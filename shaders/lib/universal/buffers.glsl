#ifndef UNIVERSAL_BUFFERS
#define UNIVERSAL_BUFFERS

// Shader storage blocks shared across passes. Declare them here only, so every
// pass agrees on the binding index and the field layout.

#include "/lib/prelude.glsl"

// Auto exposure state: written by setup1 (seed) and composite2 (adaptation),
// read by the final pass when applying the exposure.
layout(std430, binding = 0) buffer ExposureBlock
{
    float exposure;
} exposureBlock;

// Frame constants: everything identical for every invocation of a frame, computed
// once by prepare4 instead of once per pixel. See docs/FRAME_CONSTANTS.md for the
// admission test and the list of what does -- and does not -- belong here.
layout(std430, binding = 1) buffer FrameBlock
{
    vec4 sunIrradiance;      // RGB, extraterrestrial irradiance after the atmosphere
    vec4 sunTransmittance;   // RGB, eye -> sun, in the same colour units
    vec4 sunDirection;       // xyz normalized, w unused
} frameBlock;

#endif
