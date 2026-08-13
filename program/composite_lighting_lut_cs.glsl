// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/common.glsl"
#include "/lib/options.glsl"
#include "/lib/color.glsl"

uniform float frameTime;
uniform sampler2D {{RT_BACK}};

layout(std430, binding = 0) buffer LightingLut {
    float value;
} lightingLut;

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(1, 1, 1);

void main()
{
    barrier();
    int level = max(textureQueryLevels({{RT_BACK}}) - 2, 0);
    float previousValue = lightingLut.value;
    float currentValue = getBrightness(textureLod({{RT_BACK}}, vec2(0.5), level).rgb);
    lightingLut.value = mix(previousValue, pow(currentValue, 0.7), frameTime * 2.0);
}
#endif
