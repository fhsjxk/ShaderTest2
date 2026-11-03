// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/prelude.glsl"
#include "/lib/lighting/brdf.glsl"
#include "/lib/lighting/tuning.glsl"
#include "/lib/utility/color.glsl"
#include "/lib/lighting/shadow.glsl"
#include "/lib/atmosphere/all.glsl"

uniform sampler2D depthtex0;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D noisetex;
uniform sampler2D {{RT_ALBEDO}};
uniform sampler2D {{RT_NORMAL}};
uniform sampler2D {{RT_LIGHTMAP}};
uniform sampler2D {{RT_HDR}};
uniform sampler2D {{IMG_SKY_SAMPLER}};
uniform sampler2D {{IMG_TRANSMIT_LUT_SAMPLER}};

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 sunDirection;
uniform float eyeAltitude;
uniform float viewWidth;
uniform float viewHeight;

layout({{RT_HDR_FORMAT}}) uniform writeonly image2D {{RT_HDR_IMG}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
const vec2 workGroupsRender = vec2(1.0, 1.0);

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

    // Transmittance from the eye towards the sun; converts the extraterrestrial
    // irradiance into the irradiance reaching the scene.
    float eyeRadius = PLANET_RADIUS_KM + altitudeFromEyePosition(eyeAltitude);
    vec34 sunTransmittance = transmittanceFromLUT({{IMG_TRANSMIT_LUT_SAMPLER}}, eyeRadius, clamp(sunDirection.y, -1.0, 1.0));
    #ifdef ENABLE_SPECTRAL
    sunTransmittance.rgb = rgbFromSpectral(sunTransmittance) * 0.2;
    #endif

    if (depth == 1.0)
    {
        vec3 viewDir = normalize(viewRay);
        vec34 trans = transmittanceFromLUT({{IMG_TRANSMIT_LUT_SAMPLER}}, eyeRadius, clamp(viewRay.y, -1.0, 1.0));
        #ifdef ENABLE_SPECTRAL
        trans.rgb = rgbFromSpectral(trans) * 0.2;
        #endif

        vec3 stars = texelFetch({{RT_HDR}}, pixelCoordinate, 0).rgb * trans.rgb;

        vec3 dither = (getNoise(noisetex, uv, vec2(viewWidth, viewHeight)).rgb - 0.5) * 0.03;
        vec3 sky = texture({{IMG_SKY_SAMPLER}}, uv).rgb;
        sky = sky * (1.0 + dither) + dither * 0.01;
        sky += stars;

        // Solar disc, attenuated by the same transmittance as the direct beam.
        // Scaled down to fit the half-float HDR buffer, see SUN_DISC_RENDER_SCALE.
        float sunCosAngle = dot(viewDir, normalize(sunDirection));
        sky += sunDiscMask(sunCosAngle) * SUN_DISC_RENDER_RADIANCE * trans.rgb;

        imageStore({{RT_HDR_IMG}}, pixelCoordinate, vec4(sky, 1.0));
        return;
    }

    vec3 albedo   = texelFetch({{RT_ALBEDO}}, pixelCoordinate, 0).rgb;
    vec4 normal   = texelFetch({{RT_NORMAL}}, pixelCoordinate, 0);
    vec4 lightmap = texelFetch({{RT_LIGHTMAP}}, pixelCoordinate, 0);

    vec3 NDCPosition = vec3(clipXY, depth * 2.0 - 1.0);
    vec3 viewPosition = projectAndDivide(gbufferProjectionInverse, NDCPosition);
    vec3 feetPlayerPosition = (gbufferModelViewInverse * vec4(viewPosition, 1.0)).xyz;
    vec3 shadowViewPosition = (shadowModelView * vec4(feetPlayerPosition, 1.0)).xyz;
    vec4 shadowClipPosition = shadowProjection * vec4(shadowViewPosition, 1.0);

    vec3 shadow = getSoftShadow(shadowtex0, shadowtex1, shadowcolor0, noisetex, shadowClipPosition, uv, vec2(viewWidth, viewHeight));

    vec3 N = normalize(normal.xyz * 2.0 - 1.0);
    vec3 V = mat3(gbufferModelViewInverse) * normalize(-viewPosition);
    vec3 L = normalize(sunDirection);

    // normal.a and normal.a again from the gbuffer: .a holds N.L against the sun
    // as computed in the vertex stage, the shadow map adds occlusion.
    float NdotL = max(normal.a, 0.0);
    float sunVisibility = min(normal.a, float(shadow));
    float NdotV = max(dot(N, V), 1e-4);

    // ── Direct sun ──────────────────────────────────────────
    // Irradiance on the surface (units) = extraterrestrial irradiance * T.
    vec34 sunIrradiance = SUN_IRRADIANCE * sunTransmittance;
    #ifdef ENABLE_SPECTRAL
    vec3 sunIrradianceRGB = rgbFromSpectral(sunIrradiance);
    #else
    vec3 sunIrradianceRGB = sunIrradiance;
    #endif

    // Cook-Torrance specular: F0 * E * cos(theta) with the full BRDF.
    vec3 specular = specularBRDF(N, V, L, SURFACE_ROUGHNESS, SURFACE_F0, SURFACE_F90)
                  * sunIrradianceRGB * sunVisibility * NdotL;

    // ── Sky and block light ─────────────────────────────────
    // Lightmap .g is skylight, .b is ambient occlusion, .r is block light.
    float skyVisibility = lightmap.g * lightmap.b;
    float blockLight    = lightmap.r;

    // ── Fake GI (medium quality tier) ───────────────────────
    // A real GI solution would add light bounced off nearby surfaces. This stands
    // in for it using the cheapest available signal: how much sky and sun the
    // surface is missing. Higher quality tiers replace this with a physical
    // solution, so the whole approximation is confined to this block.
    float missingLight = (1.0 - skyVisibility) * (1.0 - NdotL) * float(shadow);
    float fakeGI = 1.0 + FAKE_GI_GAIN * missingLight;

    // The bounce light carries the colour of its surroundings, which reads as a
    // small saturation lift where the fake GI term is strongest.
    float fakeGISaturation = saturate(1.0 + FAKE_GI_SATURATION * (fakeGI - 1.0));
    vec3 surfaceAlbedo = adjustSaturationFast(albedo, fakeGISaturation);

    vec3 skyIrradiance   = vec3(nitsToUnits(SKY_ILLUMINANCE_LUX)) * skyVisibility * vec3(0.3, 0.55, 1.0);
    vec3 blockIrradiance = vec3(nitsToUnits(BLOCK_LIGHT_ILLUMINANCE_LUX)) * blockLight;

    // Lambertian diffuse: L = albedo/pi * E * cos(theta).
    vec3 diffuse = albedo * INV_PI * sunIrradianceRGB * sunVisibility * fakeGI;

    vec3 ambient = surfaceAlbedo * INV_PI * (skyIrradiance + blockIrradiance);

    vec3 outColor = diffuse + specular + ambient;

    imageStore({{RT_HDR_IMG}}, pixelCoordinate, vec4(outColor, 1.0));
}
#endif
