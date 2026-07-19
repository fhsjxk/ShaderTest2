// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/atmosphere.glsl"

uniform sampler2D depthtex0;
uniform sampler2D {{IMG_TRANSMIT_LUT_SAMPLER}};
uniform vec3 sunDirection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform float eyeAltitude;
uniform float viewWidth;
uniform float viewHeight;

layout({{IMG_SKY_FORMAT}}) uniform writeonly image2D {{IMG_SKY}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
const vec2 workGroupsRender = vec2(0.125, 0.125);

bool tileHasSky(ivec2 tileMin, ivec2 tileMax)
{
    for (int y = tileMin.y; y <= tileMax.y; y++)
    {
        for (int x = tileMin.x; x <= tileMax.x; x++)
        {
            float depth = texelFetch(depthtex0, ivec2(x, y), 0).r;
            if (depth >= 1.0)
            {
                return true;
            }
        }
    }

    return false;
}

void main()
{
    ivec2 fullRes = ivec2(viewWidth, viewHeight);
    ivec2 skyRes = max(ivec2(1), (fullRes + ivec2(7)) / 8);
    ivec2 pixelCoord = ivec2(gl_GlobalInvocationID.xy);
    if (any(greaterThanEqual(pixelCoord, skyRes)))
    {
        return;
    }

    ivec2 tileMin = pixelCoord * 8;
    ivec2 tileMax = min(tileMin + ivec2(7), fullRes - ivec2(1));

    if (!tileHasSky(tileMin, tileMax))
    {
        imageStore({{IMG_SKY}}, pixelCoord, vec4(0.0));
        return;
    }

    vec2 uv = (vec2(pixelCoord) + 0.5) / vec2(skyRes);
    vec3 clipPos = vec3(uv * 2.0 - 1.0, 1.0);
    vec3 viewPos = (gbufferProjectionInverse * vec4(clipPos, 1.0)).xyz;
    vec3 viewRay = mat3(gbufferModelViewInverse) * viewPos;

    vec34 sky = computeInscattering({{IMG_TRANSMIT_LUT_SAMPLER}}, sunDirection, normalize(viewRay.xzy), max((eyeAltitude - 64.0) * 0.02, 0.001));
    #if ENABLE_SPECTRAL
    sky.rgb = rgbFromSpectral(sky);
    #endif
    //vec3 sky = rgbFromSpectral(computeInscattering(...));$
    imageStore({{IMG_SKY}}, pixelCoord, vec4(sky.rgb, 1.0));
}
#endif