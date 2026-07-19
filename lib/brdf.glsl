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

#endif
