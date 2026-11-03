// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/atmosphere.glsl"

layout({{IMG_TRANSMIT_LUT_FORMAT}}) uniform writeonly image2D {{IMG_TRANSMIT_LUT}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
const ivec3 workGroups = ivec3({{IMG_TRANSMIT_LUT_SIZE_X}} / 8, {{IMG_TRANSMIT_LUT_SIZE_Y}} / 8, 1);
const ivec2 LUT_SIZE = ivec2({{IMG_TRANSMIT_LUT_SIZE_X}}, {{IMG_TRANSMIT_LUT_SIZE_Y}});

void main()
{
    ivec2 pixelCoordinate = ivec2(gl_GlobalInvocationID.xy);
    if (any(greaterThanEqual(pixelCoordinate, LUT_SIZE)))
    {
        return;
    }

    vec2 uv = (vec2(pixelCoordinate) + 0.5) / vec2(LUT_SIZE);

    #ifdef ENABLE_SPECTRAL
    imageStore({{IMG_TRANSMIT_LUT}}, pixelCoordinate, computeTransmittanceLUT(uv));
    #else
    imageStore({{IMG_TRANSMIT_LUT}}, pixelCoordinate, vec4(computeTransmittanceLUT(uv), 1.0));
    #endif
}
#endif
