// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
uniform sampler2D {{RT_BACK}};
uniform sampler2D {{RT_LIGHTING_LUT}};

layout({{IMG_BACK_FORMAT}}) uniform writeonly image2D {{IMG_BACK}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
const vec2 workGroupsRender = vec2(1.0, 1.0);

uniform float viewWidth;
uniform float viewHeight;

void main()
{
    ivec2 pixelCoord = ivec2(gl_GlobalInvocationID.xy);
    ivec2 fullRes = ivec2(viewWidth, viewHeight);
    if (any(greaterThanEqual(pixelCoord, fullRes))) {
        return;
    }

    float value = texelFetch({{RT_LIGHTING_LUT}}, ivec2({{POS_LIGHTING_LUT_VALUE}}), 0).r;
    vec3 color = texelFetch({{RT_BACK}}, pixelCoord, 0).rgb / mix(value, 1.0, 0.05) * 0.5;
    
    imageStore({{IMG_BACK}}, pixelCoord, vec4(color, 1.0));
}
#endif