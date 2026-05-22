// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/atmosphere.glsl"

//layout({{IMG_ATMOSPHERE_LUT_FORMAT}}) uniform writeonly image2D {{IMG_ATMOSPHERE_LUT}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
const ivec3 workGroups = ivec3(16, 4, 1); // 128x32 LUT

void main()
{
//    ivec2 pixelCoord = ivec2(gl_GlobalInvocationID.xy);
//    ivec2 lutSize = ivec2(128, 32);
//    if (any(greaterThanEqual(pixelCoord, lutSize))) {
//        return;
//    }
//
//    vec2 uv = (vec2(pixelCoord) + 0.5) / vec2(lutSize);
//    imageStore({{IMG_ATMOSPHERE_LUT}}, pixelCoord, computeAtmosphereLUT(uv));
}
#endif
