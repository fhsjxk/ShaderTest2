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
vec3 fresnelSchlick(float NdotV, vec3 f0)
{
    return f0 + (1.0 - f0) * pow(1.0 - NdotV, 5.0);
}

// Same, scalar form.
float fresnelSchlick(float NdotV, float f0)
{
    return f0 + (1.0 - f0) * pow(1.0 - NdotV, 5.0);
}

vec3 fresnelSchlick(float NdotV, vec3 f0, float f90)
{
    return f0 + (f90 - f0) * pow(1.0 - NdotV, 5.0);
}

// Same, scalar form.
float fresnelSchlick(float NdotV, float f0, float f90)
{
    return f0 + (f90 - f0) * pow(1.0 - NdotV, 5.0);
}

// Fully assembled specular BRDF: returns the radiance leaving the surface for an
// incoming irradiance of 1 along L.
vec3 specularBRDF(vec3 N, vec3 V, vec3 L, float roughness, vec3 f0)
{
    vec3 H = normalize(V + L);
    float NdotL = max(dot(N, L), 1e-4);
    float NdotV = max(dot(N, V), 1e-4);
    float NoH = max(dot(N, H), 0.0);

    float D = distributionGGX(NoH, roughness);
    float G = geometrySmithGGX(NdotV, NdotL, roughness);
    vec3  F = fresnelSchlick(NdotV, f0);

    return D * G * F / (4.0 * NdotL * NdotV);
}

vec3 specularBRDF(vec3 N, vec3 V, vec3 L, float roughness, vec3 f0, float f90)
{
    vec3 H = normalize(V + L);
    float NdotL = max(dot(N, L), 1e-4);
    float NdotV = max(dot(N, V), 1e-4);
    float NoH = max(dot(N, H), 0.0);

    float D = distributionGGX(NoH, roughness);
    float G = geometrySmithGGX(NdotV, NdotL, roughness);
    vec3  F = fresnelSchlick(NdotV, f0, f90);

    return D * G * F / (4.0 * NdotL * NdotV);
}

#endif
