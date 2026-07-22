// Shared shadow mapping utilities and shadow pass shaders
// Included by: deferred_lighting_cs (compute), shadow pass (vert/frag via build.py)

#ifndef SHADOWMAP
#define SHADOWMAP

// ── Shadow clip-space distortion (Iris shadow map projection) ─

vec3 distortShadowClipPos(vec3 shadowClipPosition)
{
    float distortionFactor = length(shadowClipPosition.xy);
    distortionFactor += 0.1;
    shadowClipPosition.xy /= distortionFactor;
    shadowClipPosition.z *= 0.5;
    return shadowClipPosition;
}

// ── Projection helpers ───────────────────────────────────────

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position)
{
    vec4 homogeneousPosition = projectionMatrix * vec4(position, 1.0);
    return homogeneousPosition.xyz / homogeneousPosition.w;
}

#ifdef SHADER_COMP

// ── Shadow sampling (compute only) ───────────────────────────

vec3 getShadow(sampler2D shadowtex0, sampler2D shadowtex1, sampler2D shadowcolor0,
               vec3 shadowScreenPosition)
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

// ── Noise (compute only) ─────────────────────────────────────

vec4 getNoise(sampler2D noisetex, vec2 coordinate, vec2 viewSize)
{
    ivec2 screenCoordinate = ivec2(coordinate * viewSize);
    ivec2 noiseCoordinate = screenCoordinate % 64;
    return texelFetch(noisetex, noiseCoordinate, 0);
}

// ── Soft shadow (compute only) ───────────────────────────────

vec3 getSoftShadow(sampler2D shadowtex0, sampler2D shadowtex1, sampler2D shadowcolor0,
                   sampler2D noisetex, vec4 shadowClipPosition, vec2 uv, vec2 viewSize)
{
    float noise = getNoise(noisetex, uv, viewSize).r;
    float theta = noise * radians(360.0);
    float cosTheta = cos(theta);
    float sinTheta = sin(theta);
    mat2 rotation = mat2(cosTheta, -sinTheta, sinTheta, cosTheta);

    vec3 shadowAccumulation = vec3(0.0);
    const int SHADOW_RANGE = 3;
    const float SHADOW_RADIUS = 0.5;
    const int samples = SHADOW_RANGE * SHADOW_RANGE * 4;

    for (int x = -SHADOW_RANGE; x < SHADOW_RANGE; x++)
    {
        for (int y = -SHADOW_RANGE; y < SHADOW_RANGE; y++)
        {
            vec2 offset = vec2(x, y) * SHADOW_RADIUS / float(SHADOW_RANGE);
            offset = rotation * offset;
            offset /= shadowMapResolution;
            vec4 offsetShadowClipPosition = shadowClipPosition + vec4(offset, 0.0, 0.0);
            offsetShadowClipPosition.z -= 0.001;
            offsetShadowClipPosition.xyz = distortShadowClipPos(offsetShadowClipPosition.xyz);
            vec3 shadowNDCPosition = offsetShadowClipPosition.xyz / offsetShadowClipPosition.w;
            vec3 shadowScreenPosition = shadowNDCPosition * 0.5 + 0.5;
            shadowAccumulation += getShadow(shadowtex0, shadowtex1, shadowcolor0, shadowScreenPosition);
        }
    }

    return shadowAccumulation / float(samples);
}

#endif // SHADER_COMP

#endif // SHADOWMAP

// {{SHADER_FRAG}}
#ifdef {{SHADER_FRAG}}
uniform sampler2D gtexture;

in float alpha;
in vec2 texcoord;

void main()
{
    if (texture(gtexture, texcoord).a * alpha < 0.52)
    {
        discard;
    }
}
#endif

// {{SHADER_VERT}}
#ifdef {{SHADER_VERT}}
out float alpha;
out vec2 texcoord;

void main()
{
    gl_Position = ftransform();
    gl_Position.xyz = distortShadowClipPos(gl_Position.xyz);
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    alpha = gl_Color.a;
}
#endif
