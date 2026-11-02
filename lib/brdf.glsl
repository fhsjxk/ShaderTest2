#ifndef BRDF
#define BRDF

#include "/lib/prelude.glsl"

// Normalised GGX distribution (D term only). roughness is perceptual 0..1.
float specularGGX(float NoH, float roughness)
{
    float a  = roughness * roughness;
    float a2 = a * a;
    float denom = NoH * NoH * (a2 - 1.0) + 1.0;
    return a2 / (PI * denom * denom);
}

// Schlick Fresnel with a custom reflectance at normal incidence.
float fresnelSchlickF0(float NdotV, float f0)
{
    return f0 + (1.0 - f0) * pow(1.0 - NdotV, 5.0);
}

#endif
