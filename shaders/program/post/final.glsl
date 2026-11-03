// {{SHADER_FRAG}}
#ifdef {{SHADER_FRAG}}
#include "/lib/prelude.glsl"
#include "/lib/universal/buffers.glsl"

uniform sampler2D {{RT_HDR}};
uniform sampler2D {{RT_BLOOM1}};

#ifdef DEBUG_VIEW
uniform sampler2D {{RT_ALBEDO}};
uniform sampler2D {{RT_NORMAL}};
uniform sampler2D {{RT_LIGHTMAP}};
#endif

in vec2 texcoord;
layout(location = 0) out vec4 color;

// Radial vignette: clear inside VIGNETTE_START, fully dark at VIGNETTE_END
// (distance is measured in screen UV units from the centre).
const float VIGNETTE_START = 0.3;
const float VIGNETTE_END   = 1.7;

// Scene gain applied after bloom and exposure, before the tonemap curve.
const float PRE_TONEMAP_GAIN = 0.7;

// ACES filmic approximation (Narkowicz fit).
vec3 aces(vec3 x)
{
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

void main()
{
    ivec2 pixelCoordinate = ivec2(gl_FragCoord.xy);

    vec3 hdr = texelFetch({{RT_HDR}}, pixelCoordinate, 0).rgb;
    hdr += texture({{RT_BLOOM1}}, texcoord).rgb * BLOOM_STRENGTH;
    hdr *= exposureBlock.exposure * PRE_TONEMAP_GAIN;

    color.rgb = pow(aces(hdr), vec3(1.0 / GAMMA));

    float vignetteMask = 1.0 - smoothstep(VIGNETTE_START, VIGNETTE_END, distance(texcoord, vec2(0.5, 0.5))) * VIGNETTE_AMOUNT;
    color.rgb *= vignetteMask * vignetteMask;

    #ifdef DEBUG_VIEW
    vec2 viewCoordinate = fract(texcoord * 2.0);

    if (texcoord.x < 0.5 && texcoord.y >= 0.5)
    {
        color.rgb = pow(aces(texelFetch({{RT_HDR}}, ivec2(texcoord * vec2(textureSize({{RT_HDR}}, 0))), 0).rgb), vec3(1.0 / GAMMA));
    }
    else if (texcoord.x >= 0.5 && texcoord.y >= 0.5)
    {
        color.rgb = texture({{RT_ALBEDO}}, viewCoordinate).rgb;
    }
    else if (texcoord.x < 0.5 && texcoord.y < 0.5)
    {
        color.rgb = texture({{RT_NORMAL}}, viewCoordinate).rgb;
    }
    else
    {
        color.rgb = texture({{RT_LIGHTMAP}}, viewCoordinate).rgb;
    }

    // Dot in each quadrant centre so the split is easy to read.
    const float DOT_SIZE = 0.001;
    vec2 localCoordinate = fract(texcoord * 2.0) - 0.5;
    float dotMask = 1.0 - smoothstep(DOT_SIZE, DOT_SIZE + 0.001, length(localCoordinate));
    color.rgb = mix(color.rgb, vec3(1.0), dotMask);
    #endif

    color.a = 1.0;
}
#endif

// {{SHADER_VERT}}
#ifdef {{SHADER_VERT}}
out vec2 texcoord;

void main()
{
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
#endif
