// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/prelude.glsl"
#include "/lib/utility/color.glsl"
#include "/lib/universal/buffers.glsl"
#include "/lib/lighting/tuning.glsl"

uniform sampler2D {{RT_HDR}};

// One texel holds the average of a screen block: .r = log2(luma),
// .g = centre weight. adapt_cs reduces these into a single multiplier.
layout({{RT_LUM_FORMAT}}) uniform writeonly image2D {{RT_LUM_IMG}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
const vec2 workGroupsRender = vec2({{RT_LUM_SIZE_X}}, {{RT_LUM_SIZE_Y}});

// Sampling density per block. Deliberately sparse: the block is ~32x32 screen
// pixels, so 16 taps is a sample rather than an average, which is fine because
// adapt_cs then averages ~2000 blocks. Raise it only if the adaptation is noisy.
const int MEASURE_TAPS = 4;

void main()
{
    ivec2 pixelCoordinate = ivec2(gl_GlobalInvocationID.xy);
    ivec2 lumSize = imageSize({{RT_LUM_IMG}});
    if (any(greaterThanEqual(pixelCoordinate, lumSize)))
    {
        return;
    }

    vec2 uv      = (vec2(pixelCoordinate) + 0.5) / vec2(lumSize);
    vec2 blockUv = 1.0 / vec2(lumSize);

    float lumaSum = 0.0;
    for (int y = 0; y < MEASURE_TAPS; ++y)
    {
        for (int x = 0; x < MEASURE_TAPS; ++x)
        {
            vec2 offset = (vec2(x, y) + 0.5) / float(MEASURE_TAPS) - 0.5;
            lumaSum += getBrightness(texture({{RT_HDR}}, uv + offset * blockUv).rgb);
        }
    }
    float luma = lumaSum / float(MEASURE_TAPS * MEASURE_TAPS);

    // Log domain: adapt_cs averages these, which is the geometric mean of luma.
    float encoded = log2(max(luma, EPS));

    vec2 centered = uv - 0.5;
    float weight = exp(-dot(centered, centered) * EXPOSURE_CENTER_FALLOFF);

    imageStore({{RT_LUM_IMG}}, pixelCoordinate, vec4(encoded, weight, 0.0, 1.0));
}
#endif
