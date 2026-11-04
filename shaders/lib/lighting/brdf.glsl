// Microfacet BRDF terms
//
// Energy-conserving Cook-Torrance: D * G * F / (4 NdotL NdotV). All terms are
// physically normalised, so the specular result is a radiance when multiplied by
// the incoming irradiance and NdotL — no artistic gain factor.

#ifndef LIGHTING_BRDF
#define LIGHTING_BRDF

#include "/lib/prelude.glsl"

// GGX / Trowbridge-Reitz normal distribution. roughness is perceptual 0..1.
float distributionGGX(float NoH, float roughness)
{
    float a  = roughness * roughness;
    float a2 = a * a;
    float denom = NoH * NoH * (a2 - 1.0) + 1.0;
    return a2 / (PI * denom * denom);
}

// Smith-Schlick masking-shadowing for the GGX distribution.
float geometrySmithGGX(float NdotV, float NdotL, float roughness)
{
    float k = (roughness + 1.0) * (roughness + 1.0) / 8.0;
    float gv = NdotV / (NdotV * (1.0 - k) + k);
    float gl = NdotL / (NdotL * (1.0 - k) + k);
    return gv * gl;
}

// Schlick Fresnel for a dielectric or conductor with a given reflectance at
// normal incidence.
//
// The base of the power is written as saturate(1 - NdotV) rather than plain
// 1 - NdotV: dot() of two unit vectors can land a few ULP above 1 in float32, and
// pow() of a negative number is undefined, so it comes out NaN. That happens
// exactly where the surface faces the camera, which is a couple of pixels at a
// time and only at particular view angles.
vec3 fresnelSchlick(float NdotV, vec3 f0)
{
    return f0 + (1.0 - f0) * pow(saturate(1.0 - NdotV), 5.0);
}

// Same, scalar form.
float fresnelSchlick(float NdotV, float f0)
{
    return f0 + (1.0 - f0) * pow(saturate(1.0 - NdotV), 5.0);
}

vec3 fresnelSchlick(float NdotV, vec3 f0, float f90)
{
    return f0 + (f90 - f0) * pow(saturate(1.0 - NdotV), 5.0);
}

// Same, scalar form.
float fresnelSchlick(float NdotV, float f0, float f90)
{
    return f0 + (f90 - f0) * pow(saturate(1.0 - NdotV), 5.0);
}

// Fully assembled specular BRDF: returns the radiance leaving the surface for an
// incoming irradiance of 1 along L.
//
// Both cosines are clamped into [EPS, 1] — the lower bound keeps the division
// finite, the upper bound keeps 1 - NdotV non-negative, which fresnelSchlick
// needs for its pow(). A dot product of two unit vectors can exceed 1 by a few
// ULP, and only the upper clamp costs nothing visually. The lower bound does not
// have to be large: the Smith term cancels the
// 4 * NdotL * NdotV denominator, so the result stays bounded as the cosines
// approach zero.
vec3 specularBRDF(vec3 N, vec3 V, vec3 L, float roughness, vec3 f0)
{
    vec3 H = normalize(V + L);
    float NdotL = clamp(dot(N, L), EPS, 1.0);
    float NdotV = clamp(dot(N, V), EPS, 1.0);
    float NoH = clamp(dot(N, H), 0.0, 1.0);

    float D = distributionGGX(NoH, roughness);
    float G = geometrySmithGGX(NdotV, NdotL, roughness);
    vec3  F = fresnelSchlick(NdotV, f0);

    return D * G * F / (4.0 * NdotL * NdotV);
}

vec3 specularBRDF(vec3 N, vec3 V, vec3 L, float roughness, vec3 f0, float f90)
{
    vec3 H = normalize(V + L);
    float NdotL = clamp(dot(N, L), EPS, 1.0);
    float NdotV = clamp(dot(N, V), EPS, 1.0);
    float NoH = clamp(dot(N, H), 0.0, 1.0);

    float D = distributionGGX(NoH, roughness);
    float G = geometrySmithGGX(NdotV, NdotL, roughness);
    vec3  F = fresnelSchlick(NdotV, f0, f90);

    return D * G * F / (4.0 * NdotL * NdotV);
}

#endif
