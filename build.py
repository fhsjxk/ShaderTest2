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
    "E:/Minecraft/.minecraft/versions/1.21.11-Fabric"
    "/shaderpacks/ShaderTest2/shaders/"
)

DIR_TEXTURE      = "textures"
DIR_LIB          = "lib"
DIR_PROGRAM      = "program"
DIR_WORLD        = "world0"

GBUFFER_COMMON   = "gbuffers_common.glsl"
SHADOW_COMMON    = "shadowmap.glsl"
PROPERTIES       = "shaders.properties"


@dataclass
class RT:
    name: str
    fmt: str  = "RGBA16F"
    size: str = "1.0 1.0"


RT_LIST = [
    RT("RT_BASE_COLOR",  "RGBA8"),
    RT("RT_NORMAL",      "RGBA8"),
    RT("RT_SPECULAR",    "RGBA8"),
    RT("RT_LIGHTING0",   "RGBA16F"),
    RT("RT_LIGHTING1",   "RGBA8"),
    RT("RT_BLOOM",       "RGBA16F", size="1.505 1.02"),
    RT("RT_BACK",        "RGBA16F"),
]


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
    IMG("IMG_SKYVIEW",      image="RGBA16F", relative=False, size="256 128"),
    IMG("IMG_FROXEL",       image="RGBA16F", relative=False, clear=True, size="64 512"),
    IMG("IMG_SKY",          image="RGBA16F", relative=True,  size="0.125 0.125"),
]


PIPELINE = {
    "prepare":   ["lighting_lut", "transmit_lut", "skyview", "atmosphere_froxel"],
    "deferred":  ["sky", "lighting"],
    "composite": ["mipmap", "lighting_lut",
                  "bloom_atlas",        # .vsh+.gsh+.fsh -> atlas packing only
                  "bloom_blur_h",       # .vsh+.fsh -> horizontal blur (buffer flip)
                  "bloom_blur_v",       # .vsh+.fsh -> vertical blur (buffer flip)
                  "bloom", "exposure", "final"],
}

GBUFFER_VARIANTS = [
    "basic", "line", "textured", "textured_lit", "skybasic", "skytextured",
    "clouds", "terrain", "damagedblock", "block", "beaconbeam",
    "entities", "armor_glint", "spidereyes", "hand",
    "weather", "water", "hand_water",
]

SHADOW_VARIANTS = [""]

EXCLUDE_ROOT = {PROPERTIES, ".gitignore", "NAMING_CONVENTION.md"}


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
    rt_fmt_lines = ["/*"]
    rt_size_lines = []

    for i, rt in enumerate(RT_LIST):
        name  = rt.name
        fmt   = rt.fmt
        short = name.replace("RT_", "IMG_")

        # {RT_BACK} → 0  |  {{RT_BACK}} → colortex0
        tmpl.add("{" + name + "}", i)
        tmpl.add("{{" + name + "}}", f"colortex{i}")
        tmpl.add("{{" + name + "_IMG}}", f"colorimg{i}")
        tmpl.add("{{" + name + "_FORMAT_IMG}}", fmt.lower())
        tmpl.add("{{" + short + "}}", f"colorimg{i}")
        tmpl.add("{{" + short + "_FORMAT}}", fmt.lower())

        rt_fmt_lines.append(f"const int colortex{i}Format = {fmt};")
        rt_size_lines.append(f"size.buffer.colortex{i} = {rt.size}")

    rt_fmt_lines.append("*/")
    tmpl.add("{{RT_FORMATS}}", "\n".join(rt_fmt_lines))
    tmpl.add("{{RT_SIZE}}",    "\n".join(rt_size_lines))

    # ── Custom images ───────────────────────────────────────────
    img_lines = []
    for img in IMG_LIST:
        safe = img.name.lower().removeprefix("img_")
        tmpl.add("{{IMG_" + safe.upper() + "}}", f"img_{safe}")
        tmpl.add("{{IMG_" + safe.upper() + "_SAMPLER}}", f"sampler_{safe}")
        tmpl.add("{{IMG_" + safe.upper() + "_FORMAT}}", img.image.lower())

        img_lines.append(
            f"image.img_{safe} = sampler_{safe} "
            f"{img.pixel.lower()} {img.image.lower()} {img.type_.lower()} "
            f"{str(img.clear).lower()} {str(img.relative).lower()} {img.size}"
        )
    tmpl.add("{{IMG_DECS}}", "\n".join(img_lines))

    # ── Shader-type markers ─────────────────────────────────────
    for st in ("SHADER_COMP", "SHADER_FRAG", "SHADER_VERT", "SHADER_GEOM"):
        tmpl.add("{{" + st + "}}", st)

    tmpl.freeze()
    return tmpl


_STAGE_EXT = {
    "SHADER_COMP": ".csh",
    "SHADER_FRAG": ".fsh",
    "SHADER_VERT": ".vsh",
    "SHADER_GEOM": ".gsh",
}


def _source(stage: str, include: str,
            defines: list[str] | None = None) -> str:
    """Build the entry-point shader source text."""
    parts = [VERSION_HEADER, "", f"#define {stage}"]
    if defines:
        parts.extend(f"#define {d}" for d in defines)
    parts += ["", f"#include /{include}"]
    return "\n".join(parts)


def _emit(tmpl: TemplateEngine, out_dir: Path, base: str,
          stage: str, include: str,
          defines: list[str] | None = None) -> None:
    ext = _STAGE_EXT[stage]
    (out_dir / f"{base}{ext}").write_text(
        tmpl.apply(_source(stage, include, defines)), encoding="utf-8")


def _emit_pair(tmpl: TemplateEngine, out_dir: Path, base: str,
               include: str, defines: list[str] | None = None) -> None:
    _emit(tmpl, out_dir, base, tmpl.frag, include, defines)
    _emit(tmpl, out_dir, base, tmpl.vert, include, defines)


class ShaderBuilder:
    def __init__(self):
        self.tmpl = build_template_vars()
        self.src_prog = Path(DIR_PROGRAM)
        self.src_lib  = Path(DIR_LIB)
        self.out_world = SHADERPACK / DIR_WORLD

    # ── entry point ────────────────────────────────────────────

    def run(self) -> None:
        # 1 — clean & recreate output tree
        if SHADERPACK.exists():
            shutil.rmtree(SHADERPACK)
        for d in (SHADERPACK / DIR_LIB,
                  SHADERPACK / DIR_PROGRAM,
                  self.out_world,
                  SHADERPACK / DIR_TEXTURE):
            os.makedirs(d, exist_ok=True)

        # 3 — copy texture assets
        for f in Path(DIR_TEXTURE).iterdir():
            if f.is_file():
                shutil.copy(f, SHADERPACK / DIR_TEXTURE / f.name)

        # 4 — process shared library files
        for f in self.src_lib.iterdir():
            if f.is_file():
                self.tmpl.apply_file(f, SHADERPACK / DIR_LIB / f.name)

        # 5 — build shader stages
        self._gbuffers()
        self._shadows()
        self._pipeline()
        self._properties()

        # 6 — copy root-level loose files
        for f in Path(".").iterdir():
            if (f.is_file() and f.suffix != ".py"
                    and f.name not in EXCLUDE_ROOT):
                self.tmpl.apply_file(f, SHADERPACK / f.name)

    # ── gbuffers ───────────────────────────────────────────────

    def _gbuffers(self) -> None:
        common = self.src_prog / GBUFFER_COMMON
        self.tmpl.apply_file(common, SHADERPACK / DIR_PROGRAM / GBUFFER_COMMON)

        # A — variants relying on gbuffers_common (no dedicated file)
        for variant in GBUFFER_VARIANTS:
            if (self.src_prog / f"gbuffers_{variant}.glsl").exists():
                continue
            _emit_pair(self.tmpl, self.out_world,
                       base=f"gbuffers_{variant}",
                       include=f"{DIR_PROGRAM}/{GBUFFER_COMMON}",
                       defines=[f"GBUFFER_{variant.upper()}"])

        # B — variants with a dedicated source file
        for f in self.src_prog.iterdir():
            if not f.name.startswith("gbuffers_") or f.name == GBUFFER_COMMON:
                continue

            self.tmpl.apply_file(f, SHADERPACK / DIR_PROGRAM / f.name)

            base    = f.stem
            variant = base.removeprefix("gbuffers_")
            inc     = f"{DIR_PROGRAM}/{f.name}"
            defines = [f"GBUFFER_{variant.upper()}"]

            _emit_pair(self.tmpl, self.out_world, base, inc, defines)

            if "{{SHADER_GEOM}}" in f.read_text(encoding="utf-8"):
                _emit(self.tmpl, self.out_world, base,
                      self.tmpl.geom, inc, defines)

    # ── shadows ────────────────────────────────────────────────

    def _shadows(self) -> None:
        for variant in SHADOW_VARIANTS:
            sep  = "_" if variant else ""
            base = f"shadow{sep}{variant}"
            _emit_pair(self.tmpl, self.out_world, base,
                       include=f"{DIR_LIB}/{SHADOW_COMMON}",
                       defines=[f"SHADOW{sep}{variant.upper()}"]
                       if variant else None)

    # ── pipeline (prepare / composite / deferred) ──────────────

    def _pipeline(self) -> None:
        seen: set[Path] = set()

        for prefix, names in PIPELINE.items():
            for n, name in enumerate(names, 1):
                final = f"{prefix}{n}"

                # common_*.glsl  (shared include, e.g. common_mipmap.glsl)
                common = self.src_prog / f"common_{name}.glsl"
                if common.exists():
                    if common not in seen:
                        self.tmpl.apply_file(
                            common, SHADERPACK / DIR_PROGRAM / common.name)
                        seen.add(common)
                    _emit_pair(self.tmpl, self.out_world, final,
                               f"{DIR_PROGRAM}/{common.name}")

                # {prefix}_{name}.glsl  (fragment / vertex entry points)
                fv = self.src_prog / f"{prefix}_{name}.glsl"
                if fv.exists():
                    self.tmpl.apply_file(fv,
                                         SHADERPACK / DIR_PROGRAM / fv.name)
                    _emit_pair(self.tmpl, self.out_world, final,
                               f"{DIR_PROGRAM}/{fv.name}")

                    # Also emit geometry shader if declared in source
                    if "{{SHADER_GEOM}}" in fv.read_text(encoding="utf-8"):
                        _emit(self.tmpl, self.out_world, final,
                              self.tmpl.geom, f"{DIR_PROGRAM}/{fv.name}")

                # {prefix}_{name}_cs.glsl  (compute entry points)
                cs = self.src_prog / f"{prefix}_{name}_cs.glsl"
                if cs.exists():
                    self.tmpl.apply_file(cs,
                                         SHADERPACK / DIR_PROGRAM / cs.name)
                    _emit(self.tmpl, self.out_world, final,
                          self.tmpl.comp, f"{DIR_PROGRAM}/{cs.name}")

    # ── properties ─────────────────────────────────────────────

    def _properties(self) -> None:
        text = Path(PROPERTIES).read_text(encoding="utf-8")

        # Expand "blend.X.gbuffers = off" → off for every RT
        # Uses {{RT_NAME}} → colortexN (Iris buffer name), not {RT_NAME} → index
        pat = re.compile(r"blend\.([^.]+)\.gbuffers\s*=\s*off")
        expand = "\n".join(f"blend.\\1.{{{{{rt.name}}}}} = off" for rt in RT_LIST)
        text = pat.sub(expand, text)
        text = self.tmpl.apply(text)

        (SHADERPACK / PROPERTIES).write_text(text, encoding="utf-8")


if __name__ == "__main__":
    ShaderBuilder().run()