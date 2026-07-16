#ifndef SHADOW_UTILS
#define SHADOW_UTILS

vec3 distortShadowClipPos(vec3 shadowClipPosition)
//vec3 distortShadowClipPos(vec3 shadowClipPos)$
{
    float distortionFactor = length(shadowClipPosition.xy);
    distortionFactor += 0.1;
    shadowClipPosition.xy /= distortionFactor;
    shadowClipPosition.z *= 0.5;
    return shadowClipPosition;
}

#endif
