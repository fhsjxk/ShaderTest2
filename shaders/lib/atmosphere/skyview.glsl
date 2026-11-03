// Sky-view LUT layout and sampling
//
// Atmosphere model split by responsibility. Dependencies are one-way:
//   constants -> {geometry, phase, medium} -> transmittance -> scattering
// `scene` and `skyview` only depend on constants.
//
// Units: distances km, coefficients 1/km, radiance scene-linear unitless.
// See constants.glsl for the provenance of every physical number.

#ifndef ATMOSPHERE_SKYVIEW
#define ATMOSPHERE_SKYVIEW

#include "/lib/prelude.glsl"
#include "/lib/atmosphere/constants.glsl"

// Sky-view LUT layout: the lowest SKYVIEW_GROUND_FRACTION of the V axis holds
// the below-horizon half, the rest is the sky.
const float SKYVIEW_GROUND_FRACTION = 0.125;

// ═══ Sky-view LUT sampling (lat-long) ═══════════════════════

vec3 sampleSkyViewLUT(sampler2D skyViewLUT, vec3 viewDir, float viewHeight)
{
    // Horizon sits at SKYVIEW_GROUND_FRACTION; below it the V axis is remapped
    // linearly onto the ground half of the LUT.
    float r  = PLANET_RADIUS + viewHeight;
    float Vh = sqrt(max(0.0, r * r - PLANET_RADIUS * PLANET_RADIUS));
    float thetaHorizon = acos(clamp(Vh / r, 0.0, 1.0));

    float phi   = atan(viewDir.z, viewDir.x) + PI;
    float theta = acos(clamp(viewDir.y, -1.0, 1.0));

    float v;
    if (theta > thetaHorizon)
    {
        v = SKYVIEW_GROUND_FRACTION * (1.0 - (theta - thetaHorizon) / max(PI - thetaHorizon, 1e-6));
    }
    else
    {
        v = SKYVIEW_GROUND_FRACTION + (1.0 - theta / max(thetaHorizon, 1e-6)) * (1.0 - SKYVIEW_GROUND_FRACTION);
    }
    vec2 uv = vec2(phi / (2.0 * PI), clamp(v, 0.0, 1.0));
    return texture(skyViewLUT, uv).rgb;
}

#endif
