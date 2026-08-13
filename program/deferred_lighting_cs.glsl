// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/common.glsl"
#include "/lib/math.glsl"
#include "/lib/options.glsl"
#include "/lib/brdf.glsl"
#include "/lib/color.glsl"
#include "/lib/shadowmap.glsl"
#include "/lib/atmosphere.glsl"

uniform sampler2D depthtex0;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D noisetex;
uniform sampler2D nightSkyTex;
uniform sampler2D {{RT_BASE_COLOR}};
uniform sampler2D {{RT_NORMAL}};
uniform sampler2D {{RT_LIGHTING0}};
uniform sampler2D {{RT_BACK}};
uniform sampler2D {{IMG_SKY_SAMPLER}};
uniform sampler2D {{IMG_TRANSMIT_LUT_SAMPLER}};
uniform sampler2D {{IMG_FROXEL_SAMPLER}};

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

    vec34 sunColor = transmittanceFromLUT({{IMG_TRANSMIT_LUT_SAMPLER}}, PLANET_RADIUS + max((eyeAltitude - 64.0) * 0.02, 0.001), clamp(sunDirection.y, -1.0, 1.0));
    #ifdef ENABLE_SPECTRAL
    sunColor.rgb = rgbFromSpectral(sunColor) * 0.2;
    #endif

    //sunColor.rgb = pow(sunColor.rgb, vec3(1.5)) * 1.15;

    if (depth == 1.0)
    {
        vec3 viewDir = normalize(viewRay);
        vec34 trans = transmittanceFromLUT({{IMG_TRANSMIT_LUT_SAMPLER}}, PLANET_RADIUS + max((eyeAltitude - 64.0) * 0.02, 0.001), clamp(viewRay.y, -1.0, 1.0));
        #ifdef ENABLE_SPECTRAL
        trans.rgb = rgbFromSpectral(trans) * 0.2;
        #endif

        vec3 stars = texelFetch({{RT_BACK}}, pixelCoordinate, 0).rgb * trans.rgb;

        vec3 dither = (getNoise(noisetex, uv, vec2(viewWidth, viewHeight)).rgb - 0.5) * 0.03;
        vec3 sky = texture({{IMG_SKY_SAMPLER}}, uv).rgb;
        sky = sky * (1.0 + dither) + dither * 0.01;
        sky += stars;
        float sunCosAngle = dot(viewDir, normalize(sunDirection));
        float sunIntensity = (smoothstep(0.999983, 1.00005, sunCosAngle) * 0.98 + 0.02) * (step(0.9999893, sunCosAngle));
        //float glow = pow(max(sunCosAngle - 0.9999, 0.0), 2.0) * 5.0;
        sky += (sunIntensity * 10000.0) * trans.rgb;
        //sky += float(dot(viewDir, normalize(sunDirection)) > 0.9999893) * 1000.0 * trans.rgb;$
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
    //shadow = vec3(1);
    float sunLightAmount = min(normal.a, float(shadow));

    float temp1 = 2.5;

    float fakeGI = 1.0 + (1.0 - lighting0.b) * (1.0 - normal.a) * float(shadow) * temp1;
    float fakeGIFactor = fakeGI * 0.05 + 0.95;
    vec3 baseAlbedo = adjustSaturationFast(baseColor, fakeGIFactor);

    vec3 diffuseSun = sunLightAmount * (fakeGI * lighting0.g * sunColor.rgb + temp1 * sunColor.rgb);

    //vec3 skyColor = vec3(0.4, 0.6, 1.0);
    vec3 skyColor = vec3(0.5, 0.65, 1.0);
    vec3 ambientLight = ambientAmount * lighting0.g * lighting0.b * skyColor * getBrightness(sunColor.rgb) * 0.75;

    vec3 localLightColor = vec3(1.0, 0.6, 0.2);
    vec3 localLight = pow(lighting0.r, 3.0) * localLightColor * 1.0;

    const float MASTER_GAIN = 0.6;
    vec3 outColor = baseAlbedo * (diffuseSun + ambientLight + localLight) * MASTER_GAIN;

    //float viewDist = length(feetPlayerPosition);
    //vec4 froxel = sampleFroxel({{IMG_FROXEL_SAMPLER}}, uv, viewDist*0.0);
    //vec3 fogColor = froxel.rgb;
    //float fogTrans = froxel.a;
    //outColor = outColor * fogTrans + fogColor * (1.0 - fogTrans);

    vec3 N = normalize(normal.xyz * 2.0 - 1.0);
    vec3 V = mat3(gbufferModelViewInverse) * normalize(-viewPosition);
    vec3 L = normalize(sunDirection);
    vec3 H = normalize(V + L);
    float NoH = max(dot(N, H), 0.0);
    //float spec = specularGTR(NoH, 0.5, 1.5);
    float spec = specularGGX(NoH, 0.75);
    float f = 0.03 + 0.15 * pow(max(1.0 - max(dot(N, V), 0.001), 0.001), 5.0);
    vec3 specColor = spec * sunColor.rgb * temp1 * sunLightAmount * f;
    outColor += specColor * 0.3;

    imageStore({{IMG_BACK}}, pixelCoordinate, vec4(outColor, 1.0));
}
#endif
