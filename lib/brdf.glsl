#ifndef BRDF
#define BRDF

float specularGGX(float NoH, float roughness)
{
    float a  = roughness * roughness;
    float a2 = a * a;
    float denom = NoH * NoH * (a2 - 1.0) + 1.0;
    return a2 / (PI * denom * denom);
}

// GTR: gamma=2 → GGX, gamma<2 → longer tail
float specularGTR(float NoH, float roughness, float gamma)
{
    float a  = roughness * roughness;
    float a2 = a * a;
    float num = (gamma - 1.0) * (a2 - 1.0);
    float denomNorm = PI * (1.0 - pow(a, 2.0 * (1.0 - gamma)));
    float denom = 1.0 + (a2 - 1.0) * NoH * NoH;
    return num / (denomNorm * pow(denom, gamma));
}

float specularBlinnPhong(float NoH, float exponent)
{
    return (exponent + 2.0) * pow(NoH, exponent) * (1.0 / (2.0 * PI));
}

float roughnessToExponent(float roughness)
{
    float r = max(roughness, 0.001);
    return 2.0 / (r * r) - 2.0;
}

// ── Fresnel approximations ───────────────────────────────────

// Schlick: F0 = 0.04 (default dielectric), F90 = 1.0
float fresnelSchlick(float NdotV)
{
    float f0 = 0.04;
    return f0 + (1.0 - f0) * pow(1.0 - NdotV, 5.0);
}

// Schlick with custom F0, F90 = 1.0
float fresnelSchlickF0(float NdotV, float f0)
{
    return f0 + (1.0 - f0) * pow(1.0 - NdotV, 5.0);
}

// Schlick with custom F90, F0 = 0.04
float fresnelSchlickF90(float NdotV, float f90)
{
    float f0 = 0.04;
    return f0 + (f90 - f0) * pow(1.0 - NdotV, 5.0);
}

// Schlick with both F0 and F90
float fresnelSchlickFull(float NdotV, float f0, float f90)
{
    return f0 + (f90 - f0) * pow(1.0 - NdotV, 5.0);
}

#endif
