// {{SHADER_FRAG}}
#ifdef {{SHADER_FRAG}}

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

void main()
{
    ivec2 pixelPosition = ivec2(gl_FragCoord.xy - vec2(0.5));

    //if pixelPosition == ivec2(0, 0)
    //{
//
    //}

}
#endif

// {{SHADER_VERT}}
#ifdef {{SHADER_VERT}}
void main()
{
    gl_Position = ftransform();
}
#endif