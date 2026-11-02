#ifndef PRELUDE
#define PRELUDE

// Single entry point for every shader stage. Include this first (and only this)
// to get configuration, math constants and the render-target format block.
//   settings.glsl   Iris built-in constants
//   options.glsl    user-facing switches and tunables
//   math.glsl       PI / INV_PI / INV_4PI / saturate
//   rt_formats.glsl generated colortex format declarations
#include "/settings.glsl"
#include "/options.glsl"
#include "/lib/math.glsl"
#include "/lib/rt_formats.glsl"

// Alpha cutout threshold used by both the gbuffer and the shadow pass.
const float ALPHA_TEST_THRESHOLD = 0.52;

#endif
