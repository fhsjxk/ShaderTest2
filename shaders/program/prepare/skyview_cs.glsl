// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/atmosphere.glsl"

uniform vec3 sunDirection;
uniform sampler2D {{IMG_TRANSMIT_LUT_SAMPLER}};

// Lat-long sky-view LUT: 360° azimuth × (ground band + sky) elevation.
layout({{IMG_SKYVIEW_FORMAT}}) uniform writeonly image2D {{IMG_SKYVIEW}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
const ivec3 workGroups = ivec3({{IMG_SKYVIEW_SIZE_X}} / 8, {{IMG_SKYVIEW_SIZE_Y}} / 8, 1);
const ivec2 SKYVIEW_SIZE = ivec2({{IMG_SKYVIEW_SIZE_X}}, {{IMG_SKYVIEW_SIZE_Y}});

void main()
{
    ivec2 pixelCoordinate = ivec2(gl_GlobalInvocationID.xy);
    if (any(greaterThanEqual(pixelCoordinate, SKYVIEW_SIZE)))
    {
        return;
    }

    vec2 uv = (vec2(pixelCoordinate) + 0.5) / vec2(SKYVIEW_SIZE);

    // V axis: [0, SKYVIEW_GROUND_FRACTION) is the below-horizon band (nadir at
    // 0), the remainder is the sky (zenith at 1). Must match sampleSkyViewLUT.
    float theta;
    if (uv.y < SKYVIEW_GROUND_FRACTION)
    {
        theta = PI - (uv.y / SKYVIEW_GROUND_FRACTION) * PI * 0.5;
    }
    else
    {
        theta = PI * 0.5 * (1.0 - (uv.y - SKYVIEW_GROUND_FRACTION) / (1.0 - SKYVIEW_GROUND_FRACTION));
    }

    float phi   = uv.x * 2.0 * PI;
    vec3 rayDir = vec3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi));

    vec34 inscatter = computeInscattering({{IMG_TRANSMIT_LUT_SAMPLER}}, sunDirection, rayDir, MIN_ALTITUDE_KM);

    #ifdef ENABLE_SPECTRAL
    vec3 color = rgbFromSpectral(inscatter);
    #else
    vec3 color = inscatter.rgb;
    #endif

    vec34 trans = transmittanceFromLUT({{IMG_TRANSMIT_LUT_SAMPLER}}, PLANET_RADIUS + MIN_ALTITUDE_KM, clamp(rayDir.y, -1.0, 1.0));
    #ifdef ENABLE_SPECTRAL
    trans.rgb = rgbFromSpectral(trans) * 0.2;
    #endif

    color += sunDiscMask(dot(rayDir, normalize(sunDirection))) * SUN_DISC_RADIANCE * trans.rgb;

    imageStore({{IMG_SKYVIEW}}, pixelCoordinate, vec4(color, 1.0));
}
#endif
