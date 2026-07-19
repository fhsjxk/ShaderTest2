#ifndef COLOR
#define COLOR

float getBrightness(vec3 color)
{
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

vec3 adjustSaturationFast(vec3 color, float s)
{
    float luma = (color.r + color.g + color.b) * 0.3333;
    return mix(vec3(luma), color, s);
}

vec3 calcAdjustSaturationHDR(vec3 color, float saturation)
{
    float L = getBrightness(color);
    vec3 res = max(mix(vec3(L), color, saturation), 0.0);
    
    if(saturation > 1.0) 
    {
        float newL = getBrightness(res);
        res *= (L / max(newL, 1e-4)); 
    }
    return res;
}

vec3 calcAdjustVibranceHDR(vec3 color, float vibrance)
{
    float maxC = max(color.r, max(color.g, color.b));
    float minC = min(color.r, min(color.g, color.b));
    float sat = (maxC - minC) / max(maxC, 1e-4);
    return calcAdjustSaturationHDR(color, 1.0 + vibrance * (1.0 - sat));
}

#endif
