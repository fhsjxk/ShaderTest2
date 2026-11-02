#ifndef SETTINGS
#define SETTINGS

// Iris built-in constants. Values that must agree with the pack layout live in
// build.py instead (see RT_LIST / IMG_LIST).

const float sunPathRotation = -30.0;

const int shadowMapResolution = 2048;

const vec4 {{RT_BACK}}ClearColor = vec4(0.0, 0.0, 0.0, 1.0);

const float shadowDistanceRenderMul = 1.0;

#endif
