#ifndef MATH
#define MATH

const float PI = 3.14159265358979323846;
const float INV_PI = 0.31830988618379067154;
const float INV_4PI = 0.07957747154594766788;

float saturate(float x)
{
    return clamp(x, 0.0, 1.0);
}

vec3 saturate(vec3 x)
{
    return clamp(x, vec3(0.0), vec3(1.0));
}

float getBrightness(vec3 color)
{
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

#endif
