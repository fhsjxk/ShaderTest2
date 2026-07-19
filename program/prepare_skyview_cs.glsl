// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/atmosphere.glsl"

uniform vec3 sunDirection;
uniform sampler2D {{IMG_TRANSMIT_LUT_SAMPLER}};

layout({{IMG_SKYVIEW_FORMAT}}) uniform writeonly image2D {{IMG_SKYVIEW}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
const ivec3 workGroups = ivec3(32, 16, 1); // 256x128

// UE-style sky view LUT: UV → (viewZenithCosAngle, lightViewCosAngle)
// U: view-sun angle (nonlinear, more resolution near sun)
// V: view zenith angle (nonlinear, split at horizon)
void uvToSkyViewLutParams(float viewHeight, vec2 uv,
                          out float viewZenithCosAngle,
                          out float lightViewCosAngle)
{
    float r = PLANET_RADIUS + viewHeight;
    float Vhorizon = sqrt(max(0.0, r * r - PLANET_RADIUS * PLANET_RADIUS));
    float CosBeta = Vhorizon / r;
    float Beta = acos(clamp(CosBeta, -1.0, 1.0));
    float ZenithHorizonAngle = PI - Beta;

    // V → view zenith angle (split at horizon: uv.y=0.5)
    if (uv.y < 0.5)
    {
        float coord = 1.0 - 2.0 * uv.y;
        coord *= coord;
        coord = 1.0 - coord;
        viewZenithCosAngle = cos(ZenithHorizonAngle * coord);
    }
    else
    {
        float coord = uv.y * 2.0 - 1.0;
        coord *= coord;
        viewZenithCosAngle = cos(ZenithHorizonAngle + Beta * coord);
    }

    // U → view-sun angle (sqrt for more resolution near sun)
    float coord = uv.x;
    coord *= coord;
    lightViewCosAngle = -(coord * 2.0 - 1.0);
}

void main()
{
    ivec2 pix = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = ivec2(256, 128);
    if (any(greaterThanEqual(pix, size))) return;

    vec2 uv = 1.0 - (vec2(pix) + 0.5) / vec2(size);

    float viewHeight = 0.0; // ground level
    float viewZenithCosAngle;
    float lightViewCosAngle;
    uvToSkyViewLutParams(viewHeight, uv, viewZenithCosAngle, lightViewCosAngle);

    // Reconstruct view ray direction from (zenith, sun-relative) angles
    float thetaV = acos(clamp(viewZenithCosAngle, -1.0, 1.0));
    float sunZenithCos = clamp(sunDirection.y, -1.0, 1.0);
    float thetaS = acos(sunZenithCos);

    // cos(angle(view, sun)) = sinθv·sinθs·cos(Δφ) + cosθv·cosθs = lightViewCosAngle
    float sinV = sin(thetaV);
    float sinS = sin(thetaS);
    float cosDPhi = (lightViewCosAngle - viewZenithCosAngle * sunZenithCos)
                  / max(sinV * sinS, 1e-6);
    cosDPhi = clamp(cosDPhi, -1.0, 1.0);
    float dPhi = acos(cosDPhi);

    // Sun in XZ plane at angle θS; view at θV with azimuth dPhi
    vec3 rayDir = vec3(sinV * cos(dPhi), sinV * sin(dPhi), viewZenithCosAngle);

    vec34 inscatter = computeInscattering({{IMG_TRANSMIT_LUT_SAMPLER}}, sunDirection, rayDir, viewHeight);

    #ifdef ENABLE_SPECTRAL
    vec3 color = rgbFromSpectral(inscatter);
    #else
    vec3 color = inscatter.rgb;
    #endif
    imageStore({{IMG_SKYVIEW}}, pix, vec4(color, 1.0));
}
#endif
