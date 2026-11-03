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

#endif
