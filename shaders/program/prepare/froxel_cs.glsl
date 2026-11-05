// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/atmosphere/all.glsl"

uniform sampler2D {{IMG_TRANSMIT_LUT_SAMPLER}};
uniform vec3 sunDirection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform float viewWidth;
uniform float viewHeight;

// Not `writeonly`: imageSize() has to be callable on it, and a write-only image
// is only allowed as an argument to imageStore/imageAtomic*. The slices are stacked
// vertically (slice k owns rows [k*H/N, (k+1)*H/N)) and the three stored quantities
// are laid out side by side, one third of the width each.
layout({{IMG_FROXEL_FORMAT}}) uniform image2D {{IMG_FROXEL}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
const vec2 workGroupsRender = vec2({{FROXEL_WORKGROUPS}}, {{FROXEL_WORKGROUPS}});

// Copy `value` into one data texel of a tile and, when this invocation sits on the
// data border, into the padding texels that mirror it. Padding copies the nearest
// data texel, which is what a clamp-to-edge lookup would return, and every padding
// texel has exactly one writer, so the copies need neither a barrier nor a second
// pass.
void storeTile(ivec2 groupOrigin, ivec2 innerSize, ivec2 local, vec4 value)
{
    ivec2 c = ivec2(FROXEL_PADDING) + local;
    imageStore({{IMG_FROXEL}}, groupOrigin + c, value);

    bool atLeft   = local.x == 0;
    bool atRight  = local.x == innerSize.x - 1;
    bool atBottom = local.y == 0;
    bool atTop    = local.y == innerSize.y - 1;

    if (!atLeft && !atRight && !atBottom && !atTop)
    {
        return;
    }

    int xL = FROXEL_PADDING - 1;
    int xR = FROXEL_PADDING + innerSize.x;
    int yB = FROXEL_PADDING - 1;
    int yT = FROXEL_PADDING + innerSize.y;

    if (atLeft)   { imageStore({{IMG_FROXEL}}, groupOrigin + ivec2(xL, c.y), value); }
    if (atRight)  { imageStore({{IMG_FROXEL}}, groupOrigin + ivec2(xR, c.y), value); }
    if (atBottom) { imageStore({{IMG_FROXEL}}, groupOrigin + ivec2(c.x, yB), value); }
    if (atTop)    { imageStore({{IMG_FROXEL}}, groupOrigin + ivec2(c.x, yT), value); }

    if (atLeft && atBottom)  { imageStore({{IMG_FROXEL}}, groupOrigin + ivec2(xL, yB), value); }
    if (atRight && atBottom) { imageStore({{IMG_FROXEL}}, groupOrigin + ivec2(xR, yB), value); }
    if (atLeft && atTop)     { imageStore({{IMG_FROXEL}}, groupOrigin + ivec2(xL, yT), value); }
    if (atRight && atTop)    { imageStore({{IMG_FROXEL}}, groupOrigin + ivec2(xR, yT), value); }
}

// One invocation owns a whole screen-space column. Every slice is integrated from
// the camera out to its own depth with its own step count, exactly like the
// reference implementation: a far slice spans far more depth, so it gets more
// samples instead of sharing a fixed budget with the near ones.
void main()
{
    ivec2 atlasSize = imageSize({{IMG_FROXEL}});
    ivec2 tileSize  = ivec2(atlasSize.x / 3, atlasSize.y / FROXEL_SLICES);
    ivec2 innerSize = tileSize - 2 * FROXEL_PADDING;
    ivec2 cell = ivec2(gl_GlobalInvocationID.xy);
    if (innerSize.x <= 0 || innerSize.y <= 0
        || any(greaterThanEqual(cell, innerSize)))
    {
        return;
    }

    vec2 uv = (vec2(cell) + 0.5) / vec2(innerSize);

    // View ray through the column centre, reconstructed the same way as sky_cs.
    vec3 clipPos = vec3(uv * 2.0 - 1.0, 1.0);
    vec3 viewPos = (gbufferProjectionInverse * vec4(clipPos, 1.0)).xyz;
    vec3 rayDir = normalize(mat3(gbufferModelViewInverse) * viewPos);

    // Same frame as computeInscattering(): a real origin in atmosphere space, so
    // every sample is a real position and the ray is curved like the real one.
    vec3 rayOrigin = vec3(0.0, cameraRadiusKm(), 0.0);
    vec3 sunDirN = normalize(sunDirection);

    // Where the march stops: the end of the medium along this ray, expressed in the
    // stretched space the slices live in. Nothing caps the distance any earlier, so
    // the whole stack gets integrated.
    float mediumEnd = mediumEndKm(rayDir) / max(FOG_DISTANCE_SCALE, 0.01);

    // Phase is a per-ray constant, exactly as computeInscattering() treats it.
    float cosTheta = dot(rayDir, sunDirN);
    float rayleighPhaseVal = rayleighPhase(-cosTheta);
    float aerosolPhaseVal  = aerosolPhase(-cosTheta);

    vec3 single = vec3(0.0);
    vec3 multi  = vec3(0.0);
    vec34 transmittance = vec34(1.0);

    float prevKm = 0.0;
    bool done = false;

    for (int k = 0; k < FROXEL_SLICES; ++k)
    {
        // The slice's own depth is where it stops.
        float sliceKm = froxelSliceDepthKm(k);

        // Once a slice starts at or beyond the end of the medium, it and everything
        // after it are not integrated: they keep the value of the last slice that
        // was, so sampling beyond the medium reads a saturated value instead of
        // stale memory.
        if (!done && prevKm >= mediumEnd)
        {
            done = true;
        }

        if (!done)
        {
            float limitKm = min(sliceKm, mediumEnd);
            int steps = froxelSliceSteps(k);
            float stepKm = limitKm / float(steps);

            single = vec3(0.0);
            multi  = vec3(0.0);
            transmittance = vec34(1.0);

            for (int s = 0; s < steps; ++s)
            {
                integrateAerialStep({{IMG_TRANSMIT_LUT_SAMPLER}}, sunDirN, rayOrigin, rayDir,
                                    (float(s) + 0.5) * stepKm, stepKm,
                                    rayleighPhaseVal, aerosolPhaseVal,
                                    single, multi, transmittance);
            }
        }

        int row = k * tileSize.y;
        storeTile(ivec2(0, row), innerSize, cell, vec4(single, 1.0));
        storeTile(ivec2(tileSize.x, row), innerSize, cell, vec4(multi, 1.0));
        storeTile(ivec2(2 * tileSize.x, row), innerSize, cell,
                  vec4(vec3(transmittance), 1.0));

        prevKm = sliceKm;
    }
}
#endif
