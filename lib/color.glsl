#ifndef COLOR
#define COLOR

vec3 adjustSaturationFast(vec3 color, float s)
{
    float luma = (color.r + color.g + color.b) * 0.3333;
    return mix(vec3(luma), color, s);
}

#endif
