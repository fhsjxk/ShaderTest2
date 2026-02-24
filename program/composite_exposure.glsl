// {{SHADER_FRAG}}
#ifdef {{SHADER_FRAG}}

uniform sampler2D {RT_BACK};
uniform sampler2D {RT_LIGHTING_LUT};

in vec2 texcoord;

// LOCAL SETTINGS
const bool {RT_BACK}MipmapEnabled = true;

/* RENDERTARGETS: {{RT_BACK}} */
layout(location = 0) out vec4 color;

void main()
{
    ivec2 pixelCoord = ivec2(gl_FragCoord.xy);
    float value = texelFetch({RT_LIGHTING_LUT}, ivec2({{POS_LIGHTING_LUT_VALUE}}), 0).r;
    color.rgb = texelFetch({RT_BACK}, pixelCoord, 0).rgb / mix(value, 1.0, 0.05) / 3.0;
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