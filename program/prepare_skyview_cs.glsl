// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/atmosphere.glsl"

uniform vec3 sunDirection;
uniform sampler2D {{IMG_TRANSMIT_LUT_SAMPLER}};

layout({{IMG_SKYVIEW_FORMAT}}) uniform writeonly image2D {{IMG_SKYVIEW}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
const ivec3 workGroups = ivec3(32, 16, 1); // 256x128

void main()
{
    ivec2 pix = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = ivec2(256, 128);
    if (any(greaterThanEqual(pix, size))) return;

    vec2 uv = (vec2(pix) + 0.5) / vec2(size);

    // Ground at bottom (uv.y < 0.125), horizon at 0.125, sky above
    float groundFraction = 0.125;
    float theta;
    if (uv.y < groundFraction)
    {
        theta = PI - (uv.y / groundFraction) * PI * 0.5;   // nadir → horizon
    }
    else
    {
        theta = PI * 0.5 * (1.0 - (uv.y - groundFraction) / (1.0 - groundFraction)); // horizon → zenith
    }
    float phi   = uv.x * 2.0 * PI;
    vec3 rayDir = vec3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi));

    float viewHeight = 0.0;
    vec34 inscatter = computeInscattering({{IMG_TRANSMIT_LUT_SAMPLER}}, sunDirection, rayDir, viewHeight);

    #ifdef ENABLE_SPECTRAL
    vec3 color = rgbFromSpectral(inscatter);
    #else
    vec3 color = inscatter.rgb;
    #endif
    imageStore({{IMG_SKYVIEW}}, pix, vec4(color, 1.0));
}
#endif
