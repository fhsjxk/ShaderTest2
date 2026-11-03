// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/prelude.glsl"
#include "/lib/utility/color.glsl"
#include "/lib/lighting/tuning.glsl"

uniform sampler2D {{RT_HDR}};

// One texel holds the average of a screen block: .r = encoded luma,
// .g = centre weight. Decoding happens in adapt_cs.
layout({{RT_LUM_FORMAT}}) uniform writeonly image2D {{RT_LUM_IMG}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
const vec2 workGroupsRender = vec2({{RT_LUM_SIZE_X}}, {{RT_LUM_SIZE_Y}});

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

    // Sparse taps across the block; bilinear filtering fills the gaps.
    float lumaSum = 0.0;
    for (int y = 0; y < EXPOSURE_MEASURE_TAPS; ++y)
    {
        for (int x = 0; x < EXPOSURE_MEASURE_TAPS; ++x)
        {
            vec2 offset = (vec2(x, y) + 0.5) / float(EXPOSURE_MEASURE_TAPS) - 0.5;
            lumaSum += getBrightness(texture({{RT_HDR}}, uv + offset * blockUv).rgb);
        }
    }
    float luma = lumaSum / float(EXPOSURE_MEASURE_TAPS * EXPOSURE_MEASURE_TAPS);

    // Perceptual encoding: geometric mean (log) or sqrt, selected in tuning.
    float encoded = EXPOSURE_USE_LOG != 0
                  ? log2(max(luma, EXPOSURE_EPS))
                  : sqrt(max(luma, 0.0));

    vec2 centered = uv - 0.5;
    float weight = exp(-dot(centered, centered) * EXPOSURE_CENTER_FALLOFF);

    imageStore({{RT_LUM_IMG}}, pixelCoordinate, vec4(encoded, weight, 0.0, 1.0));
}
#endif
