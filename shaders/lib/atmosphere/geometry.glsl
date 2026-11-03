// Ray/sphere intersections in atmosphere space
//
// Atmosphere model split by responsibility. Dependencies are one-way:
//   constants -> {geometry, phase, medium} -> transmittance -> scattering
// `scene` and `skyview` only depend on constants.
//
// Units: distances km, coefficients 1/km, radiance scene-linear unitless.
// See constants.glsl for the provenance of every physical number.

#ifndef ATMOSPHERE_GEOMETRY
#define ATMOSPHERE_GEOMETRY

#include "/lib/prelude.glsl"
#include "/lib/atmosphere/constants.glsl"

// ═══ Geometry ═══════════════════════════════════════════════

float distanceToTopAtmosphereBoundary(float r, float mu)
{
    float discriminant = r * r * (mu * mu - 1.0) + ATMOSPHERE_RADIUS_KM * ATMOSPHERE_RADIUS_KM;
    return clamp(-r * mu + sqrt(max(0.0, discriminant)), 0.0, 1e6);
}

bool rayIntersectsGround(float r, float mu)
{
    return mu < 0.0 && r * r * (mu * mu - 1.0) + PLANET_RADIUS_KM * PLANET_RADIUS_KM >= 0.0;
}

// Returns the nearest positive intersection distance, or -1.0 when the ray misses.
float raySphereIntersect(vec3 origin, vec3 dir, float radius)
{
    float b = dot(origin, dir);
    float c = dot(origin, origin) - radius * radius;
    float disc = b * b - c;
    if (disc < 0.0) return -1.0;
    float sqrtDisc = sqrt(disc);
    float t0 = -b - sqrtDisc;
    float t1 = -b + sqrtDisc;
    return (t0 >= 0.0) ? t0 : ((t1 >= 0.0) ? t1 : -1.0);
}

#endif
