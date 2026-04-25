// {{SHADER_FRAG}}
#ifdef {{SHADER_FRAG}}

void main()
{
    discard;
}
#endif

// {{SHADER_VERT}}
#ifdef {{SHADER_VERT}}

void main()
{
    gl_Position = vec4(0.0, 0.0, 0.0, 1.0);
}
#endif