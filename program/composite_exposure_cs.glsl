// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
uniform sampler2D {{RT_BACK}};

layout(std430, binding = 0) buffer LightingLut {
    float value;
} lightingLut;

layout({{IMG_BACK_FORMAT}}) uniform writeonly image2D {{IMG_BACK}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
const vec2 workGroupsRender = vec2(1.0, 1.0);

uniform float viewWidth;
uniform float viewHeight;

void main()
{
    ivec2 pixelCoordinate = ivec2(gl_GlobalInvocationID.xy);
    //ivec2 pixelCoord = ivec2(gl_GlobalInvocationID.xy);$
    ivec2 fullResolution = ivec2(viewWidth, viewHeight);
    //ivec2 fullRes = ivec2(viewWidth, viewHeight);$
    if (any(greaterThanEqual(pixelCoordinate, fullResolution)))
    {
        return;
    }

    float value = lightingLut.value;
    vec3 color = texelFetch({{RT_BACK}}, pixelCoordinate, 0).rgb / mix(value, 1.0, 0.005) * 0.39;

    imageStore({{IMG_BACK}}, pixelCoordinate, vec4(color, 1.0));
}
#endif