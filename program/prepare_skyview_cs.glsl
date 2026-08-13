// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/atmosphere.glsl"

uniform vec3 sunDirection;
uniform sampler2D {{IMG_TRANSMIT_LUT_SAMPLER}};

//#define ERP

layout({{IMG_SKYVIEW_FORMAT}}) uniform writeonly image2D {{IMG_SKYVIEW}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
#ifndef ERP
const ivec3 workGroups = ivec3(64, 32, 1); // 256x128
#else
const ivec3 workGroups = ivec3(512, 256, 1);
#endif

void main()
{
    ivec2 pix = ivec2(gl_GlobalInvocationID.xy);
    #ifndef ERP
    ivec2 size = ivec2(512, 256);
    #else
    ivec2 size = ivec2(4096, 2048);
    #endif
    if (any(greaterThanEqual(pix, size))) return;

    vec2 uv = (vec2(pix) + 0.5) / vec2(size);

    // Ground at bottom (uv.y < 0.125), horizon at 0.125, sky above
    float groundFraction = 0.125;
    float theta;
    #ifndef ERP
    if (uv.y < groundFraction)
    {
        theta = PI - (uv.y / groundFraction) * PI * 0.5;   // nadir → horizon
    }
    else
    {
        theta = PI * 0.5 * (1.0 - (uv.y - groundFraction) / (1.0 - groundFraction)); // horizon → zenith
    }
    #else
    theta = PI - uv.y * PI;
    #endif

    float phi   = uv.x * 2.0 * PI;
    vec3 rayDir = vec3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi));

    float viewHeight = 0.001;
    vec34 inscatter = computeInscattering({{IMG_TRANSMIT_LUT_SAMPLER}}, sunDirection, rayDir, viewHeight);

    #ifdef ENABLE_SPECTRAL
    vec3 color = rgbFromSpectral(inscatter);
    #else
    vec3 color = inscatter.rgb;
    #endif

    vec34 trans = transmittanceFromLUT({{IMG_TRANSMIT_LUT_SAMPLER}}, PLANET_RADIUS + viewHeight, clamp(rayDir.y, -1.0, 1.0));
    #ifdef ENABLE_SPECTRAL
    trans.rgb = rgbFromSpectral(trans) * 0.2;
    #endif

    float sunCosAngle = dot(rayDir, normalize(sunDirection));
    float sunIntensity = (smoothstep(0.999983, 1.00005, sunCosAngle) * 0.98 + 0.02) * (step(0.9999893, sunCosAngle));
    //float glow = pow(max(sunCosAngle - 0.9999, 0.0), 2.0) * 5.0;
    color += (sunIntensity * 1000.0) * trans.rgb;

    imageStore({{IMG_SKYVIEW}}, pix, vec4(color, 1.0));
}
#endif
