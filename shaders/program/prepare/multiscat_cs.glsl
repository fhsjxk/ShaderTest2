// Building the multiple-scattering transfer LUT disables the multiple-scattering
// term itself (see multiScattering()), so this pass only ever sees first-order
// scattering. The define has to precede every include.
#define MULTISCAT_BUILD 1

// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/prelude.glsl"
#include "/lib/atmosphere/all.glsl"

uniform sampler2D {{IMG_TRANSMIT_LUT_SAMPLER}};
uniform vec3 sunDirection;

layout({{IMG_MULTISCAT_FORMAT}}) uniform writeonly image2D {{IMG_MULTISCAT}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
const ivec2 MULTISCAT_SIZE = ivec2({{IMG_MULTISCAT_SIZE_X}}, {{IMG_MULTISCAT_SIZE_Y}});
// Literal, not an expression: Iris parses ConstDirective with a plain numeric
// parse and silently drops `ivec3(32 / 8, ...)`.
const ivec3 workGroups = {{IMG_MULTISCAT_WORKGROUPS}};

// SEBH20 (Hillaire 2020), the multiple-scattering transfer function Psi_ms.
//
// One invocation owns one LUT texel: x maps to the cosine of the sun's zenith
// angle, y to altitude. For that point we integrate the single-scattered light
// arriving from every direction over the sphere, and with it the fraction of that
// light which scatters again, then sum the whole series of scattering orders
// analytically:
//
//     Psi_ms = L_2ndOrder / (1 - f_ms)                      (paper Eq.10)
//
// The LUT is written as Psi_ms / SUN_IRRADIANCE so it is a pure transfer function;
// the consumer multiplies by the solar irradiance like it does for single
// scattering.
const int MS_SQRT_SAMPLES = 8;   // 8x8 = 64 sphere directions

void main()
{
    ivec2 texel = ivec2(gl_GlobalInvocationID.xy);
    if (any(greaterThanEqual(texel, MULTISCAT_SIZE)))
    {
        return;
    }

    vec2 uv = (vec2(texel) + 0.5) / vec2(MULTISCAT_SIZE);
    float cosSunZenith = uv.x * 2.0 - 1.0;
    float altitude = uv.y * ATMOSPHERE_THICKNESS_KM;

    // Any frame will do: the sphere integration is uniform, so only the angle
    // between the sun and each direction matters.
    vec3 sunDirN = vec3(sqrt(max(0.0, 1.0 - cosSunZenith * cosSunZenith)), cosSunZenith, 0.0);

    vec34 sumRadiance = vec34(0.0);
    vec34 sumTransfer = vec34(0.0);

    const float sqrtSample = float(MS_SQRT_SAMPLES);
    for (int j = 0; j < MS_SQRT_SAMPLES; ++j)
    {
        for (int i = 0; i < MS_SQRT_SAMPLES; ++i)
        {
            // Uniform sphere sampling (the phi = acos(1 - 2b) form is the one
            // that does not bunch up towards the poles).
            float theta = 2.0 * PI * ((float(i) + 0.5) / sqrtSample);
            float phi   = acos(1.0 - 2.0 * ((float(j) + 0.5) / sqrtSample));

            vec3 dir = vec3(cos(theta) * sin(phi), sin(theta) * sin(phi), cos(phi));

            vec34 transfer;
            vec34 radiance = computeInscatteringCore({{IMG_TRANSMIT_LUT_SAMPLER}}, sunDirN,
                                                     dir, altitude, transfer);

            sumRadiance += radiance;
            sumTransfer += transfer;
        }
    }

    // Averaging over the sphere and multiplying by the isotropic phase 1/(4pi) are
    // the same factor, so they cancel to a plain mean.
    float invCount = 1.0 / (sqrtSample * sqrtSample);
    vec34 fms = sumTransfer * invCount;
    vec34 secondOrder = sumRadiance * invCount;

    // The series converges only while f_ms < 1; clamping keeps a pathological
    // coefficient set from producing an infinity that then blooms across the sky.
    vec34 psi = secondOrder / max(vec34(1.0) - fms, vec34(1e-4));

    // Store the transfer, not the radiance: the sun's intensity is applied by the
    // consumer, exactly as it is for single scattering.
    psi = psi / max(SUN_IRRADIANCE, vec34(1e-6));

    imageStore({{IMG_MULTISCAT}}, texel, vec4(psi.rgb, 1.0));
}
#endif
