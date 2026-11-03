// Sky-view LUT sampling
//
// Depends on constants and scene (for SKYVIEW_GROUND_FRACTION). The LUT stores
// radiance in colour units, so the sampled value needs no conversion.

#ifndef ATMOSPHERE_SKYVIEW
#define ATMOSPHERE_SKYVIEW

#include "/lib/prelude.glsl"
#include "/lib/atmosphere/constants.glsl"
#include "/lib/atmosphere/scene.glsl"

vec3 sampleSkyViewLUT(sampler2D skyViewLUT, vec3 viewDir, float viewHeight)
{
    // Horizon sits at SKYVIEW_GROUND_FRACTION; above it the V axis is remapped
    // linearly onto the sky half of the LUT, below it onto the ground half.
    float r  = PLANET_RADIUS_KM + viewHeight;
    float Vh = sqrt(max(0.0, r * r - PLANET_RADIUS_KM * PLANET_RADIUS_KM));
    float thetaHorizon = acos(clamp(Vh / r, 0.0, 1.0));

    float phi   = atan(viewDir.z, viewDir.x) + PI;
    float theta = acos(clamp(viewDir.y, -1.0, 1.0));

    float v;
    if (theta > thetaHorizon)
    {
        v = SKYVIEW_GROUND_FRACTION * (1.0 - (theta - thetaHorizon) / max(PI - thetaHorizon, EPS));
    }
    else
    {
        v = SKYVIEW_GROUND_FRACTION + (1.0 - theta / max(thetaHorizon, EPS)) * (1.0 - SKYVIEW_GROUND_FRACTION);
    }
    vec2 uv = vec2(phi / (2.0 * PI), clamp(v, 0.0, 1.0));
    return texture(skyViewLUT, uv).rgb;
}

#endif
