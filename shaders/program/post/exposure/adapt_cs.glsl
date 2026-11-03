// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/prelude.glsl"
#include "/lib/universal/buffers.glsl"
#include "/lib/lighting/tuning.glsl"

uniform sampler2D {{RT_LUM}};
uniform float frameTime;

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(1, 1, 1);

void main()
{
    ivec2 lumSize = textureSize({{RT_LUM}}, 0);

    // Weighted mean of the per-block encoded luma. The luminance buffer is tiny
    // (1/32 of the screen), so a single invocation can reduce it directly.
    float weightedSum = 0.0;
    float weightSum = 0.0;
    for (int y = 0; y < lumSize.y; ++y)
    {
        for (int x = 0; x < lumSize.x; ++x)
        {
            vec2 value = texelFetch({{RT_LUM}}, ivec2(x, y), 0).rg;
            weightedSum += value.x * value.y;
            weightSum   += value.y;
        }
    }

    float encodedAverage = weightedSum / max(weightSum, EXPOSURE_EPS);
    float averageLuma = EXPOSURE_USE_LOG != 0
                      ? exp2(encodedAverage)
                      : encodedAverage * encodedAverage;

    float target = EXPOSURE_KEY / max(pow(averageLuma, EXPOSURE_CURVE), EXPOSURE_EPS);
    target = clamp(target, EXPOSURE_MIN, EXPOSURE_MAX);

    // Frame-rate independent temporal adaptation.
    float blend = 1.0 - exp(-frameTime * EXPOSURE_ADAPT_SPEED);
    exposureBlock.exposure = mix(exposureBlock.exposure, target, blend);
}
#endif
