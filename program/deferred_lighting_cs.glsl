// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/common.glsl"
#include "/lib/options.glsl"
#include "/program/shadow_common.glsl"

uniform sampler2D depthtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowtex0;
uniform sampler2D shadowcolor0;
uniform sampler2D {{RT_BASE_COLOR}};
uniform sampler2D {{RT_NORMAL}};
uniform sampler2D {{RT_LIGHTING0}};
uniform sampler2D {{IMG_SKY_SAMPLER}};
uniform sampler2D noisetex;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 sunDirection;
uniform float ambientAmount;
uniform float viewWidth;
uniform float viewHeight;

layout({{IMG_BACK_FORMAT}}) uniform writeonly image2D {{IMG_BACK}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
const vec2 workGroupsRender = vec2(1.0, 1.0);

#define SHADOW_RANGE 3
#define SHADOW_RADIUS 0.5

// distortShadowClipPos() is now in /program/shadow_common.glsl$

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position)
//vec3 projectAndDivide(mat4 projectionMatrix, vec3 position) { ... }$
{
    vec4 homogeneousPosition = projectionMatrix * vec4(position, 1.0);
    //vec4 homPos = projectionMatrix * vec4(position, 1.0);$
    return homogeneousPosition.xyz / homogeneousPosition.w;
}

vec3 getShadow(vec3 shadowScreenPosition)
//vec3 getShadow(vec3 shadowScreenPos)$
{
    float transparentShadow = step(shadowScreenPosition.z, texture(shadowtex0, shadowScreenPosition.xy).r);
    if (transparentShadow == 1.0)
    {
        return vec3(1.0);
    }

    float opaqueShadow = step(shadowScreenPosition.z, texture(shadowtex1, shadowScreenPosition.xy).r);
    if (opaqueShadow == 0.0)
    {
        return vec3(0.0);
    }

    vec4 shadowColor = texture(shadowcolor0, shadowScreenPosition.xy);
    return shadowColor.rgb * (1.0 - shadowColor.a);
}

vec4 getNoise(vec2 coordinate)
//vec4 getNoise(vec2 coord)$
{
    ivec2 screenCoordinate = ivec2(coordinate * vec2(viewWidth, viewHeight));
    //ivec2 screenCoord = ivec2(coord * vec2(viewWidth, viewHeight));$
    ivec2 noiseCoordinate = screenCoordinate % 64;
    //ivec2 noiseCoord = screenCoord % 64;$
    return texelFetch(noisetex, noiseCoordinate, 0);
}

vec3 getSoftShadow(vec4 shadowClipPosition, vec2 uv)
//vec3 getSoftShadow(vec4 shadowClipPos, vec2 uv)$
{
    float noise = getNoise(uv).r;
    float theta = noise * radians(360.0);
    float cosTheta = cos(theta);
    float sinTheta = sin(theta);
    mat2 rotation = mat2(cosTheta, -sinTheta, sinTheta, cosTheta);

    vec3 shadowAccumulation = vec3(0.0);
    //vec3 shadowAccum = vec3(0.0);$
    const int samples = SHADOW_RANGE * SHADOW_RANGE * 4;

    for (int x = -SHADOW_RANGE; x < SHADOW_RANGE; x++)
    {
        for (int y = -SHADOW_RANGE; y < SHADOW_RANGE; y++)
        {
            vec2 offset = vec2(x, y) * SHADOW_RADIUS / float(SHADOW_RANGE);
            offset = rotation * offset;
            offset /= shadowMapResolution;
            vec4 offsetShadowClipPosition = shadowClipPosition + vec4(offset, 0.0, 0.0);
            //vec4 offsetShadowClipPos = shadowClipPos + vec4(offset, 0.0, 0.0);$
            offsetShadowClipPosition.z -= 0.001;
            offsetShadowClipPosition.xyz = distortShadowClipPos(offsetShadowClipPosition.xyz);
            vec3 shadowNDCPosition = offsetShadowClipPosition.xyz / offsetShadowClipPosition.w;
            //vec3 shadowNDCPos = offsetShadowClipPos.xyz / offsetShadowClipPos.w;$
            vec3 shadowScreenPosition = shadowNDCPosition * 0.5 + 0.5;
            //vec3 shadowScreenPos = shadowNDCPos * 0.5 + 0.5;$
            shadowAccumulation += getShadow(shadowScreenPosition);
        }
    }

    return shadowAccumulation / float(samples);
}

void main()
{
    ivec2 pixelCoordinate = ivec2(gl_GlobalInvocationID.xy);
    //ivec2 pixelCoord = ivec2(gl_GlobalInvocationID.xy);$
    ivec2 fullResolution = ivec2(viewWidth, viewHeight);
    //ivec2 fullRes = ivec2(viewWidth, viewHeight);$
    if (any(greaterThanEqual(pixelCoordinate, fullResolution)))
    {
        return;
    }

    vec2 uv = (vec2(pixelCoordinate) + 0.5) / vec2(viewWidth, viewHeight);
    float depth = texelFetch(depthtex0, pixelCoordinate, 0).r;
    vec2 clipXY = uv * 2.0 - 1.0;
    vec3 viewRay = mat3(gbufferModelViewInverse) * (gbufferProjectionInverse * vec4(clipXY, 1.0, 1.0)).xyz;

    if (depth == 1.0)
    {
        vec3 dither = (getNoise(uv).rgb - 0.5) * 0.05;
        vec3 sky = texture({{IMG_SKY_SAMPLER}}, uv).rgb;
        sky = sky * (1.0 + dither) + dither * 0.05;
        sky += float(dot(normalize(viewRay), normalize(sunDirection)) > 0.9999) * 1000.0;
        imageStore({{IMG_BACK}}, pixelCoordinate, vec4(sky, 1.0));
        //imageStore({{RT_BACK_IMG}}, pixelCoord, vec4(sky, 1.0));$
        return;
    }

    vec3 baseColor = texelFetch({{RT_BASE_COLOR}}, pixelCoordinate, 0).rgb;
    vec4 normal = texelFetch({{RT_NORMAL}}, pixelCoordinate, 0);
    vec4 lighting0 = texelFetch({{RT_LIGHTING0}}, pixelCoordinate, 0);

    vec3 NDCPosition = vec3(clipXY, depth * 2.0 - 1.0);
    //vec3 NDCPos = vec3(clipXY, depth * 2.0 - 1.0);$
    vec3 viewPosition = projectAndDivide(gbufferProjectionInverse, NDCPosition);
    //vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDCPos);$
    vec3 feetPlayerPosition = (gbufferModelViewInverse * vec4(viewPosition, 1.0)).xyz;
    //vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;$
    vec3 shadowViewPosition = (shadowModelView * vec4(feetPlayerPosition, 1.0)).xyz;
    //vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;$
    vec4 shadowClipPosition = shadowProjection * vec4(shadowViewPosition, 1.0);
    //vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);$

    vec3 shadow = getSoftShadow(shadowClipPosition, uv);
    float sunLightAmount = min(normal.a, float(shadow));

    float fakeGI = 1.0 + (1.0 - lighting0.b) * (1.0 - normal.a) * float(shadow) * 3.0;
    float fakeGIFactor = fakeGI * 0.05 + 0.95;
    vec3 baseAlbedo = adjustSaturationFast(baseColor, fakeGIFactor);

    vec3 sunColor = vec3(0.95, 0.88, 0.84);
    vec3 diffuseSun = sunLightAmount * (fakeGI * lighting0.g + 3.0 * sunColor);

    vec3 skyColor = vec3(0.4, 0.6, 1.0);
    vec3 ambientLight = ambientAmount * lighting0.g * lighting0.b * skyColor;

    vec3 localLightColor = vec3(1.0, 0.6, 0.2);
    vec3 localLight = pow(lighting0.r, 3.0) * localLightColor * 5.0;

    const float masterGain = 0.6;
    vec3 outColor = baseAlbedo * (diffuseSun + ambientLight + localLight) * masterGain;
    imageStore({{IMG_BACK}}, pixelCoordinate, vec4(outColor, 1.0));
}
#endif
