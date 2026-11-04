import os
import shutil
import re
from pathlib import Path
from dataclasses import dataclass

# ═══════════════════════════════════════════════════════════════
#  Configuration
# ═══════════════════════════════════════════════════════════════

VERSION_HEADER = "#version 460 compatibility"

SHADERPACK = Path(
    "E:/Minecraft/.minecraft/versions/26.3-Fabric"
    "/shaderpacks/ShaderTest2/shaders/"
)

# Source tree. Mirrors the pack layout one-to-one; the builder only substitutes
# template variables and generates world0/ entry shims.
SRC_ROOT         = Path("shaders")

DIR_PROGRAM      = "program"
DIR_WORLD        = "world0"

GBUFFER_COMMON   = "gbuffers/common.glsl"          # relative to program/
SHADOW_PROGRAM   = "program/shadow/shadow.glsl"    # relative to shaders/
PROPERTIES       = "shaders.properties"

# Handled by dedicated code, must not be copied by the generic tree walk.
WALK_SKIP_FILES  = {PROPERTIES}
# Generated, or development-only source assets (authoring projects, etc.).
WALK_SKIP_PATHS  = {
    (DIR_WORLD,),
    ("textures", "projects"),
}
# Only these are template-expanded; everything else is copied byte for byte.
TEMPLATED_SUFFIXES = {".glsl"}


@dataclass
class RT:
    name: str
    fmt: str  = "RGBA16F"
    size: str = "1.0 1.0"


# Number of bloom cascade levels. Each level halves the resolution, so level 1 is
# half res and level BLOOM_LEVELS is 1/2^BLOOM_LEVELS. Everything else (buffers,
# passes, docs) is derived from this number.
BLOOM_LEVELS = 10


RT_LIST = [
    RT("RT_ALBEDO",        "RGBA8"),
    RT("RT_NORMAL",        "RGBA8"),
    RT("RT_SPECULAR",      "RGBA8"),
    RT("RT_LIGHTMAP",      "RGBA16F"),
    RT("RT_VERTEX_LIGHT",  "RGBA8"),
    # Scene radiance in colour units. 16F suffices because the solar disc is
    # written at SUN_DISC_RENDER_SCALE of its physical radiance (3.1e4 units).
    RT("RT_HDR",           "RGBA16F"),
    # Luminance buffer for auto exposure (log-average + centre weighting).
    RT("RT_LUM",           "RG16F",   size="0.03125 0.03125"),
]

# Bloom pyramid: one buffer per level, 1/2 down to 1/2^BLOOM_LEVELS. Values are
# display-referred (already multiplied by the exposure) and capped at
# BLOOM_SOURCE_CEILING, so a half float holds them.
for _level in range(1, BLOOM_LEVELS + 1):
    _scale = 0.5 ** _level
    RT_LIST.append(RT(f"RT_BLOOM{_level}", "RGBA16F",
                      size=f"{_scale:g} {_scale:g}"))


# Iris documents 16 colortex (0..15) and 32 from 1.10.5 onwards. Measured on Iris
# 1.10.3 with a probe pack, twice (with and without format declarations): buffers
# 0..19 really get created, and from index 20 the binding silently falls back to a
# previously bound texture -- no GL error, nothing in the log. Custom images are a
# separate, hard limit of 16 that Iris does log.
MAX_COLOR_BUFFERS = 32
DOCUMENTED_COLOR_BUFFERS = 16
MEASURED_COLOR_BUFFERS = 20
if len(RT_LIST) > MAX_COLOR_BUFFERS:
    raise SystemExit(
        f"RT_LIST has {len(RT_LIST)} entries (colortex0..{len(RT_LIST) - 1}) but "
        f"Iris enforces at most {MAX_COLOR_BUFFERS}. Lower BLOOM_LEVELS to "
        f"{MAX_COLOR_BUFFERS - (len(RT_LIST) - BLOOM_LEVELS)} or free a slot.")
if len(RT_LIST) > MEASURED_COLOR_BUFFERS:
    print(f"warning: {len(RT_LIST)} render targets declared, past the measured "
          f"working range of {MEASURED_COLOR_BUFFERS} (colortex0..19). Iris 1.10.3 "
          f"binds a stale texture instead of failing, so verify with a capture.")
elif len(RT_LIST) > DOCUMENTED_COLOR_BUFFERS:
    print(f"note: {len(RT_LIST)} render targets declared, but only "
          f"{DOCUMENTED_COLOR_BUFFERS} colortex are documented (colortex0..15). "
          f"Measured working range is {MEASURED_COLOR_BUFFERS}.")


@dataclass
class IMG:
    name:     str
    pixel:    str  = "RGBA"
    image:    str  = "RGBA16F"
    type_:    str  = "HALF_FLOAT"
    clear:    bool = False
    relative: bool = True
    size:     str  = "1.0 1.0"


IMG_LIST = [
    IMG("IMG_TRANSMIT_LUT", image="RGBA16F", relative=False, size="256 64"),
    # Sky-view LUT holds radiance in colour units plus the scaled solar disc.
    IMG("IMG_SKYVIEW",      image="RGBA16F", relative=False, size="512 256"),
    IMG("IMG_SKY",          image="RGBA16F", relative=True,  size="0.125 0.125"),
]


@dataclass
class Pass:
    """One Iris program slot: which source it includes and which stages it needs.

    A single source file may serve several slots by receiving different defines
    (see the bloom chain), which is why the table is the single source of truth
    for the pipeline order.
    """
    slot: str
    source: str                       # relative to shaders/
    stages: tuple[str, ...] = ("frag", "vert")
    defines: tuple[str, ...] = ()


PIPELINE = [
    Pass("setup1",      "program/setup/exposure_init_cs.glsl",       ("comp",)),
    Pass("prepare1",    "program/prepare/transmittance_lut_cs.glsl", ("comp",)),
    Pass("prepare2",    "program/prepare/skyview_cs.glsl",           ("comp",)),
    Pass("deferred1",   "program/deferred/sky_cs.glsl",              ("comp",)),
    Pass("deferred2",   "program/deferred/lighting_cs.glsl",         ("comp",)),

    # Auto exposure: sparse log-luma measure, then temporal adaptation.
    Pass("composite1",  "program/post/exposure/measure_cs.glsl",     ("comp",)),
    Pass("composite2",  "program/post/exposure/adapt_cs.glsl",       ("comp",)),
]

# Bloom: 13-tap downsample pyramid, then tent upsample that accumulates into the
# finer level. Both stages are shared sources driving every level, so each pass
# gets its buffer pair and dispatch scale injected as defines.
RT_SLOT = {rt.name: i for i, rt in enumerate(RT_LIST)}


def _float_literal(value: float) -> str:
    """Format as a GLSL float literal, which must contain a decimal point."""
    text = f"{value:.10f}".rstrip("0")
    return text + "0" if text.endswith(".") else text


def _bloom_defines(src: str, dst: str, scale: float, level: int) -> tuple[str, ...]:
    """Defines for one bloom pass.

    BLOOM_SCALE has to reach the shader as a bare number: Iris parses
    workGroupsRender from the preprocessed source with a plain float parse, so an
    expression there is silently ignored and the pass dispatches at full screen
    resolution instead of at the level's size.
    """
    return (
        f"BLOOM_SRC colortex{RT_SLOT[src]}",
        f"BLOOM_DST_IMG colorimg{RT_SLOT[dst]}",
        f"BLOOM_SCALE {_float_literal(scale)}",
        f"BLOOM_LEVEL {level}",
    )


_bloom_slot = 3
for _level in range(BLOOM_LEVELS):
    _src = "RT_HDR" if _level == 0 else f"RT_BLOOM{_level}"
    PIPELINE.append(Pass(f"composite{_bloom_slot}",
                         "program/post/bloom/downsample_cs.glsl",
                         ("comp",),
                         _bloom_defines(_src, f"RT_BLOOM{_level + 1}",
                                        0.5 ** (_level + 1), _level)))
    _bloom_slot += 1
for _level in range(BLOOM_LEVELS - 1, 0, -1):
    PIPELINE.append(Pass(f"composite{_bloom_slot}",
                         "program/post/bloom/upsample_cs.glsl",
                         ("comp",),
                         _bloom_defines(f"RT_BLOOM{_level + 1}", f"RT_BLOOM{_level}",
                                        0.5 ** _level, _level)))
    _bloom_slot += 1

# Tone mapping, exposure and bloom are applied here, writing the backbuffer.
PIPELINE.append(Pass("final", "program/post/final.glsl", ("frag", "vert")))

GBUFFER_VARIANTS = [
    "basic", "line", "textured", "textured_lit", "skybasic", "skytextured",
    "clouds", "terrain", "damagedblock", "block", "beaconbeam",
    "entities", "armor_glint", "spidereyes", "hand",
    "weather", "water", "hand_water",
]

SHADOW_VARIANTS = [""]


class TemplateEngine:
    """Compiles a single regex from all template variables for fast
    one-pass substitution.  Keys are regex-escaped automatically."""

    def __init__(self):
        self._vars: dict[str, str] = {}
        self._regex: re.Pattern | None = None

    # -- registration -------------------------------------------------
    def add(self, key: str, value) -> None:
        self._vars[key] = str(value)

    def add_all(self, mapping: dict[str, str]) -> None:
        for k, v in mapping.items():
            self._vars[k] = str(v)

    def freeze(self) -> None:
        """Compile the regex.  Call after all variables are registered."""
        escaped = (re.escape(k) for k in self._vars)
        self._regex = re.compile("|".join(escaped))

    # -- processing ---------------------------------------------------
    def apply(self, text: str) -> str:
        if self._regex is None:
            self.freeze()
        return self._regex.sub(lambda m: self._vars[m.group(0)], text)

    def apply_file(self, src: Path, dst: Path) -> None:
        dst.write_text(self.apply(src.read_text(encoding="utf-8")),
                       encoding="utf-8")

    # -- accessors ----------------------------------------------------
    @property
    def frag(self) -> str: return self._vars["{{SHADER_FRAG}}"]
    @property
    def vert(self) -> str: return self._vars["{{SHADER_VERT}}"]
    @property
    def comp(self) -> str: return self._vars["{{SHADER_COMP}}"]
    @property
    def geom(self) -> str: return self._vars["{{SHADER_GEOM}}"]


def build_template_vars() -> TemplateEngine:
    """Populate the template engine from RT / IMG definitions."""
    tmpl = TemplateEngine()

    # ── Render targets ──────────────────────────────────────────
    # The format block is wrapped in a comment because `RGBA16F` is not a GLSL
    # token, but Iris still reads it: ConstDirectiveParser scans the source line by
    # line and only checks that a line starts with `const`, so declarations inside
    # a comment are picked up while the compiler never sees them. This block is the
    # only place buffer formats are set -- the layout() qualifier on colorimgN does
    # not create the buffer format, it only has to agree with it.
    rt_fmt_lines = ["/*"]
    rt_size_lines = []

    for i, rt in enumerate(RT_LIST):
        name = rt.name
        fmt  = rt.fmt

        # One namespace, suffix states how the buffer is referenced.
        tmpl.add("{{" + name + "}}",        f"colortex{i}")   # sampler / property key
        tmpl.add("{{" + name + "_IMG}}",    f"colorimg{i}")   # image2D handle
        tmpl.add("{{" + name + "_SLOT}}",   i)                # RENDERTARGETS index
        tmpl.add("{{" + name + "_FORMAT}}", fmt.lower())      # layout(...) format

        # Relative buffer size, so shaders sharing a layout never hardcode it.
        sizeX, sizeY = rt.size.split()
        tmpl.add("{{" + name + "_SIZE}}",   rt.size)
        tmpl.add("{{" + name + "_SIZE_X}}", sizeX)
        tmpl.add("{{" + name + "_SIZE_Y}}", sizeY)

        rt_fmt_lines.append(f"const int colortex{i}Format = {fmt};")
        rt_size_lines.append(f"size.buffer.colortex{i} = {rt.size}")

    rt_fmt_lines.append("*/")
    tmpl.add("{{GENERATED_RT_FORMATS}}", "\n".join(rt_fmt_lines))
    tmpl.add("{{GENERATED_RT_SIZES}}",   "\n".join(rt_size_lines))

    # ── Custom images ───────────────────────────────────────────
    img_lines = []
    for img in IMG_LIST:
        safe = img.name.lower().removeprefix("img_")
        tmpl.add("{{IMG_" + safe.upper() + "}}", f"img_{safe}")
        tmpl.add("{{IMG_" + safe.upper() + "_SAMPLER}}", f"sampler_{safe}")
        tmpl.add("{{IMG_" + safe.upper() + "_FORMAT}}", img.image.lower())

        sizeX, sizeY = img.size.split()
        tmpl.add("{{IMG_" + safe.upper() + "_SIZE}}",   img.size)
        tmpl.add("{{IMG_" + safe.upper() + "_SIZE_X}}", sizeX)
        tmpl.add("{{IMG_" + safe.upper() + "_SIZE_Y}}", sizeY)

        img_lines.append(
            f"image.img_{safe} = sampler_{safe} "
            f"{img.pixel.lower()} {img.image.lower()} {img.type_.lower()} "
            f"{str(img.clear).lower()} {str(img.relative).lower()} {img.size}"
        )
    tmpl.add("{{GENERATED_IMG_DECLS}}", "\n".join(img_lines))

    # ── Shader-type markers ─────────────────────────────────────
    for st in ("SHADER_COMP", "SHADER_FRAG", "SHADER_VERT", "SHADER_GEOM"):
        tmpl.add("{{" + st + "}}", st)

    tmpl.freeze()
    return tmpl


STAGE_EXT = {"vert": ".vsh", "frag": ".fsh", "geom": ".gsh", "comp": ".csh"}
STAGE_MACRO = {
    "vert": "SHADER_VERT",
    "frag": "SHADER_FRAG",
    "geom": "SHADER_GEOM",
    "comp": "SHADER_COMP",
}


def _emit(tmpl: TemplateEngine, out_dir: Path, slot: str, stage: str,
          include: str, defines: tuple[str, ...] = ()) -> None:
    """Write one Iris entry shim: version, stage macro, extra defines, include."""
    parts = [VERSION_HEADER, "", f"#define {STAGE_MACRO[stage]}"]
    parts.extend(f"#define {d}" for d in defines)
    parts += ["", f"#include /{include}"]
    (out_dir / f"{slot}{STAGE_EXT[stage]}").write_text(
        tmpl.apply("\n".join(parts)), encoding="utf-8")


def _emit_pass(tmpl: TemplateEngine, out_dir: Path, p: "Pass") -> None:
    for stage in p.stages:
        _emit(tmpl, out_dir, p.slot, stage, p.source, p.defines)


class ShaderBuilder:
    def __init__(self):
        self.tmpl = build_template_vars()
        self.src_root  = SRC_ROOT
        self.src_prog  = SRC_ROOT / DIR_PROGRAM
        self.out_world = SHADERPACK / DIR_WORLD

    # ── entry point ────────────────────────────────────────────

    def run(self) -> None:
        # 1 — clean & recreate output tree
        if SHADERPACK.exists():
            shutil.rmtree(SHADERPACK)
        os.makedirs(self.out_world, exist_ok=True)

        # 2 — mirror the source tree (template substitution only)
        self._copy_tree()

        # 3 — properties (needs the blend expansion, so it is not walked)
        self._properties()

        # 4 — generate world0/ entry shims
        self._gbuffers()
        self._shadows()
        self._pipeline()

    # ── source tree mirror ─────────────────────────────────────

    def _copy_tree(self) -> None:
        """Copy shaders/ into the pack, expanding templates in GLSL only.

        Paths are preserved, so a file in the pack always maps back to the file
        it came from. world0/ is generated and shaders.properties is written by
        _properties(), so both are skipped here.
        """
        for src in sorted(self.src_root.rglob("*")):
            if not src.is_file():
                continue

            rel = src.relative_to(self.src_root)
            parts = rel.parts
            if src.name in WALK_SKIP_FILES:
                continue
            if any(parts[:len(skip)] == skip for skip in WALK_SKIP_PATHS):
                continue

            dst = SHADERPACK / rel
            dst.parent.mkdir(parents=True, exist_ok=True)

            if src.suffix.lower() in TEMPLATED_SUFFIXES:
                self.tmpl.apply_file(src, dst)
            else:
                shutil.copy2(src, dst)

    # ── gbuffers ───────────────────────────────────────────────

    def _gbuffers(self) -> None:
        variants_dir = self.src_prog / "gbuffers"
        for variant in GBUFFER_VARIANTS:
            dedicated = variants_dir / f"{variant}.glsl"
            if dedicated.is_file():
                source = f"{DIR_PROGRAM}/gbuffers/{variant}.glsl"
                stages = ["frag", "vert"]
                if "{{SHADER_GEOM}}" in dedicated.read_text(encoding="utf-8"):
                    stages.append("geom")
            else:
                source = f"{DIR_PROGRAM}/{GBUFFER_COMMON}"
                stages = ["frag", "vert"]

            _emit_pass(self.tmpl, self.out_world,
                       Pass(f"gbuffers_{variant}", source, tuple(stages),
                            (f"GBUFFER_{variant.upper()}",)))

    # ── shadows ────────────────────────────────────────────────

    def _shadows(self) -> None:
        for variant in SHADOW_VARIANTS:
            sep = "_" if variant else ""
            defines = (f"SHADOW{sep}{variant.upper()}",) if variant else ()
            _emit_pass(self.tmpl, self.out_world,
                       Pass(f"shadow{sep}{variant}", SHADOW_PROGRAM,
                            ("frag", "vert"), defines))

    # ── pipeline ───────────────────────────────────────────────

    def _pipeline(self) -> None:
        for p in PIPELINE:
            _emit_pass(self.tmpl, self.out_world, p)

    # ── properties ─────────────────────────────────────────────

    def _properties(self) -> None:
        text = (self.src_root / PROPERTIES).read_text(encoding="utf-8")

        # Expand "blend.X.gbuffers = off" → off for every RT.
        # {{RT_<NAME>}} expands to the Iris buffer name (colortexN), which is
        # what the properties file expects here.
        pat = re.compile(r"blend\.([^.]+)\.gbuffers\s*=\s*off")
        expand = "\n".join(f"blend.\\1.{{{{{rt.name}}}}} = off" for rt in RT_LIST)
        text = pat.sub(expand, text)
        text = self.tmpl.apply(text)

        (SHADERPACK / PROPERTIES).write_text(text, encoding="utf-8")


if __name__ == "__main__":
    ShaderBuilder().run()