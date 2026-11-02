// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/prelude.glsl"
#include "/lib/color.glsl"

uniform float frameTime;
uniform sampler2D {{RT_BACK}};

// Shared between setup1 / composite2 / composite7 (matched by binding index).
layout(std430, binding = 0) buffer Exposure {
    float value;
} exposure;

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(1, 1, 1);

// Temporal adaptation: exponential average of the luma of the second-to-last
// mip. The exponent compresses the luma range, the speed is in 1/s.
const float EXPOSURE_RESPONSE_CURVE = 0.7;
const float EXPOSURE_ADAPT_SPEED    = 2.0;

void main()
{
    barrier();
    int level = max(textureQueryLevels({{RT_BACK}}) - 2, 0);
    float previousValue = exposure.value;
    float currentValue = getBrightness(textureLod({{RT_BACK}}, vec2(0.5), level).rgb);
    exposure.value = mix(previousValue, pow(currentValue, EXPOSURE_RESPONSE_CURVE), frameTime * EXPOSURE_ADAPT_SPEED);
}
#endif
