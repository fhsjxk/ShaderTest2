// {{SHADER_FRAG}}
#ifdef {{SHADER_FRAG}}
uniform sampler2D {{RT_BACK}};

in vec2 texcoord;

// LOCAL SETTINGS

/* RENDERTARGETS: {RT_BACK} */
layout(location = 0) out vec4 color;

void main()
{
    // Dummy copy pass used to force Iris/OpenGL to regenerate RT_BACK mipmap chain.
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
