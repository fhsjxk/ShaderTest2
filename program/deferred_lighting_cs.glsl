// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/prelude.glsl"
#include "/lib/brdf.glsl"
#include "/lib/color.glsl"
#include "/lib/shadow.glsl"
#include "/lib/atmosphere.glsl"

uniform sampler2D depthtex0;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D noisetex;
uniform sampler2D {{RT_BASE_COLOR}};
uniform sampler2D {{RT_NORMAL}};
uniform sampler2D {{RT_LIGHTING0}};
uniform sampler2D {{RT_BACK}};
uniform sampler2D {{IMG_SKY_SAMPLER}};
uniform sampler2D {{IMG_TRANSMIT_LUT_SAMPLER}};

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 sunDirection;
uniform float ambientAmount;
uniform float eyeAltitude;
uniform float viewWidth;
uniform float viewHeight;

layout({{IMG_BACK_FORMAT}}) uniform writeonly image2D {{IMG_BACK}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
const vec2 workGroupsRender = vec2(1.0, 1.0);

// ── Lighting tuning ─────────────────────────────────────────
// SUN_SCATTER_GAIN stands in for the multiple scattering this single-bounce
// model cannot resolve; it also lifts the fake GI on shadowed surfaces.
const float SUN_SCATTER_GAIN    = 2.5;
const float FAKE_GI_STRENGTH    = 0.05;
const vec3  AMBIENT_SKY_TINT    = vec3(0.5, 0.65, 1.0);
const float AMBIENT_GAIN        = 0.75;
const float LOCAL_LIGHT_EXP     = 3.0;
const vec3  LOCAL_LIGHT_TINT    = vec3(1.0, 0.6, 0.2);
const float MASTER_GAIN         = 0.6;
const float SPECULAR_ROUGHNESS  = 0.75;
const float SPECULAR_F0         = 0.03;
const float SPECULAR_F0_GRAZING = 0.15;
const float SPECULAR_GAIN       = 0.3;

void main()
{
    ivec2 pixelCoordinate = ivec2(gl_GlobalInvocationID.xy);
    ivec2 fullResolution = ivec2(viewWidth, viewHeight);
    if (any(greaterThanEqual(pixelCoordinate, fullResolution)))
    {
        return;
    }

    vec2 uv = (vec2(pixelCoordinate) + 0.5) / vec2(viewWidth, viewHeight);
    float depth = texelFetch(depthtex0, pixelCoordinate, 0).r;
    vec2 clipXY = uv * 2.0 - 1.0;
    vec3 viewRay = mat3(gbufferModelViewInverse) * (gbufferProjectionInverse * vec4(clipXY, 1.0, 1.0)).xyz;

    vec34 sunColor = transmittanceFromLUT({{IMG_TRANSMIT_LUT_SAMPLER}}, PLANET_RADIUS + altitudeFromEyePosition(eyeAltitude), clamp(sunDirection.y, -1.0, 1.0));
    #ifdef ENABLE_SPECTRAL
    sunColor.rgb = rgbFromSpectral(sunColor) * 0.2;
    #endif

    if (depth == 1.0)
    {
        vec3 viewDir = normalize(viewRay);
        vec34 trans = transmittanceFromLUT({{IMG_TRANSMIT_LUT_SAMPLER}}, PLANET_RADIUS + altitudeFromEyePosition(eyeAltitude), clamp(viewRay.y, -1.0, 1.0));
        #ifdef ENABLE_SPECTRAL
        trans.rgb = rgbFromSpectral(trans) * 0.2;
        #endif

        vec3 stars = texelFetch({{RT_BACK}}, pixelCoordinate, 0).rgb * trans.rgb;

        vec3 dither = (getNoise(noisetex, uv, vec2(viewWidth, viewHeight)).rgb - 0.5) * 0.03;
        vec3 sky = texture({{IMG_SKY_SAMPLER}}, uv).rgb;
        sky = sky * (1.0 + dither) + dither * 0.01;
        sky += stars;
        float sunCosAngle = dot(viewDir, normalize(sunDirection));
        float sunIntensity = sunDiscMask(sunCosAngle) * SUN_DISC_RADIANCE;
        sky += sunIntensity * trans.rgb;
        imageStore({{IMG_BACK}}, pixelCoordinate, vec4(sky, 1.0));
        return;
    }

    vec3 baseColor = texelFetch({{RT_BASE_COLOR}}, pixelCoordinate, 0).rgb;
    vec4 normal = texelFetch({{RT_NORMAL}}, pixelCoordinate, 0);
    vec4 lighting0 = texelFetch({{RT_LIGHTING0}}, pixelCoordinate, 0);

    vec3 NDCPosition = vec3(clipXY, depth * 2.0 - 1.0);
    vec3 viewPosition = projectAndDivide(gbufferProjectionInverse, NDCPosition);
    vec3 feetPlayerPosition = (gbufferModelViewInverse * vec4(viewPosition, 1.0)).xyz;
    vec3 shadowViewPosition = (shadowModelView * vec4(feetPlayerPosition, 1.0)).xyz;
    vec4 shadowClipPosition = shadowProjection * vec4(shadowViewPosition, 1.0);

    vec3 shadow = getSoftShadow(shadowtex0, shadowtex1, shadowcolor0, noisetex, shadowClipPosition, uv, vec2(viewWidth, viewHeight));
    float sunLightAmount = min(normal.a, float(shadow));

    float fakeGI = 1.0 + (1.0 - lighting0.b) * (1.0 - normal.a) * float(shadow) * SUN_SCATTER_GAIN;
    float fakeGIFactor = fakeGI * FAKE_GI_STRENGTH + (1.0 - FAKE_GI_STRENGTH);
    vec3 baseAlbedo = adjustSaturationFast(baseColor, fakeGIFactor);

    vec3 diffuseSun = sunLightAmount * (fakeGI * lighting0.g + SUN_SCATTER_GAIN) * sunColor.rgb;

    vec3 ambientLight = ambientAmount * lighting0.g * lighting0.b * AMBIENT_SKY_TINT
                      * getBrightness(sunColor.rgb) * AMBIENT_GAIN;

    vec3 localLight = pow(lighting0.r, LOCAL_LIGHT_EXP) * LOCAL_LIGHT_TINT;

    vec3 outColor = baseAlbedo * (diffuseSun + ambientLight + localLight) * MASTER_GAIN;

    vec3 N = normalize(normal.xyz * 2.0 - 1.0);
    vec3 V = mat3(gbufferModelViewInverse) * normalize(-viewPosition);
    vec3 L = normalize(sunDirection);
    vec3 H = normalize(V + L);
    float NoH = max(dot(N, H), 0.0);
    float spec = specularGGX(NoH, SPECULAR_ROUGHNESS);
    float f = SPECULAR_F0 + SPECULAR_F0_GRAZING * pow(max(1.0 - max(dot(N, V), 0.001), 0.001), 5.0);
    vec3 specColor = spec * sunColor.rgb * SUN_SCATTER_GAIN * sunLightAmount * f;
    outColor += specColor * SPECULAR_GAIN;

    imageStore({{IMG_BACK}}, pixelCoordinate, vec4(outColor, 1.0));
}
#endif
