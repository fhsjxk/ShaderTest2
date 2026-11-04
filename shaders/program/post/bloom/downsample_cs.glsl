// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/prelude.glsl"
#include "/lib/utility/color.glsl"
#include "/lib/universal/buffers.glsl"
#include "/lib/lighting/tuning.glsl"

// 13-tap downsample (COD:AW kernel). Level 0 reads the scene and applies the
// bright-pass prefilter; every other level reads the previous, larger level.
//
// The buffer pair and the dispatch scale are injected by the build, because one
// source serves every level and a single source cannot name the slots
// dynamically. BLOOM_LEVEL is only used for the level-0 prefilter below.
uniform sampler2D BLOOM_SRC;
layout({{RT_BLOOM1_FORMAT}}) uniform writeonly image2D BLOOM_DST_IMG;

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
// Relative dispatch size. Iris reads this from the *preprocessed* source with a
// plain float parse, so both components have to be numeric literals. An
// expression such as vec2(0.5 / float(1 << BLOOM_LEVEL)) is silently ignored and
// the pass quietly dispatches at full screen resolution instead.
const vec2 workGroupsRender = vec2(BLOOM_SCALE, BLOOM_SCALE);

vec3 sampleSource(vec2 uv)
{
    return texture(BLOOM_SRC, uv).rgb;
}

// Half-float ceiling that used to live here is now handled by guardHalf() at the
// point where the exposure multiply happens, so a single mechanism covers this
// pass, the RT_HDR stores and the pyramid accumulation. See
// lib/utility/guards.glsl.

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

// Bright-pass prefilter, evaluated in display-referred units (the caller has
// already applied the exposure), so 1.0 is display white and the threshold means
// the same thing regardless of scene brightness or the chosen unit scale.
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

    float threshold   = max(BLOOM_THRESHOLD, EPS);
    float smoothRatio = clamp(BLOOM_THRESHOLD_SMOOTH, 0.0, 1.0);

    // Lower edge of the ramp, as a fraction of the threshold so the softness
    // scales with it. The -EPS keeps smoothstep defined when the ratio is 0
    // without moving where the threshold itself takes effect.
    float lowerBound = min(threshold * (1.0 - smoothRatio), threshold - EPS);

    float weight = mix(smoothstep(lowerBound, threshold, brightness), 1.0, BLOOM_MIN_STRENGTH);

    return color * weight;
}

void main()
{
    ivec2 pixelCoordinate = ivec2(gl_GlobalInvocationID.xy);
    ivec2 dstSize = imageSize(BLOOM_DST_IMG);

    // A level is dropped only once it collapses to a single texel: anything with
    // more than one texel on either axis still carries the widest, flattest part
    // of the halo and is what makes the glow reach the far edge. Skipping the
    // write is safe because every colortex is cleared to zero each frame by
    // default, so the coarser pass above reads a zero level and adds nothing.
    if (max(dstSize.x, dstSize.y) <= 1)
    {
        return;
    }

    if (any(greaterThanEqual(pixelCoordinate, dstSize)))
    {
        return;
    }

    vec2 uv    = (vec2(pixelCoordinate) + 0.5) / vec2(dstSize);
    vec2 texel = 1.0 / vec2(textureSize(BLOOM_SRC, 0));

    vec3 color = downsample13(uv, texel);

    #if BLOOM_LEVEL == 0
    // Bloom is a sensor effect, so the chain works in display-referred space:
    // scale the scene radiance by the exposure first, then either threshold it
    // (mode 1) or take it whole (mode 0).
    //
    // Guarded here as well as at the RT_HDR store: that store bounds the scene
    // radiance, but this pass multiplies by the exposure (up to 20), so the
    // product can still leave the half-float range. The pyramid bounds its own
    // accumulation on every write.
    vec3 scaled = guardHalf(color * exposureBlock.exposure);

    #if BLOOM_MODE == 0
    color = scaled;
    #elif BLOOM_MODE == 1
    color = bloomPrefilter(scaled);
    #endif

    #endif

    imageStore(BLOOM_DST_IMG, pixelCoordinate, vec4(color, 1.0));
}
#endif
