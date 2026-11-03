// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/prelude.glsl"
#include "/lib/utility/color.glsl"
#include "/lib/lighting/tuning.glsl"

// 13-tap downsample (COD:AW kernel). Level 0 reads the scene and applies the
// bright-pass prefilter; every other level reads the previous, larger level.
#if BLOOM_LEVEL == 0
    #define SRC_TEX    {{RT_HDR}}
    #define DST_IMG    {{RT_BLOOM1_IMG}}
    #define DST_FORMAT {{RT_BLOOM1_FORMAT}}
#elif BLOOM_LEVEL == 1
    #define SRC_TEX    {{RT_BLOOM1}}
    #define DST_IMG    {{RT_BLOOM2_IMG}}
    #define DST_FORMAT {{RT_BLOOM2_FORMAT}}
#elif BLOOM_LEVEL == 2
    #define SRC_TEX    {{RT_BLOOM2}}
    #define DST_IMG    {{RT_BLOOM3_IMG}}
    #define DST_FORMAT {{RT_BLOOM3_FORMAT}}
#elif BLOOM_LEVEL == 3
    #define SRC_TEX    {{RT_BLOOM3}}
    #define DST_IMG    {{RT_BLOOM4_IMG}}
    #define DST_FORMAT {{RT_BLOOM4_FORMAT}}
#elif BLOOM_LEVEL == 4
    #define SRC_TEX    {{RT_BLOOM4}}
    #define DST_IMG    {{RT_BLOOM5_IMG}}
    #define DST_FORMAT {{RT_BLOOM5_FORMAT}}
#elif BLOOM_LEVEL == 5
    #define SRC_TEX    {{RT_BLOOM5}}
    #define DST_IMG    {{RT_BLOOM6_IMG}}
    #define DST_FORMAT {{RT_BLOOM6_FORMAT}}
#elif BLOOM_LEVEL == 6
    #define SRC_TEX    {{RT_BLOOM6}}
    #define DST_IMG    {{RT_BLOOM7_IMG}}
    #define DST_FORMAT {{RT_BLOOM7_FORMAT}}
#else
    #define SRC_TEX    {{RT_BLOOM7}}
    #define DST_IMG    {{RT_BLOOM8_IMG}}
    #define DST_FORMAT {{RT_BLOOM8_FORMAT}}
#endif

uniform sampler2D SRC_TEX;
layout(DST_FORMAT) uniform writeonly image2D DST_IMG;

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
// Level 0 writes half resolution, each further level halves again.
const vec2 workGroupsRender = vec2(0.5 / float(1 << BLOOM_LEVEL));

vec3 sampleSource(vec2 uv)
{
    return texture(SRC_TEX, uv).rgb;
}

// Group weights sum to 1: centre 1/8, axis neighbours 1/16, corners 1/32.
vec3 downsample13(vec2 uv, vec2 texel)
{
    vec3 a = sampleSource(uv + texel * vec2(-1.0, -1.0));
    vec3 b = sampleSource(uv + texel * vec2( 0.0, -1.0));
    vec3 c = sampleSource(uv + texel * vec2( 1.0, -1.0));
    vec3 d = sampleSource(uv + texel * vec2(-0.5, -0.5));
    vec3 e = sampleSource(uv + texel * vec2( 0.5, -0.5));
    vec3 f = sampleSource(uv + texel * vec2(-1.0,  0.0));
    vec3 g = sampleSource(uv);
    vec3 h = sampleSource(uv + texel * vec2( 1.0,  0.0));
    vec3 i = sampleSource(uv + texel * vec2(-0.5,  0.5));
    vec3 j = sampleSource(uv + texel * vec2( 0.5,  0.5));
    vec3 k = sampleSource(uv + texel * vec2(-1.0,  1.0));
    vec3 l = sampleSource(uv + texel * vec2( 0.0,  1.0));
    vec3 m = sampleSource(uv + texel * vec2( 1.0,  1.0));

    vec3 result = g * 0.125;
    result += (a + c + k + m) * 0.03125;
    result += (b + f + h + l) * 0.0625;
    result += (d + e + i + j) * 0.125;
    return result;
}

// Bright-pass prefilter.
//
// Each pixel contributes with a weight in [0, 1]:
//   brightness >= BLOOM_THRESHOLD                       -> 1, fully included
//   brightness <= BLOOM_THRESHOLD * (1 - SMOOTH)        -> 0, fully excluded
//   in between                                          -> smoothstep ramp
//
// SMOOTH is a ratio rather than an absolute width, so the softness stays the
// same relative amount when BLOOM_THRESHOLD is changed.
vec3 bloomPrefilter(vec3 color)
{
    float brightness = getBrightness(color);

    float threshold   = max(BLOOM_THRESHOLD, 1e-4);
    float smoothRatio = clamp(BLOOM_THRESHOLD_SMOOTH, 0.0, 1.0);

    // Lower edge of the ramp, as a fraction of the threshold so the softness
    // scales with it. The -1e-4 keeps smoothstep defined when the ratio is 0
    // without moving where the threshold itself takes effect.
    float lowerBound = min(threshold * (1.0 - smoothRatio), threshold - 1e-4);

    float weight = smoothstep(lowerBound, threshold, brightness);

    return color * weight;
}

void main()
{
    ivec2 pixelCoordinate = ivec2(gl_GlobalInvocationID.xy);
    ivec2 dstSize = imageSize(DST_IMG);
    if (any(greaterThanEqual(pixelCoordinate, dstSize)))
    {
        return;
    }

    vec2 uv    = (vec2(pixelCoordinate) + 0.5) / vec2(dstSize);
    vec2 texel = 1.0 / vec2(textureSize(SRC_TEX, 0));

    vec3 color = downsample13(uv, texel);

    #if BLOOM_LEVEL == 0
    color = bloomPrefilter(color);
    #endif

    imageStore(DST_IMG, pixelCoordinate, vec4(color, 1.0));
}
#endif
