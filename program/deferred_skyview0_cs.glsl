// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/common.glsl"
#include "/lib/options.glsl"

uniform sampler2D depthtex0;

uniform float viewWidth;
uniform float viewHeight;

/* RENDERTARGETS: {RT_BACK} */
layout({{RT_BACK_FORMAT_IMG}}) uniform writeonly image2D {{RT_BACK_IMG}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
const vec2 workGroupsRender = vec2(1.0, 1.0);

void main()
{
    ivec2 pixelCoord = ivec2(gl_GlobalInvocationID.xy);
    ivec2 fullRes = ivec2(viewWidth, viewHeight);
    if (any(greaterThanEqual(pixelCoord, fullRes))) {
        return;
    }

    float skyMask = float(texelFetch(depthtex0, pixelCoord, 0).r == 1.0) * 100.0;
    imageStore({{RT_BACK_IMG}}, pixelCoord, vec4(skyMask, 0.0, 0.0, 1.0));
}
#endif
