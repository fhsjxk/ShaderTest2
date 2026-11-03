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

    // Weighted mean of the per-block log2(luma). The luminance buffer is tiny
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

    // Undo the log encoding: the weighted mean of log2(luma) is the geometric
    // mean of luma.
    float averageLuma = exp2(weightedSum / max(weightSum, EPS));

    // exposure = TARGET * (REFERENCE_LUMA / averageLuma)^STRENGTH, so the
    // reference scene receives exactly TARGET and every other scene is pulled
    // towards it by STRENGTH.
    float strength = clamp(EXPOSURE_ADAPT_STRENGTH, 0.0, 1.0);
    float target = EXPOSURE_TARGET
                 * pow(EXPOSURE_REFERENCE_LUMA / max(averageLuma, EPS), strength);
    target = clamp(target, EXPOSURE_MIN, EXPOSURE_MAX);

    // Frame-rate independent adaptation; EXPOSURE_ADAPT_RATE is 1/time-constant.
    float blend = 1.0 - exp(-frameTime * EXPOSURE_ADAPT_RATE);
    exposureBlock.exposure = mix(exposureBlock.exposure, target, blend);
}
#endif
