// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/common.glsl"
#include "/lib/options.glsl"

uniform sampler2D depthtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowtex0;
uniform sampler2D shadowcolor0;
uniform sampler2D {{RT_BASE_COLOR}};
uniform sampler2D {{RT_NORMAL}};
uniform sampler2D {{RT_LIGHTING0}};
uniform sampler2D {{RT_SKYVIEW}};
uniform sampler2D noisetex;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 sunDirection;
uniform float ambientAmount;
uniform float viewWidth;
uniform float viewHeight;

/* RENDERTARGETS: {RT_BACK} */
layout({{RT_BACK_FORMAT_IMG}}) uniform writeonly image2D {{RT_BACK_IMG}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
const vec2 workGroupsRender = vec2(1.0, 1.0);

#define SHADOW_RANGE 3
#define SHADOW_RADIUS 0.5

vec3 distortShadowClipPos(vec3 shadowClipPos) {
    float distortionFactor = length(shadowClipPos.xy);
    distortionFactor += 0.1;
    shadowClipPos.xy /= distortionFactor;
    shadowClipPos.z *= 0.5;
    return shadowClipPos;
}

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position) {
    vec4 homPos = projectionMatrix * vec4(position, 1.0);
    return homPos.xyz / homPos.w;
}

vec3 getShadow(vec3 shadowScreenPos) {
    float transparentShadow = step(shadowScreenPos.z, texture(shadowtex0, shadowScreenPos.xy).r);
    if (transparentShadow == 1.0) {
        return vec3(1.0);
    }

    float opaqueShadow = step(shadowScreenPos.z, texture(shadowtex1, shadowScreenPos.xy).r);
    if (opaqueShadow == 0.0) {
        return vec3(0.0);
    }

    vec4 shadowColor = texture(shadowcolor0, shadowScreenPos.xy);
    return shadowColor.rgb * (1.0 - shadowColor.a);
}

vec4 getNoise(vec2 coord) {
    ivec2 screenCoord = ivec2(coord * vec2(viewWidth, viewHeight));
    ivec2 noiseCoord = screenCoord % 64;
    return texelFetch(noisetex, noiseCoord, 0);
}

vec3 getSoftShadow(vec4 shadowClipPos, vec2 uv) {
    float noise = getNoise(uv).r;
    float theta = noise * radians(360.0);
    float cosTheta = cos(theta);
    float sinTheta = sin(theta);
    mat2 rotation = mat2(cosTheta, -sinTheta, sinTheta, cosTheta);

    vec3 shadowAccum = vec3(0.0);
    const int samples = SHADOW_RANGE * SHADOW_RANGE * 4;

    for (int x = -SHADOW_RANGE; x < SHADOW_RANGE; x++) {
        for (int y = -SHADOW_RANGE; y < SHADOW_RANGE; y++) {
            vec2 offset = vec2(x, y) * SHADOW_RADIUS / float(SHADOW_RANGE);
            offset = rotation * offset;
            offset /= shadowMapResolution;
            vec4 offsetShadowClipPos = shadowClipPos + vec4(offset, 0.0, 0.0);
            offsetShadowClipPos.z -= 0.001;
            offsetShadowClipPos.xyz = distortShadowClipPos(offsetShadowClipPos.xyz);
            vec3 shadowNDCPos = offsetShadowClipPos.xyz / offsetShadowClipPos.w;
            vec3 shadowScreenPos = shadowNDCPos * 0.5 + 0.5;
            shadowAccum += getShadow(shadowScreenPos);
        }
    }

    return shadowAccum / float(samples);
}

void main() {
    ivec2 pixelCoord = ivec2(gl_GlobalInvocationID.xy);
    ivec2 fullRes = ivec2(viewWidth, viewHeight);
    if (any(greaterThanEqual(pixelCoord, fullRes))) {
        return;
    }

    vec2 uv = (vec2(pixelCoord) + 0.5) / vec2(viewWidth, viewHeight);
    float depth = texelFetch(depthtex0, pixelCoord, 0).r;
    vec2 clipXY = uv * 2.0 - 1.0;
    vec3 viewRay = mat3(gbufferModelViewInverse) * (gbufferProjectionInverse * vec4(clipXY, 1.0, 1.0)).xyz;

    if (depth == 1.0) {
        vec3 sky = texture({{RT_SKYVIEW}}, uv).rgb;
        sky += float(dot(normalize(viewRay), normalize(sunDirection)) > 0.9999) * 100.0;
        imageStore({{RT_BACK_IMG}}, pixelCoord, vec4(sky, 1.0));
        return;
    }

    vec3 baseColor = texelFetch({{RT_BASE_COLOR}}, pixelCoord, 0).rgb;
    vec4 normal = texelFetch({{RT_NORMAL}}, pixelCoord, 0);
    vec4 lighting0 = texelFetch({{RT_LIGHTING0}}, pixelCoord, 0);

    vec3 NDCPos = vec3(clipXY, depth * 2.0 - 1.0);
    vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDCPos);
    vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
    vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;
    vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);

    vec3 shadow = getSoftShadow(shadowClipPos, uv);
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
    imageStore({{RT_BACK_IMG}}, pixelCoord, vec4(outColor, 1.0));
}
#endif
