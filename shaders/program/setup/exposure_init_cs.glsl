// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/prelude.glsl"
#include "/lib/universal/buffers.glsl"
#include "/lib/lighting/tuning.glsl"

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(1, 1, 1);

void main()
{
    // Seed with EXPOSURE_TARGET: that is the steady state for the reference
    // scene, so a frame matching the calibration starts exactly on target.
    exposureBlock.exposure = EXPOSURE_TARGET;
    // exposureBlock.exposure = exposureBlock.exposure * 10.0;
}
#endif
