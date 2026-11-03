#ifndef COLOR
#define COLOR

// Rec.709 luma.
float getBrightness(vec3 color)
{
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

// Cheap saturation change around the channel average (not luma preserving).
vec3 adjustSaturationFast(vec3 color, float s)
{
    float luma = (color.r + color.g + color.b) * 0.3333;
    return mix(vec3(luma), color, s);
}

#endif
