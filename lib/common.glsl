#ifndef COMMON

#define COMMON

#define PI 3.141592653589793

{{GLOBAL_SETTINGS}}

{{RT_FORMATS}}

float saturate(float x)
{
  return clamp(x, 0.0, 1.0);
}

vec3 saturate(vec3 x)
{
  return clamp(x, vec3(0.0), vec3(1.0));
}


vec3 adjustSaturationFast(vec3 color, float s)
{
    float luma = (color.r + color.g + color.b) * 0.3333;
    return mix(vec3(luma), color, s);
}

float getBrightness(vec3 color)
{
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}


float specularGGX(float NoH, float roughness)
{
    float a  = roughness * roughness;
    float a2 = a * a;
    float denom = NoH * NoH * (a2 - 1.0) + 1.0;
    return a2 / (PI * denom * denom);
}

float specularBlinnPhong(float NoH, float exponent)
{
    return (exponent + 2.0) * pow(NoH, exponent) * (1.0 / (2.0 * PI));
}

float RoughnessToExponent(float roughness)
{
    float r = max(roughness, 0.001);
    return 2.0 / (r * r) - 2.0;
}

#endif