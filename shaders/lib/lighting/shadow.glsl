#ifndef SHADOW
#define SHADOW

// Shared shadow-map helpers. Pass bodies live in /program/shadow.glsl.

#include "/lib/prelude.glsl"

// Iris renders the shadow map with a dithered projection; undo the distortion
// when reconstructing clip positions.
vec3 distortShadowClipPos(vec3 shadowClipPosition)
{
    float distortionFactor = length(shadowClipPosition.xy);
    distortionFactor += 0.1;
    shadowClipPosition.xy /= distortionFactor;
    shadowClipPosition.z *= 0.5;
    return shadowClipPosition;
}

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position)
{
    vec4 homogeneousPosition = projectionMatrix * vec4(position, 1.0);
    return homogeneousPosition.xyz / homogeneousPosition.w;
}

#ifdef SHADER_COMP

vec3 getShadow(sampler2D shadowtex0, sampler2D shadowtex1, sampler2D shadowcolor0,
               vec3 shadowScreenPosition)
{
    float transparentShadow = step(shadowScreenPosition.z, texture(shadowtex0, shadowScreenPosition.xy).r);
    if (transparentShadow == 1.0)
    {
        return vec3(1.0);
    }

    float opaqueShadow = step(shadowScreenPosition.z, texture(shadowtex1, shadowScreenPosition.xy).r);
    if (opaqueShadow == 0.0)
    {
        return vec3(0.0);
    }

    vec4 shadowColor = texture(shadowcolor0, shadowScreenPosition.xy);
    return shadowColor.rgb * (1.0 - shadowColor.a);
}

vec4 getNoise(sampler2D noisetex, vec2 coordinate, vec2 viewSize)
{
    ivec2 screenCoordinate = ivec2(coordinate * viewSize);
    ivec2 noiseCoordinate = screenCoordinate % 64;
    return texelFetch(noisetex, noiseCoordinate, 0);
}

// Rotated 6x6 tap PCF. SHADOW_RADIUS is in shadow-map texels before the
// per-sample divide by the shadow map resolution.
const int   SHADOW_RANGE  = 3;
const float SHADOW_RADIUS = 0.5;
const int   SHADOW_SAMPLES = SHADOW_RANGE * SHADOW_RANGE * 4;

vec3 getSoftShadow(sampler2D shadowtex0, sampler2D shadowtex1, sampler2D shadowcolor0,
                   sampler2D noisetex, vec4 shadowClipPosition, vec2 uv, vec2 viewSize)
{
    float noise = getNoise(noisetex, uv, viewSize).r;
    float theta = noise * radians(360.0);
    float cosTheta = cos(theta);
    float sinTheta = sin(theta);
    mat2 rotation = mat2(cosTheta, -sinTheta, sinTheta, cosTheta);

    vec3 shadowAccumulation = vec3(0.0);

    for (int x = -SHADOW_RANGE; x < SHADOW_RANGE; x++)
    {
        for (int y = -SHADOW_RANGE; y < SHADOW_RANGE; y++)
        {
            vec2 offset = vec2(x, y) * SHADOW_RADIUS / float(SHADOW_RANGE);
            offset = rotation * offset;
            offset /= shadowMapResolution;
            vec4 offsetShadowClipPosition = shadowClipPosition + vec4(offset, 0.0, 0.0);
            offsetShadowClipPosition.z -= 0.001;
            offsetShadowClipPosition.xyz = distortShadowClipPos(offsetShadowClipPosition.xyz);
            vec3 shadowNDCPosition = offsetShadowClipPosition.xyz / offsetShadowClipPosition.w;
            vec3 shadowScreenPosition = shadowNDCPosition * 0.5 + 0.5;
            shadowAccumulation += getShadow(shadowtex0, shadowtex1, shadowcolor0, shadowScreenPosition);
        }
    }

    return shadowAccumulation / float(SHADOW_SAMPLES);
}

#endif // SHADER_COMP

#endif // SHADOW
