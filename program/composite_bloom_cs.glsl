// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/common.glsl"
#include "/lib/options.glsl"

uniform sampler2D noisetex;
uniform sampler2D {{RT_BACK}};

uniform float viewWidth;
uniform float viewHeight;

layout({{IMG_BACK_FORMAT}}) uniform writeonly image2D {{IMG_BACK}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

const vec2 workGroupsRender = vec2(1.0, 1.0);

vec3 sampleBloom9Tap(vec2 uv, vec2 texelStep, int mipLevel, vec2 jitter)
{
    vec3 bloom = vec3(0.0);
    bloom += textureLod({{RT_BACK}}, uv + jitter + vec2(-texelStep.x, texelStep.y), mipLevel).rgb * 0.0625;
    bloom += textureLod({{RT_BACK}}, uv + jitter + vec2(0.0, texelStep.y), mipLevel).rgb * 0.1250;
    bloom += textureLod({{RT_BACK}}, uv + jitter + vec2(texelStep.x, texelStep.y), mipLevel).rgb * 0.0625;

    bloom += textureLod({{RT_BACK}}, uv + jitter + vec2(-texelStep.x, 0.0), mipLevel).rgb * 0.1250;
    bloom += textureLod({{RT_BACK}}, uv + jitter, mipLevel).rgb * 0.2500;
    bloom += textureLod({{RT_BACK}}, uv + jitter + vec2(texelStep.x, 0.0), mipLevel).rgb * 0.1250;

    bloom += textureLod({{RT_BACK}}, uv + jitter + vec2(-texelStep.x, -texelStep.y), mipLevel).rgb * 0.0625;
    bloom += textureLod({{RT_BACK}}, uv + jitter + vec2(0.0, -texelStep.y), mipLevel).rgb * 0.1250;
    bloom += textureLod({{RT_BACK}}, uv + jitter + vec2(texelStep.x, -texelStep.y), mipLevel).rgb * 0.0625;
    return bloom;
}

void main()
{
    ivec2 pixelCoord = ivec2(gl_GlobalInvocationID.xy);
    ivec2 fullRes = ivec2(viewWidth, viewHeight);
    if (any(greaterThanEqual(pixelCoord, fullRes))) {
        return;
    }

    vec2 uv = (vec2(pixelCoord) + 0.5) / vec2(viewWidth, viewHeight);
    vec3 baseColor = texelFetch({{RT_BACK}}, pixelCoord, 0).rgb;

    int mipCount = textureQueryLevels({{RT_BACK}});
    vec3 bloomAccum = vec3(0.0);
    float bloomWeightAccum = 0.0;

    vec2 dither = (texture(noisetex, (vec2(pixelCoord) + 0.5) / 128.0).rg - 0.5) * BLOOM_DITHER;
    float threshold = BLOOM_THRESHOLD;
    float knee = max(BLOOM_KNEE, 1e-4);
    int mipLimit = min(mipCount, 2 + BLOOM_MAX_MIPS);

    for (int i = 2; i < mipLimit; ++i) {
        vec2 mipScale = exp2(vec2(i));
        vec2 texelStep = 1.0 / max(vec2(1.0), vec2(viewWidth, viewHeight) / mipScale);
        vec2 jitter = dither * texelStep;

        vec3 bloom = sampleBloom9Tap(uv, texelStep, i, jitter);

        float luma = dot(bloom, vec3(0.2126, 0.7152, 0.0722));
        float soft = clamp((luma - threshold + knee) / (2.0 * knee), 0.0, 1.0);
        float highPass = max(luma - threshold, 0.0) + soft * soft * knee;
        bloom *= highPass / max(luma, 1e-4);

        float mipWeight = exp(-0.42 * float(i - 2));
        bloomAccum += bloom * mipWeight;
        bloomWeightAccum += mipWeight;
    }

    vec3 bloomColor = bloomAccum / max(bloomWeightAccum, 1e-4);
    float resolutionScale = sqrt((viewWidth * viewHeight) / (1920.0 * 1080.0));
    float bloomStrength = BLOOM_STRENGTH / max(resolutionScale, 0.75);
    vec3 finalColor = baseColor + bloomColor * bloomStrength;

    imageStore({{IMG_BACK}}, pixelCoord, vec4(finalColor, 1.0));
}
#endif
