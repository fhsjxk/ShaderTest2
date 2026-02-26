// {{SHADER_FRAG}}
#ifdef {{SHADER_FRAG}}
#include "/lib/common.glsl"
#include "/lib/options.glsl"

uniform float frameTime;

uniform sampler2D {{RT_BACK}};
uniform sampler2D {{RT_LIGHTING_LUT}};

// LOCAL SETTINGS
const bool {{RT_BACK}}MipmapEnabled = true;

/* RENDERTARGETS: {RT_LIGHTING_LUT} */
layout(location = 0) out vec4 outColor;

void main()
{
    ivec2 pixelCoord = ivec2(gl_FragCoord.xy);

    if (pixelCoord == ivec2({{POS_LIGHTING_LUT_VALUE}}))
    {
        const int level = textureQueryLevels({{RT_BACK}}) - 2;

        float prevValue = texelFetch({{RT_LIGHTING_LUT}}, ivec2({{POS_LIGHTING_LUT_VALUE}}), 0).r;
        float currentValue = getBrightness(textureLod({{RT_BACK}}, vec2(0.5), level).rgb);

        outColor.r = mix(prevValue, pow(currentValue, 0.7), frameTime * 1.5);
    }
}
#endif

// {{SHADER_VERT}}
#ifdef {{SHADER_VERT}}
void main()
{
    gl_Position = ftransform();
}
#endif
