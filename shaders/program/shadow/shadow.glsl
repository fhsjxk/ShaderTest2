// Shadow pass: writes the alpha-tested depth used by the shadow map.

// {{SHADER_FRAG}}
#ifdef {{SHADER_FRAG}}
#include "/lib/lighting/shadow.glsl"

uniform sampler2D gtexture;

in float alpha;
in vec2 texcoord;

void main()
{
    if (texture(gtexture, texcoord).a * alpha < ALPHA_TEST_THRESHOLD)
    {
        discard;
    }
}
#endif

// {{SHADER_VERT}}
#ifdef {{SHADER_VERT}}
#include "/lib/lighting/shadow.glsl"

out float alpha;
out vec2 texcoord;

void main()
{
    gl_Position = ftransform();
    gl_Position.xyz = distortShadowClipPos(gl_Position.xyz);
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    alpha = gl_Color.a;
}
#endif
