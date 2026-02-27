// {{SHADER_FRAG}}
#ifdef {{SHADER_FRAG}}
#include "/lib/atmosphere.glsl"

in vec2 texcoord;

/* RENDERTARGETS: {RT_TRANSMIT_LUT} */
layout(location = 0) out vec4 outColor;

void main()
{
    outColor = computeTransmittanceLUT(texcoord);
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