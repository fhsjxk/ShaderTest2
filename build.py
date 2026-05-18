import os
import shutil
import re

VERSION_HEADER = "#version 460 compatibility"

FOLDER_SHADER = "E:/Minecraft/.minecraft/versions/1.21.11-Fabric/shaderpacks/ShaderTest2/shaders/"

FOLDER_TEXTURE = "textures"
FOLDER_LIB = "lib"
FOLDER_PROGRAM = "program"
FOLDER_WORLD_0 = "world0"

FILE_IGNORE = ["global_settings.glsl", ".gitignore"]

GBUFFER_COMMON_FILE = "gbuffers_common.glsl"
SHADOW_COMMON_FILE = "shadow_common.glsl"

GBUFFER_PROGRAMS = ["basic"]
#GBUFFER_PROGRAMS = ["basic", "entities","weather", "water", "hand_water", "skybasic", "skytextured"]
GBUFFER_PROGRAMS = ["basic", "terrain", "block", "entities", "hand"]
#GBUFFER_PROGRAMS = ["basic", "line", "textured", "textured_lit", "skybasic", "skytextured", "clouds", "terrain", "damagedblock", "block", "beaconbeam", "entities", "armor_glint", "spidereyes", "hand", "weather", "water", "hand_water"]

SHADOW_PROGRAMS = [""]

DEBUG_PRECOMPUTE = False

RT_DEFS = [
    { # 0
        "name": "RT_BACK",
        "format": "R11F_G11F_B10F",
    },
    { # 1
        "name": "RT_BASE_COLOR", # RGB:BaseColor A:Unused
        "format": "RGBA8",
    },
    { # 2
        "name": "RT_NORMAL", # RGB:Normal A:SunLight
        "format": "RGBA8",
    },
    { # 3
        "name": "RT_SPECULAR",
        "format": "RGBA8",
    },
    { # 4
        "name": "RT_LIGHTING0", # RG:LightLevel B:AO
        "format": "R11F_G11F_B10F",
    },
    { # 5
        "name": "RT_LIGHTING1", # Unused
        "format": "RGBA8",
    },
    { # 6
        "name": "RT_LIGHTING_LUT",
        "format": "RGBA16F",
        "size": "32 2",
    },
    { # 7
        "name": "RT_TRANSMIT_LUT",
        "format": "RGBA8",
        "size": "256 64",
    },
    { # 8
        "name": "RT_ATMOSPHERE_LUT",
        "format": "RGBA16F",
        "size": "32 32",
    },
    { # 9
        "name": "RT_SKYVIEW",
        "format": "RGBA16F",
        "size": "64 64",
    },
    { # 10
        "name": "RT_FROXEL",
        "format": "RGBA16F",
        "size": "32 1024",
    },
    { # 11
        "name": "RT_SKY",
        "format": "RGBA16F",
        "size": "0.125 0.125",
    },
    { # 12
        "name": "RT_BLOOM",
        "format": "R11F_G11F_B10F",
        "size": "1.0 0.5",
    },
#    {
#        "name": "RT_SKY_TEST",
#        "format": "RGB32F",
#        "size": "4096 2048",
#    },
]

# RT_LIGHTING_LUT:
# 0~10:SkyLight:x, -x, y, -y, z, -z, xz, -xz, x-z, -x-z
# 0:R:Value

IMG_DEFS = [
    { # 0
        "name": "RT_BACK",
        "format": "R11F_G11F_B10F",
    },
]

SHADER_CONFIG = {}

rt_formats_lines = ["/*"]
rt_size_lines = []

for index, rt in enumerate(RT_DEFS):
    name = rt["name"]
    format = rt.get("format", "RGBA16F")
    size = rt.get("size", "1.0 1.0")

    SHADER_CONFIG[f"{{{name}}}"] = index
    SHADER_CONFIG[f"{{{{{name}}}}}"] = f"colortex{index}"
    SHADER_CONFIG["{{" + name + "_IMG}}"] = f"colorimg{index}"
    SHADER_CONFIG["{{" + name + "_FORMAT_IMG}}"] = format.lower()
    
    # Add IMG_* placeholders (new naming convention)
    short_name = name.replace("RT_", "IMG_")
    SHADER_CONFIG["{{" + short_name + "}}"] = f"colorimg{index}"
    SHADER_CONFIG["{{" + short_name + "_FORMAT}}"] = format.lower()

    rt_formats_lines.append(
        f"const int colortex{index}Format = {format};"
    )

    rt_size_lines.append(
        f"size.buffer.colortex{index} = {size}"
    )

rt_formats_lines.append("*/")

SHADER_CONFIG["{{RT_FORMATS}}"] = "\n".join(rt_formats_lines)
SHADER_CONFIG["{{RT_SIZE}}"] = "\n".join(rt_size_lines)

SHADER_CONFIG.update({
"{{SHADER_COMP}}": "SHADER_COMP",
"{{SHADER_FRAG}}": "SHADER_FRAG",
"{{SHADER_VERT}}": "SHADER_VERT",
"{{SHADER_GEOM}}": "SHADER_GEOM",

"{{POS_LIGHTING_LUT_VALUE}}": "11, 0",
})

PREPARE_INDEX = [
#"sky",
"lightingLUT",
"transmitLUT",
"atmosphereLUT"
]

COMPOSITE_INDEX = [
#"skytest",
"mipmap", # Need barrier?
"lightingLUT",
"bloom_downsample",
"bloom_blur_horiz",
"bloom_blur_vert",
"bloom_upsample",
"bloom",
"exposure",
"final"
]

DEFERRED_INDEX = [
"sky",
"lighting",
"mipmap"
]

def process_text(text):
    pattern = re.compile("|".join(re.escape(key) for key in SHADER_CONFIG.keys()))
    text = pattern.sub(lambda m: str(SHADER_CONFIG[m.group(0)]), text)
    return text

def process_file(path):
    with open(path, mode="r", encoding="utf-8") as f:
        text = f.read()
    text = process_text(text)
    with open(os.path.join(FOLDER_SHADER, path), mode="w", encoding="utf-8") as f:
        f.write(text)

def generate_shader(stage, program):
    lines = [
        VERSION_HEADER,
        "",
        f"#define {stage}",
        "",
        f"#include /{FOLDER_PROGRAM}/{program}.glsl"
        ]
    return process_text("\n".join(lines))

def generate_shader_gbuffer(stage, program, base_name=""):
    lines = [
        VERSION_HEADER,
        "",
        f"#define {stage}",
        f"#define GBUFFER_{program.upper()}",
        "",
        f"#include /{FOLDER_PROGRAM}/{base_name + ".glsl" if base_name else GBUFFER_COMMON_FILE}"
        ]
    return process_text("\n".join(lines))

def generate_shader_shadow(stage, program):
    split = "_" if program != "" else ""
    lines = [
        VERSION_HEADER,
        "",
        f"#define {stage}",
        f"#define SHADOW{split}{program.upper()}",
        "",
        f"#include /{FOLDER_PROGRAM}/{SHADOW_COMMON_FILE}"
        ]
    return process_text("\n".join(lines))

with open("global_settings.glsl", mode="r", encoding="utf-8") as gs:
    SHADER_CONFIG["{{GLOBAL_SETTINGS}}"] = process_text(gs.read())

if(os.path.exists(FOLDER_SHADER)):
    shutil.rmtree(FOLDER_SHADER)

os.makedirs(FOLDER_SHADER)
os.makedirs(FOLDER_SHADER + FOLDER_LIB)
os.makedirs(FOLDER_SHADER + FOLDER_PROGRAM)
os.makedirs(FOLDER_SHADER + FOLDER_WORLD_0)
os.makedirs(FOLDER_SHADER + FOLDER_TEXTURE)

for item in os.listdir(FOLDER_TEXTURE):
    path = os.path.join(FOLDER_TEXTURE, item)
    if os.path.isfile(path):
        shutil.copy(path, os.path.join(FOLDER_SHADER, FOLDER_TEXTURE))

for program in GBUFFER_PROGRAMS:
    base_name = f"gbuffers_{program}"
    
    path_fsh = os.path.join(FOLDER_SHADER, FOLDER_WORLD_0, f"{base_name}.fsh")
    path_vsh = os.path.join(FOLDER_SHADER, FOLDER_WORLD_0, f"{base_name}.vsh")

    content_fsh = generate_shader_gbuffer(SHADER_CONFIG["{{SHADER_FRAG}}"], program)
    content_vsh = generate_shader_gbuffer(SHADER_CONFIG["{{SHADER_VERT}}"], program)

    with open(path_fsh, "w", encoding="utf-8") as f:
        f.write(content_fsh)
    
    with open(path_vsh, "w", encoding="utf-8") as f:
        f.write(content_vsh)

for program in SHADOW_PROGRAMS:
    split = "_" if program != "" else ""

    base_name = f"shadow{split}{program}"
    
    path_fsh = os.path.join(FOLDER_SHADER, FOLDER_WORLD_0, f"{base_name}.fsh")
    path_vsh = os.path.join(FOLDER_SHADER, FOLDER_WORLD_0, f"{base_name}.vsh")

    content_fsh = generate_shader_shadow(SHADER_CONFIG["{{SHADER_FRAG}}"], program)
    content_vsh = generate_shader_shadow(SHADER_CONFIG["{{SHADER_VERT}}"], program)

    with open(path_fsh, "w", encoding="utf-8") as f:
        f.write(content_fsh)
    
    with open(path_vsh, "w", encoding="utf-8") as f:
        f.write(content_vsh)

for file_name in os.listdir(FOLDER_PROGRAM):
    if file_name.startswith("gbuffers_") and file_name != GBUFFER_COMMON_FILE:
        process_file(os.path.join(FOLDER_PROGRAM, file_name))

        base_name = file_name.replace(".glsl", "")
        program = base_name.replace("gbuffers_", "")

        path_fsh = os.path.join(FOLDER_SHADER, FOLDER_WORLD_0, f"{base_name}.fsh")
        path_vsh = os.path.join(FOLDER_SHADER, FOLDER_WORLD_0, f"{base_name}.vsh")

        content_fsh = generate_shader_gbuffer(SHADER_CONFIG["{{SHADER_FRAG}}"], program, base_name)
        content_vsh = generate_shader_gbuffer(SHADER_CONFIG["{{SHADER_VERT}}"], program, base_name)

        with open(path_fsh, "w", encoding="utf-8") as f:
            f.write(content_fsh)

        with open(path_vsh, "w", encoding="utf-8") as f:
            f.write(content_vsh)

        with open(os.path.join(FOLDER_PROGRAM, file_name), mode="r", encoding="utf-8") as f:
            text = f.read()
            if "{{SHADER_GEOM}}" in text:
                content_gsh = generate_shader_gbuffer(SHADER_CONFIG["{{SHADER_GEOM}}"], program, base_name)
                path_gsh = os.path.join(FOLDER_SHADER, FOLDER_WORLD_0, f"{base_name}.gsh")
                with open(path_gsh, "w", encoding="utf-8") as f:
                    f.write(content_gsh)


process_file(os.path.join(FOLDER_PROGRAM, GBUFFER_COMMON_FILE))
process_file(os.path.join(FOLDER_PROGRAM, SHADOW_COMMON_FILE))

prefix_map = {
"prepare": PREPARE_INDEX,
"composite": COMPOSITE_INDEX,
"deferred": DEFERRED_INDEX
}

processed_common_files = set()

for prefix, index_list in prefix_map.items():
    for file_type in index_list:
        common_base_name = f"common_{file_type}"
        common_file_name = f"{common_base_name}.glsl"
        common_file_path = os.path.join(FOLDER_PROGRAM, common_file_name)

        if os.path.isfile(common_file_path):
            if common_file_path not in processed_common_files:
                process_file(common_file_path)
                processed_common_files.add(common_file_path)

            file_index = index_list.index(file_type) + 1
            file_name_final = f"{prefix}{file_index}"

            path_fsh = os.path.join(FOLDER_SHADER, FOLDER_WORLD_0, f"{file_name_final}.fsh")
            path_vsh = os.path.join(FOLDER_SHADER, FOLDER_WORLD_0, f"{file_name_final}.vsh")

            content_fsh = generate_shader(SHADER_CONFIG["{{SHADER_FRAG}}"], common_base_name)
            content_vsh = generate_shader(SHADER_CONFIG["{{SHADER_VERT}}"], common_base_name)

            with open(path_fsh, "w", encoding="utf-8") as f:
                f.write(content_fsh)
            with open(path_vsh, "w", encoding="utf-8") as f:
                f.write(content_vsh)

    for file_type in index_list:
        base_name = f"{prefix}_{file_type}"
        file_name = f"{base_name}.glsl"
        file_path = os.path.join(FOLDER_PROGRAM, file_name)
        
        if os.path.isfile(file_path):
            process_file(file_path)
            
            file_index = index_list.index(file_type) + 1
            file_name_final = f"{prefix}{file_index}"
            
            path_fsh = os.path.join(FOLDER_SHADER, FOLDER_WORLD_0, f"{file_name_final}.fsh")
            path_vsh = os.path.join(FOLDER_SHADER, FOLDER_WORLD_0, f"{file_name_final}.vsh")
            
            content_fsh = generate_shader(SHADER_CONFIG["{{SHADER_FRAG}}"], base_name)
            content_vsh = generate_shader(SHADER_CONFIG["{{SHADER_VERT}}"], base_name)
            
            with open(path_fsh, "w", encoding="utf-8") as f:
                f.write(content_fsh)
            with open(path_vsh, "w", encoding="utf-8") as f:
                f.write(content_vsh)
        
        cs_base_name = f"{prefix}_{file_type}_cs"
        cs_file_name = f"{cs_base_name}.glsl"
        cs_file_path = os.path.join(FOLDER_PROGRAM, cs_file_name)
        
        if os.path.isfile(cs_file_path):
            process_file(cs_file_path)
            
            file_index = index_list.index(file_type) + 1
            file_name_final = f"{prefix}{file_index}"
            
            path_csh = os.path.join(FOLDER_SHADER, FOLDER_WORLD_0, f"{file_name_final}.csh")
            content_csh = generate_shader(SHADER_CONFIG["{{SHADER_COMP}}"], cs_base_name)
            
            with open(path_csh, "w", encoding="utf-8") as f:
                f.write(content_csh)

for file_name in os.listdir("./"):
    if file_name in FILE_IGNORE:
        continue

    if os.path.isfile(file_name) and not file_name.endswith(".py"):
        process_file(file_name)

for file_name in os.listdir(FOLDER_LIB):
    if file_name in FILE_IGNORE:
        continue

    process_file(os.path.join(FOLDER_LIB, file_name))