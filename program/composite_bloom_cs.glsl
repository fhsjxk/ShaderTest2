// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/common.glsl"
#include "/lib/options.glsl"

uniform sampler2D noisetex;
uniform sampler2D {{RT_BACK}};
uniform sampler2D {{IMG_BLOOM_SAMPLER}};

uniform float viewWidth;
uniform float viewHeight;

layout({{IMG_BACK_FORMAT}}) uniform writeonly image2D {{IMG_BACK}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

const vec2 workGroupsRender = vec2(1.0, 1.0);

// Final bloom composite step
// 1. Read original scene color from RT_BACK (mip 0)
// 2. Read bloom atlas from IMG_BLOOM_SAMPLER (contains blurred, bright-passed mip levels side by side)
// 3. For each pixel, upsample bloom from all mip levels and accumulate
// 4. Apply bloom strength and add to original color
// 5. Write result back to RT_BACK

// Convert screen pixel coordinate to bloom atlas UV for a given mip level.
// Screen pixel (x, y) maps to continuous mip position (x/2^i, y/2^i).
// We MUST NOT snap to texel centers — keeping the continuous position lets
// texture() with GL_LINEAR properly interpolate between adjacent mip texels.
vec2 screenToBloomAtlasUV(ivec2 pixelCoordinate, int mipLevel, int xOffset, vec2 atlasSize)
//vec2 screenToBloomAtlasUV(ivec2 pixelCoord, int mipLevel, int xOffset, vec2 atlasSize)$
{
    // Continuous position in mip texture space (no floor, no +0.5 snap)
    vec2 mipPosition = vec2(pixelCoordinate) / exp2(float(mipLevel));
    // Position in atlas pixel space
    vec2 atlasPixelPosition = vec2(float(xOffset), 0.0) + mipPosition;
    return atlasPixelPosition / atlasSize;
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

    vec3 color = texelFetch({{RT_BACK}}, pixelCoordinate, 0).rgb;

    int totalMipLevels = textureQueryLevels({{RT_BACK}});
    int usableMipLevels = min(totalMipLevels - 2, BLOOM_MAX_MIPS);

    if (usableMipLevels <= 1)
    {
        // No bloom to apply, pass through
        imageStore({{IMG_BACK}}, pixelCoordinate, vec4(color, 1.0));
        return;
    }

    // Dither offset for bloom sample UVs (in atlas pixel units)
    // Jittering the sample position breaks up banding from quantized mip levels
    vec2 noiseUv = vec2(pixelCoordinate) / 128.0;
    vec2 ditherPixels = (texture(noisetex, noiseUv).rg - 0.5);
    vec2 ditherUv = ditherPixels / vec2(textureSize({{IMG_BLOOM_SAMPLER}}, 0));

    // Accumulate bloom from all mip levels in the atlas
    vec3 bloomAccumulation = vec3(0.0);
    //vec3 bloomAccum = vec3(0.0);$
    vec2 atlasSize = vec2(textureSize({{IMG_BLOOM_SAMPLER}}, 0));

    int xOffset = 0;
    for (int i = 1; i < usableMipLevels; i++)
    {
        ivec2 mipSize = max(ivec2(viewWidth, viewHeight) >> i, ivec2(1));

        // Compute bloom atlas UV for this pixel at this mip level
        vec2 atlasUV = screenToBloomAtlasUV(pixelCoordinate, i, xOffset, atlasSize);

        // Jitter UV to reduce banding (dither the sample position, not the color)
        atlasUV += ditherUv;

        // Sample bloom atlas with bilinear filtering for smooth upsampling
        vec3 bloomSample = texture({{IMG_BLOOM_SAMPLER}}, atlasUV).rgb;

        bloomAccumulation += bloomSample;

        xOffset += mipSize.x;
    }

    // Normalize by number of mip levels and apply bloom strength
    float bloomWeight = BLOOM_STRENGTH / max(float(usableMipLevels - 1), 1.0);
    vec3 bloomContribution = bloomAccumulation * bloomWeight;
    bloomContribution = max(bloomContribution, vec3(0.0));

    // Composite bloom onto original color (additive blending)
    vec3 finalColor = color + bloomContribution;

    imageStore({{IMG_BACK}}, pixelCoordinate, vec4(finalColor, 1.0));
}
#endif
