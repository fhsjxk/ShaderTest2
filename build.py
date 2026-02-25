import os
import shutil
import re

VERSION_HEADER = "#version 450 compatibility"

FOLDER_SHADER = "E:/Minecraft/.minecraft/versions/1.21.11-Fabric/shaderpacks/ShaderTest2/shaders/"

FOLDER_TEXTURE = "textures"
FOLDER_LIB = "lib"
FOLDER_PROGRAM = "program"
FOLDER_WORLD_0 = "world0"

FILE_IGNORE = ["global_settings.glsl", ".gitignore"]

GBUFFER_COMMON_FILE = "gbuffers_common.glsl"

GBUFFER_PROGRAMS = ["basic"]
#GBUFFER_PROGRAMS = ["basic", "entities","weather", "water", "hand_water", "skybasic", "skytextured"]
#GBUFFER_PROGRAMS = ["basic", "terrain", "block", "entities", "hand"]
#GBUFFER_PROGRAMS = ["basic", "line", "textured", "textured_lit", "skybasic", "skytextured", "clouds", "terrain", "damagedblock", "block", "beaconbeam", "entities", "armor_glint", "spidereyes", "hand", "weather", "water", "hand_water"]

RT_DEFS = [
    {
        "name": "RT_BACK",
        "format": "R11F_G11F_B10F",
    },
    {
        "name": "RT_BASE_COLOR", # RGB:BaseColor A:Unused
        "format": "RGBA8",
    },
    {
        "name": "RT_NORMAL", # RGB:Normal A:SunLight
        "format": "RGBA8",
    },
    {
        "name": "RT_SPECULAR",
        "format": "RGBA8",
    },
    {
        "name": "RT_LIGHTING0", # RG:LightLevel B:AO
        "format": "R11F_G11F_B10F",
    },
    {
        "name": "RT_LIGHTING1", # Unused
        "format": "RGBA8",
    },
    {
        "name": "RT_LIGHTING_LUT",
        "format": "RGBA16F",
        "size": "32 2",
    },
    {
        "name": "RT_TRANSMIT_LUT",
        "format": "RGBA8",
        "size": "256 64",
    },
    {
        "name": "RT_SKYVIEW_LUT",
        "format": "RGBA16F",
        "size": "64 64",
    },
    {
        "name": "RT_FROXEL",
        "format": "RGBA16F",
        "size": "32 1024",
    },
    {
        "name": "RT_SKYVIEW",
        "format": "RGBA16F",
        "size": "0.125 0.125",
    },
]

# RT_LIGHTING_LUT:
# 0~10:SkyLight:x, -x, y, -y, z, -z, xz, -xz, x-z, -x-z
# 0:R:Value

SHADER_CONFIG = {}

rt_formats_lines = ["/*"]
rt_size_lines = []

for index, rt in enumerate(RT_DEFS):
    name = rt["name"]
    format = rt.get("format", "RGBA16F")
    size = rt.get("size", "1.0 1.0")

    SHADER_CONFIG[f"{{{{{name}}}}}"] = index
    SHADER_CONFIG[f"{{{name}}}"] = f"colortex{index}"

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
"{{SHADER_FRAG}}": "SHADER_FRAG",
"{{SHADER_VERT}}": "SHADER_VERT",

"{{POS_LIGHTING_LUT_VALUE}}": "11, 0",
})

PREPARE_INDEX = [
"sky",
"lightingLUT",
"transmitLUT"
]

COMPOSITE_INDEX = [
"lightingLUT",
"exposure",
"bloom",
"gamma",
"last"
]

DEFERRED_INDEX = [
"skyview0",
"skyview1",
"lighting"
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

def generate_shader_gbuffer(stage, program):
    lines = [
        VERSION_HEADER,
        "",
        f"#define {stage}",
        f"#define GBUFFER_{program.upper()}",
        "",
        f"#include /{FOLDER_PROGRAM}/{GBUFFER_COMMON_FILE}"
        ]
    return process_text("\n".join(lines))

with open("global_settings.glsl", mode="r", encoding="utf-8") as gs:
    SHADER_CONFIG["{{GLOBAL_SETTINGS}}"] = process_text(gs.read())

if(os.path.exists(FOLDER_SHADER)):
    shutil.rmtree(FOLDER_SHADER)

os.makedirs(FOLDER_SHADER)
shutil.copytree(FOLDER_TEXTURE, os.path.join(FOLDER_SHADER, FOLDER_TEXTURE))
os.makedirs(FOLDER_SHADER + FOLDER_LIB)
os.makedirs(FOLDER_SHADER + FOLDER_PROGRAM)
os.makedirs(FOLDER_SHADER + FOLDER_WORLD_0)

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
        
process_file(os.path.join(FOLDER_PROGRAM, GBUFFER_COMMON_FILE))

for file_name in os.listdir(FOLDER_PROGRAM):
    if file_name == GBUFFER_COMMON_FILE:
        continue
    process_file(os.path.join(FOLDER_PROGRAM, file_name))

    file_name_base = file_name.replace(".glsl", "")
    file_type = file_name_base.split("_")
    if len(file_type) > 1:
        file_type = file_type[1]
    else:
        file_type = None

    if file_name.startswith("prepare"):
        file_index = PREPARE_INDEX.index(file_type)+1
        file_name_final = f"prepare{file_index}"
    elif file_name.startswith("composite"):
        file_index = COMPOSITE_INDEX.index(file_type)+1
        file_name_final = f"composite{file_index}"
    elif file_name.startswith("deferred"):
        file_index = DEFERRED_INDEX.index(file_type)+1
        file_name_final = f"deferred{file_index}"
    else:
        file_name_final = file_name_base

    path_fsh = os.path.join(FOLDER_SHADER, FOLDER_WORLD_0, f"{file_name_final}.fsh")
    path_vsh = os.path.join(FOLDER_SHADER, FOLDER_WORLD_0, f"{file_name_final}.vsh")

    content_fsh = generate_shader(SHADER_CONFIG["{{SHADER_FRAG}}"], file_name_base)
    content_vsh = generate_shader(SHADER_CONFIG["{{SHADER_VERT}}"], file_name_base)

    with open(path_fsh, "w", encoding="utf-8") as f:
        f.write(content_fsh)
    
    with open(path_vsh, "w", encoding="utf-8") as f:
        f.write(content_vsh)

for file_name in os.listdir("./"):
    if file_name in FILE_IGNORE:
        continue

    if os.path.isfile(file_name) and not file_name.endswith(".py"):
        process_file(file_name)

for file_name in os.listdir(FOLDER_LIB):
    if file_name in FILE_IGNORE:
        continue

    process_file(os.path.join(FOLDER_LIB, file_name))