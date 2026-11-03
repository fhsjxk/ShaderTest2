// Radiometric units
//
// One colour unit is a luminance of NITS_PER_UNIT cd/m². The scale is anchored
// to a scene rather than to a display: for a clear morning, looking level across
// a grassy plain with some trees and hills, almost every pixel comes out below
// 1.0. That frame therefore already looks reasonable without auto exposure or
// tone mapping, and only its brightest highlights clip.
//
// So 1.0 is "about the brightest ordinary sunlit surface", roughly 2*10^4 cd/m².
// That is far above SDR white on purpose: the sun disc, the sky near the sun and
// specular highlights all exceed it, and the extra range is what the HDR path
// and the auto exposure are there for.
//
// Conversions:
//   radiance      L [cd/m²]  -> L / NITS_PER_UNIT
//   illuminance   E [lux]    -> E / NITS_PER_UNIT
//
// The illuminance case works because a Lambertian surface returns
// L = rho * E / PI: dividing both L and E by the same constant leaves the
// equation intact, so the same divisor converts an irradiance into the units
// the outgoing radiance is expressed in.

#ifndef UTILITY_UNITS
#define UTILITY_UNITS

const float NITS_PER_UNIT = 20000.0;

float nitsToUnits(float nits)  { return nits / NITS_PER_UNIT; }
vec2  nitsToUnits(vec2 nits)   { return nits / NITS_PER_UNIT; }
vec3  nitsToUnits(vec3 nits)   { return nits / NITS_PER_UNIT; }

float unitsToNits(float units) { return units * NITS_PER_UNIT; }
vec2  unitsToNits(vec2 units)  { return units * NITS_PER_UNIT; }
vec3  unitsToNits(vec3 units)  { return units * NITS_PER_UNIT; }

#endif
