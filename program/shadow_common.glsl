// Shared shadow utility functions

#ifndef SHADOW_COMMON_UTILS
#define SHADOW_COMMON_UTILS

vec3 distortShadowClipPos(vec3 shadowClipPosition)
{
    float distortionFactor = length(shadowClipPosition.xy);
    distortionFactor += 0.1;
    shadowClipPosition.xy /= distortionFactor;
    shadowClipPosition.z *= 0.5;
    return shadowClipPosition;
}

#endif

// {{SHADER_FRAG}}
#ifdef {{SHADER_FRAG}}
uniform sampler2D gtexture;

in float alpha;
in vec2 texcoord;

void main()
{
    if (texture(gtexture, texcoord).a * alpha < 0.52)
    {
        discard;
    }
}
#endif

// {{SHADER_VERT}}
#ifdef {{SHADER_VERT}}
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