// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/prelude.glsl"
#include "/lib/universal/buffers.glsl"
#include "/lib/atmosphere/all.glsl"

uniform sampler2D {{IMG_TRANSMIT_LUT_SAMPLER}};
uniform vec3 sunDirection;

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(1, 1, 1);

// One thread, once per frame: fills FrameBlock for everything downstream.
//
// Runs after prepare1 has rebuilt the transmittance LUT and before any consumer,
// because the sun's own transmittance is a LUT lookup and reading the LUT of the
// previous frame would make the first frame after a reload black. Nothing here may
// depend on the invocation -- if a value varies per pixel it does not belong in the
// block (see docs/FRAME_CONSTANTS.md).
void main()
{
    vec3 sunDir = normalize(sunDirection);
    float eyeRadius = cameraRadiusKm();

    vec34 trans = transmittanceFromLUT({{IMG_TRANSMIT_LUT_SAMPLER}}, eyeRadius,
                                       clamp(sunDir.y, -1.0, 1.0));

    // Same two steps sunTransmittanceAt()/sunIrradianceRGB() used to repeat for
    // every pixel: convert the spectral sample, then scale the irradiance by it.
    #ifdef ENABLE_SPECTRAL
    trans.rgb = rgbFromSpectral(trans) * 0.2;
    vec3 irradianceRGB = rgbFromSpectral(SUN_IRRADIANCE * trans);
    #else
    vec3 irradianceRGB = SUN_IRRADIANCE * trans;
    #endif

    frameBlock.sunTransmittance = vec4(trans.rgb, 1.0);
    frameBlock.sunIrradiance    = vec4(irradianceRGB, 1.0);
    frameBlock.sunDirection     = vec4(sunDir, 0.0);
}
#endif
