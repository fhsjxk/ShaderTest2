// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/common.glsl"
#include "/lib/options.glsl"

uniform float frameTime;
uniform sampler2D {{RT_BACK}};
uniform sampler2D {{RT_LIGHTING_LUT}};

/* RENDERTARGETS: {RT_LIGHTING_LUT} */
layout({{RT_LIGHTING_LUT_FORMAT_IMG}}) uniform writeonly image2D {{RT_LIGHTING_LUT_IMG}};
layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(1, 1, 1);

void main()
{
    int level = max(textureQueryLevels({{RT_BACK}}) - 2, 0);
    float prevValue = texelFetch({{RT_LIGHTING_LUT}}, ivec2({{POS_LIGHTING_LUT_VALUE}}), 0).r;
    float currentValue = getBrightness(textureLod({{RT_BACK}}, vec2(0.5), level).rgb);
    float nextValue = mix(prevValue, pow(currentValue, 0.7), frameTime * 1.5);
    imageStore({{RT_LIGHTING_LUT_IMG}}, ivec2({{POS_LIGHTING_LUT_VALUE}}), vec4(nextValue, 0.0, 0.0, 1.0));
}
#endif
