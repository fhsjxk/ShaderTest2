// {{SHADER_FRAG}}
#ifdef {{SHADER_FRAG}}
uniform sampler2D {{RT_BACK}};

in vec2 texcoord;

// LOCAL SETTINGS
const bool {{RT_BACK}}MipmapEnabled = true;

/* RENDERTARGETS: {RT_BACK} */
layout(location = 0) out vec4 color;

void main()
{
    // Force mipmap regeneration for RT_BACK before compute passes sample textureLod.
    color = texelFetch({{RT_BACK}}, ivec2(gl_FragCoord.xy), 0);
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
