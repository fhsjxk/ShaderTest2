// SHADER_COMP
#ifdef SHADER_COMP
uniform sampler2D colortex0;
uniform sampler2D colortex6;

layout(r11f_g11f_b10f) uniform writeonly image2D colorimg0;
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

    float value = texelFetch(colortex6, ivec2(11, 0), 0).r;
    vec3 color = texelFetch(colortex0, pixelCoord, 0).rgb / mix(value, 1.0, 0.02) * 0.5;
    
    imageStore(colorimg0, pixelCoord, vec4(color, 1.0));
}
#endif