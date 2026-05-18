// SHADER_COMP
#ifdef SHADER_COMP
#include "/lib/atmosphere.glsl"

layout(rgba8) uniform writeonly image2D colorimg7;
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
const ivec3 workGroups = ivec3(32, 8, 1); // 256x64 LUT

void main()
{
    ivec2 pixelCoord = ivec2(gl_GlobalInvocationID.xy);
    ivec2 lutSize = ivec2(256, 64);
    if (any(greaterThanEqual(pixelCoord, lutSize))) {
        return;
    }

    vec2 uv = (vec2(pixelCoord) + 0.5) / vec2(lutSize);
    imageStore(colorimg7, pixelCoord, vec4(computeTransmittanceLUT(uv), 1.0));
}
#endif
