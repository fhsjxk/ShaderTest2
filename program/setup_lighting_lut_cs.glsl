// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/common.glsl"
#include "/lib/options.glsl"
#include "/lib/color.glsl"

layout(std430, binding = 0) buffer LightingLut {
    float value;
} lightingLut;

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(1, 1, 1);

void main()
{
    lightingLut.value = 0.3;
}
#endif
