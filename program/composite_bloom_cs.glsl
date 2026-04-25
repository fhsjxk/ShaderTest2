// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/common.glsl"
#include "/lib/options.glsl"

uniform sampler2D noisetex;
uniform sampler2D {{RT_BACK}};

uniform float viewWidth;
uniform float viewHeight;

layout({{IMG_BACK_FORMAT}}) uniform writeonly image2D {{IMG_BACK}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

const vec2 workGroupsRender = vec2(1.0, 1.0);

void main()
{
    ivec2 pixelCoord = ivec2(gl_GlobalInvocationID.xy);
    ivec2 fullRes = ivec2(viewWidth, viewHeight);
    if (any(greaterThanEqual(pixelCoord, fullRes))) {
        return;
    }

    vec2 uv = (vec2(pixelCoord) + 0.5) / vec2(viewWidth, viewHeight);

    vec3 color = texelFetch({{RT_BACK}}, pixelCoord, 0).rgb;
    
    float w = 4.0 / viewWidth;
    float h = 4.0 / viewHeight;

    float intensity = 1.0;

    vec2 dither = (texture(noisetex, uv * vec2(viewWidth, viewHeight) / 128.0).rg - 0.5) * 0.005;
    
    vec3 bloomSum = vec3(0);

    int mips = textureQueryLevels({{RT_BACK}});
    for(int i = 2; i < mips - 1; i++)
    {
        vec3 bloom = vec3(0);

        bloom += textureLod({{RT_BACK}}, uv + dither + vec2(-w, h), i).rgb * 0.1;
        bloom += textureLod({{RT_BACK}}, uv + dither + vec2(0, h), i).rgb * 0.2;
        bloom += textureLod({{RT_BACK}}, uv + dither + vec2(w, h), i).rgb * 0.1;

        bloom += textureLod({{RT_BACK}}, uv + dither + vec2(-w, 0), i).rgb * 0.2;
        bloom += textureLod({{RT_BACK}}, uv + dither + vec2(0, 0), i).rgb * 0.2;
        bloom += textureLod({{RT_BACK}}, uv + dither + vec2(w, 0), i).rgb * 0.2;

        bloom += textureLod({{RT_BACK}}, uv + dither + vec2(-w, -h), i).rgb * 0.1;
        bloom += textureLod({{RT_BACK}}, uv + dither + vec2(0, -h), i).rgb * 0.2;
        bloom += textureLod({{RT_BACK}}, uv + dither + vec2(w, -h), i).rgb * 0.1;

        bloomSum += bloom * intensity;

        w *= 2.0;
        h *= 2.0;
        dither *= 2.0;
        intensity *= 0.97;
    }

    bloomSum /= float(mips - 3);

    vec3 finalColor = mix(color, bloomSum, 0.2);

    imageStore({{IMG_BACK}}, pixelCoord, vec4(finalColor, 1.0));
}
#endif
