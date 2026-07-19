// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/atmosphere.glsl"

layout({{IMG_TRANSMIT_LUT_FORMAT}}) uniform writeonly image2D {{IMG_TRANSMIT_LUT}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
const ivec3 workGroups = ivec3(32, 8, 1); // 256x64 LUT

void main()
{
    ivec2 pixelCoordinate = ivec2(gl_GlobalInvocationID.xy);
    //ivec2 pixelCoord = ivec2(gl_GlobalInvocationID.xy);$
    ivec2 lutSize = ivec2(256, 64);
    if (any(greaterThanEqual(pixelCoordinate, lutSize)))
    {
        return;
    }

    vec2 uv = (vec2(pixelCoordinate) + 0.5) / vec2(lutSize);
    #if ENABLE_SPECTRAL
    imageStore({{IMG_TRANSMIT_LUT}}, pixelCoordinate, computeTransmittanceLUT(uv));
    #else
    imageStore({{IMG_TRANSMIT_LUT}}, pixelCoordinate, vec4(computeTransmittanceLUT(uv), 1.0));
    #endif
}
#endif
