// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/prelude.glsl"

uniform sampler2D {{RT_BACK}};

// Shared between setup1 / composite2 / composite7 (matched by binding index).
layout(std430, binding = 0) buffer Exposure {
    float value;
} exposure;

layout({{IMG_BACK_FORMAT}}) uniform writeonly image2D {{IMG_BACK}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
const vec2 workGroupsRender = vec2(1.0, 1.0);

uniform float viewWidth;
uniform float viewHeight;

// The adapted value is only a reference: how much it is allowed to change the
// image, and the overall scene gain, are both purely empirical.
const float EXPOSURE_BLEND = 0.005;
const float EXPOSURE_GAIN  = 0.35;

void main()
{
    ivec2 pixelCoordinate = ivec2(gl_GlobalInvocationID.xy);
    ivec2 fullResolution = ivec2(viewWidth, viewHeight);
    if (any(greaterThanEqual(pixelCoordinate, fullResolution)))
    {
        return;
    }

    float value = exposure.value;
    vec3 color = texelFetch({{RT_BACK}}, pixelCoordinate, 0).rgb / mix(value, 1.0, EXPOSURE_BLEND) * EXPOSURE_GAIN;

    imageStore({{IMG_BACK}}, pixelCoordinate, vec4(color, 1.0));
}
#endif
