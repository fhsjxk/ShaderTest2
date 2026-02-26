// {{SHADER_FRAG}}
#ifdef {{SHADER_FRAG}}
#include "/lib/common.glsl"
#include "/lib/options.glsl"

uniform sampler2D noisetex;
uniform sampler2D {{RT_BACK}};

uniform float viewWidth;
uniform float viewHeight;

uniform float frameTimeCounter;

in vec2 texcoord;

// LOCAL SETTINGS
const bool {{RT_BACK}}MipmapEnabled = true;

/* RENDERTARGETS: {RT_BACK} */
layout(location = 0) out vec4 outColor;

void main()
{
    vec3 color = texelFetch({{RT_BACK}}, ivec2(gl_FragCoord.xy), 0).rgb;
    outColor.rgb = color;
    //outColor.rgb = texture({{RT_BACK}}, texcoord).rgb;
    float w = 4.0 / viewWidth;
    float h = 4.0 / viewHeight;

    float intensity = 1.0;

    vec2 dither = (texture(noisetex, texcoord * vec2(viewWidth, viewHeight) / 128.0).rg - 0.5) * 0.005;
    
    vec3 bloomSum = vec3(0);

    int mips = textureQueryLevels({{RT_BACK}});
    for(int i = 2; i < mips - 1; i++)
    {
        vec3 bloom = vec3(0);

        bloom += textureLod({{RT_BACK}}, texcoord + dither + vec2(-w, h), i).rgb * 0.1;
        bloom += textureLod({{RT_BACK}}, texcoord + dither + vec2(0, h), i).rgb * 0.2;
        bloom += textureLod({{RT_BACK}}, texcoord + dither + vec2(w, h), i).rgb * 0.1;

        bloom += textureLod({{RT_BACK}}, texcoord + dither + vec2(-w, 0), i).rgb * 0.2;
        bloom += textureLod({{RT_BACK}}, texcoord + dither + vec2(0, 0), i).rgb * 0.2;
        bloom += textureLod({{RT_BACK}}, texcoord + dither + vec2(w, 0), i).rgb * 0.2;

        bloom += textureLod({{RT_BACK}}, texcoord + dither + vec2(-w, -h), i).rgb * 0.1;
        bloom += textureLod({{RT_BACK}}, texcoord + dither + vec2(0, -h), i).rgb * 0.2;
        bloom += textureLod({{RT_BACK}}, texcoord + dither + vec2(w, -h), i).rgb * 0.1;

        bloomSum += bloom * intensity;

        w *= 2.0;
        h *= 2.0;
        dither *= 2.0;
        intensity *= 0.97;
        //intensity -= 0.05;

        //bloom += textureLod({{RT_BACK}}, texcoord + vec2(0, 0), i).rgb * 1.6;
    }
    bloomSum /= float(mips - 3);

    outColor.rgb = mix(color, bloomSum, 0.2);
}
#endif

// {{SHADER_VERT}}
#ifdef {{SHADER_VERT}}
out vec2 texcoord;

void main()
{
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
#endif