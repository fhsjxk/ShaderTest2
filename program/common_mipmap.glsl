// SHADER_FRAG
#ifdef SHADER_FRAG

uniform sampler2D colortex0;

in vec2 texcoord;

const bool colortex0MipmapEnabled = true;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main()
{
    color = texelFetch(colortex0, ivec2(gl_FragCoord.xy), 0);
}
#endif

// SHADER_VERT
#ifdef SHADER_VERT
out vec2 texcoord;

void main()
{
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
#endif