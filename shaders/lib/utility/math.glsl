#ifndef MATH
#define MATH

const float PI = 3.14159265358979323846;
const float INV_PI = 0.31830988618379067154;
const float INV_4PI = 0.07957747154594766788;

// Smallest magnitude treated as non-zero. Use it to keep a division, a log or a
// normalisation defined; never as a physical threshold, and never where the
// quantity has units that are large enough for this to be below float range
// (at planet radius, float32 spacing is ~5e-4 km, so a km-valued offset needs
// more than this).
const float EPS = 1e-6;

float saturate(float x)
{
    return clamp(x, 0.0, 1.0);
}

vec3 saturate(vec3 x)
{
    return clamp(x, vec3(0.0), vec3(1.0));
}

#endif
