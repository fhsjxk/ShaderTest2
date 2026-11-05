// Aerial perspective in a frustum-aligned voxel stack ("froxel")
//
// Screen space is 1/20 of the frame, the stack is 16 slices, and the depth
// distribution is squared: slice k is integrated out to
//
//     t_k = 128 * ((k + 0.5) / 16)^2 km
//
// which is the same layout the reference implementation uses (AP_SLICE_COUNT 32,
// AP_KM_PER_SLICE). Each texel holds the cumulative result from the camera out to
// its own slice depth, so the lighting pass reads two texels per quantity.
//
// Three quantities are stored side by side, one third of the atlas width each:
//
//   1  in-scattered radiance, single scattering only (phase baked in)
//   2  in-scattered radiance, multiple scattering only
//   3  RGB transmittance
//
// They are kept apart so the composer can weight them independently; splitting
// them costs no extra marching, only two more accumulators.

#ifndef ATMOSPHERE_AERIAL
#define ATMOSPHERE_AERIAL

#include "/lib/prelude.glsl"
#include "/lib/atmosphere/constants.glsl"
#include "/lib/atmosphere/geometry.glsl"
#include "/lib/atmosphere/phase.glsl"
#include "/lib/atmosphere/medium.glsl"
#include "/lib/atmosphere/transmittance.glsl"
#include "/lib/atmosphere/scattering.glsl"

// Slice count, padding and the atlas' three channel groups, injected by the build
// so the layout, the build pass and the sampling pass cannot drift apart.
#define FROXEL_SLICES {{FROXEL_SLICES}}
#define FROXEL_PADDING {{FROXEL_PADDING_PX}}

// Depth span of the stack: 16 slices at 8 km each, the same 128 km the reference
// uses. It is a fixed number, not a function of the render distance, because the
// pass that builds the stack draws no geometry and cannot read `far`.
const float FROXEL_SPAN_KM = 128.0;

// Steps used for slice k: (k + 1) * 2, i.e. 2, 4, ... 32. A far slice spans far
// more depth than a near one, so its integration gets proportionally more samples.
int froxelSliceSteps(int k)
{
    return max(1, (k + 1) * 2);
}

// Depth of slice k's own far boundary, in km, from the squared distribution.
float froxelSliceDepthKm(int k)
{
    float t = (float(k) + 0.5) / float(FROXEL_SLICES);
    return FROXEL_SPAN_KM * t * t;
}

// Continuous slice index for a view depth in blocks, clamped to [0, N-1]. Inverts
// the squared distribution; texel k sits at index k, so no extra shift is needed.
float froxelSliceIndex(float zBlocks)
{
    float u = sqrt(max(zBlocks * KM_PER_BLOCK, 0.0) / FROXEL_SPAN_KM) * float(FROXEL_SLICES);
    return clamp(u - 0.5, 0.0, float(FROXEL_SLICES - 1));
}

// Tile geometry. The atlas is three channel groups across and FROXEL_SLICES slices
// down, with FROXEL_PADDING texels of copied border around every tile; the data
// area inside that border is what uv maps onto.
vec2 froxelTileSize(vec2 atlasTexels)
{
    return vec2(floor(atlasTexels.x / 3.0), floor(atlasTexels.y / float(FROXEL_SLICES)));
}

vec2 froxelInnerSize(vec2 atlasTexels)
{
    return froxelTileSize(atlasTexels) - 2.0 * float(FROXEL_PADDING);
}

// One slice of the atlas. Slice k owns rows [k*H/N, (k+1)*H/N); `group` selects
// which third of the atlas width is read (single, multiple, transmittance).
//
// Both screen axes stay in play: the integer part of the vertical coordinate picks
// the slice, the fractional part carries the pixel's own y. Using a constant there
// instead makes every pixel read the same row and the result stops varying
// vertically. The clamps keep the bilinear footprint over the data area, so the
// only texels it can reach outside a slice's own data are that slice's own copy of
// its edge -- never the neighbouring tile.
vec4 sampleFroxelSlice(sampler2D froxelAtlas, vec2 uv, float slice, vec2 atlasTexels, int group)
{
    vec2 tile  = froxelTileSize(atlasTexels);
    vec2 inner = froxelInnerSize(atlasTexels);

    float uLocal = clamp(uv.x, 0.5 / inner.x, 1.0 - 0.5 / inner.x);
    float vLocal = clamp(uv.y, 0.5 / inner.y, 1.0 - 0.5 / inner.y);

    float u = (float(group) * tile.x + float(FROXEL_PADDING) + uLocal * inner.x)
              / atlasTexels.x;
    float v = (slice * tile.y + float(FROXEL_PADDING) + vLocal * inner.y)
              / atlasTexels.y;

    return texture(froxelAtlas, vec2(u, v));
}

// Composite one depth: attenuate the shaded radiance and add both scattering terms.
// `zBlocks` is the geometric view distance;  stretches the fog's
// distance axis, so the slice lookup lives in the stretched space.
vec3 applyAerialPerspective(sampler2D froxelAtlas, vec3 radiance, vec2 uv, float zBlocks)
{
    vec2 atlasTexels = vec2(textureSize(froxelAtlas, 0));

    float stretchedBlocks = max(zBlocks, 0.0) * FOG_DISTANCE_SCALE;

    float s = froxelSliceIndex(stretchedBlocks);
    float slice0 = floor(s);
    float slice1 = min(slice0 + 1.0, float(FROXEL_SLICES - 1));
    float f = s - slice0;

    vec4 single = mix(sampleFroxelSlice(froxelAtlas, uv, slice0, atlasTexels, 0),
                      sampleFroxelSlice(froxelAtlas, uv, slice1, atlasTexels, 0), f);
    vec4 multi  = mix(sampleFroxelSlice(froxelAtlas, uv, slice0, atlasTexels, 1),
                      sampleFroxelSlice(froxelAtlas, uv, slice1, atlasTexels, 1), f);
    vec4 trans  = mix(sampleFroxelSlice(froxelAtlas, uv, slice0, atlasTexels, 2),
                      sampleFroxelSlice(froxelAtlas, uv, slice1, atlasTexels, 2), f);

    // Near field. Slice 0 is integrated out to froxelSliceDepthKm(0) -- 0.12 km --
    // and froxelSliceIndex() clamps every shorter distance to it, so without this a
    // pixel at arm's length would receive the fog of the whole first slice, six
    // metres' worth instead of its own. Fade linearly to nothing at the camera
    // instead: at 0.12 km the layer's optical depth is ~5e-3, where differing from
    // the exact T^w only shows up in the third digit, and the fade meets the
    // unmodified value at w = 1 with no visible seam.
    float zKm = stretchedBlocks * KM_PER_BLOCK;
    float nearKm = froxelSliceDepthKm(0);
    if (zKm < nearKm)
    {
        float w = clamp(zKm / nearKm, 0.0, 1.0);
        trans.rgb = mix(vec3(1.0), trans.rgb, w);
        single.rgb *= w;
        multi.rgb  *= w;
    }

    return radiance * trans.rgb + single.rgb + multi.rgb;
}

// Ground sphere for the medium-end test, sunk below sea level (see mediumEndKm).
//const float FROXEL_GROUND_RADIUS_KM = PLANET_RADIUS_KM - 5.0 * FOG_DISTANCE_SCALE;

// How far the medium reaches along one ray, in km: the top of the atmosphere, or
// the ground where the ray meets it first. The ground sphere is sunk below sea
// level so a ray that grazes the horizon keeps integrating instead of being stopped
// by the sea -- the fog is air, and the consumer stops sampling at the real surface.
float mediumEndKm(vec3 rayDirection)
{
    vec3 rayOrigin = vec3(0.0, cameraRadiusKm(), 0.0);

    float atmosphereDist = raySphereIntersect(rayOrigin, rayDirection, ATMOSPHERE_RADIUS_KM);
    //float groundDist = raySphereIntersect(rayOrigin, rayDirection, FROXEL_GROUND_RADIUS_KM);

    //float endKm = (groundDist > 0.0) ? groundDist : atmosphereDist;
    //return (endKm > 0.0) ? endKm : ATMOSPHERE_THICKNESS_KM;
    return (atmosphereDist > 0.0) ? atmosphereDist : ATMOSPHERE_THICKNESS_KM;
}

// One sample of the same model computeInscattering() uses, copied verbatim from its
// loop body and adapted to aerial perspective. Keep the two in step: if the sky's
// sample changes, this must change with it.
//
// The adaptations are:
//   1. the sample position and the step length come from the caller;
//   2. single and multiple scattering accumulate separately, so the composer can
//      weight them independently;
//   3. the result accumulates instead of being returned as one radiance.
//
// `distanceKm` is the step centre, `thicknessKm` the geometric length it spans.
// Rayleigh and aerosol phase are per-ray constants, hoisted by the caller exactly
// as computeInscattering() hoists them.
void integrateAerialStep(
    sampler2D transmitLUT,
    vec3 sunDirection,
    vec3 rayOrigin,
    vec3 rayDirection,
    float distanceKm,
    float thicknessKm,
    float rayleighPhaseVal,
    float aerosolPhaseVal,
    inout vec3 singleScatter,
    inout vec3 multipleScatter,
    inout vec34 transmittance)
{
    float ds = thicknessKm;
    if (ds <= 0.0)
    {
        return;
    }

    vec3 p = rayOrigin + rayDirection * distanceKm;

    float r = length(p);
    float h = r - PLANET_RADIUS_KM;
    float normalizedH = h / ATMOSPHERE_THICKNESS_KM;

    float sunCosTheta = dot(p / r, sunDirection);

    vec34 aerosolAbsorption, aerosolScattering, molecularAbsorption, molecularScattering, ext;
    getAtmosphereCoefficients(h, aerosolAbsorption, aerosolScattering,
                              molecularAbsorption, molecularScattering, ext);

    vec34 transToSun = transmittanceFromLUT(transmitLUT, r, sunCosTheta);

    vec34 singleSource = (molecularScattering * rayleighPhaseVal
                        + aerosolScattering * aerosolPhaseVal) * transToSun;

    #ifdef PHYSICAL_PARAM
    // Rayleigh only, matching computeInscattering(): the aerosol's higher orders
    // come from the fitted gain below, not from the transfer LUT.
    vec34 multiSource = multiScattering(transmitLUT, sunCosTheta, normalizedH, r)
                      * molecularScattering;
    #else
    vec34 multiSource = multiScattering(transmitLUT, sunCosTheta, normalizedH, r)
                      * (molecularScattering + aerosolScattering);
    #endif

    singleSource *= SUN_IRRADIANCE;
    multiSource  *= SUN_IRRADIANCE;

    #ifdef PHYSICAL_PARAM
    // The gain converts the single-scattering integral into "single plus every
    // higher order the aerosol adds", so it belongs on the single term only.
    singleSource *= aerosolScatteringGain();
    #endif

    // Analytic integration of a constant source over the step.
    vec34 stepT = exp(-ext * ds);
    vec34 division = max(ext, vec34(EPS));
    vec34 singleIntegrated = (singleSource - singleSource * stepT) / division;
    vec34 multiIntegrated  = (multiSource  - multiSource  * stepT) / division;

    vec34 singleContribution = transmittance * singleIntegrated;
    vec34 multiContribution  = transmittance * multiIntegrated;
#ifdef ENABLE_SPECTRAL
    singleScatter   += rgbFromSpectral(singleContribution);
    multipleScatter += rgbFromSpectral(multiContribution);
#else
    singleScatter   += singleContribution;
    multipleScatter += multiContribution;
#endif
    transmittance *= stepT;
}

#endif
