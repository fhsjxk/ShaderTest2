// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/prelude.glsl"

// Shared between setup1 / composite2 / composite7 (matched by binding index).
layout(std430, binding = 0) buffer Exposure {
    float value;
} exposure;

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(1, 1, 1);

// Seed value so the first frame is not black before adaptation converges.
const float EXPOSURE_INITIAL = 0.3;

void main()
{
    exposure.value = EXPOSURE_INITIAL;
}
#endif
