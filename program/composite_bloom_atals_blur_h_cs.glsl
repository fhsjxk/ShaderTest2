// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/common.glsl"
#include "/lib/options.glsl"

uniform sampler2D {{RT_BACK}};

uniform float viewWidth;
uniform float viewHeight;

/* RENDERTARGETS: {RT_BLOOM} */
layout({{IMG_BLOOM_FORMAT}}) uniform writeonly image2D {{IMG_BLOOM}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
// RT_BLOOM size is 1.0 0.5 (full width, half height), enough to hold all mip levels side by side
const vec2 workGroupsRender = vec2(1.0, 0.5);

// Pack mipmaps from RT_BACK into RT_BLOOM as a texture atlas
// Layout: Each mip level is placed side by side horizontally: [mip1][mip2]...[mipN-2]
// Skip mip 0 (full res - too detailed) and smallest 2 mip levels
// Apply horizontal 3-pixel Gaussian blur during sampling
// Extract highlights using bloom threshold/knee

vec3 sampleWithHorizontalBlur(ivec2 coord, int mipLevel, ivec2 mipSize)
{
    // Gaussian weights for 5-tap horizontal blur (Pascal triangle): [1,4,6,4,1] / 16
    const float weightInnerLeft  = 0.25;
    const float weightCenter     = 0.375;
    const float weightInnerRight = 0.25;
    const float weightOuterLeft  = 0.0625;
    const float weightOuterRight = 0.0625;
    
    vec3 color = vec3(0.0);
    
    // Outer-left tap (offset -2)
    if (coord.x - 2 >= 0) {
        color += texelFetch({{RT_BACK}}, ivec2(coord.x - 2, coord.y), mipLevel).rgb * weightOuterLeft;
    } else {
        color += texelFetch({{RT_BACK}}, coord, mipLevel).rgb * weightOuterLeft;
    }
    
    // Inner-left tap (offset -1)
    if (coord.x - 1 >= 0) {
        color += texelFetch({{RT_BACK}}, ivec2(coord.x - 1, coord.y), mipLevel).rgb * weightInnerLeft;
    } else {
        color += texelFetch({{RT_BACK}}, coord, mipLevel).rgb * weightInnerLeft;
    }
    
    // Center tap
    color += texelFetch({{RT_BACK}}, coord, mipLevel).rgb * weightCenter;
    
    // Inner-right tap (offset +1)
    if (coord.x + 1 < mipSize.x) {
        color += texelFetch({{RT_BACK}}, ivec2(coord.x + 1, coord.y), mipLevel).rgb * weightInnerRight;
    } else {
        color += texelFetch({{RT_BACK}}, coord, mipLevel).rgb * weightInnerRight;
    }
    
    // Outer-right tap (offset +2)
    if (coord.x + 2 < mipSize.x) {
        color += texelFetch({{RT_BACK}}, ivec2(coord.x + 2, coord.y), mipLevel).rgb * weightOuterRight;
    } else {
        color += texelFetch({{RT_BACK}}, coord, mipLevel).rgb * weightOuterRight;
    }
    
    return color;
}

void main()
{
    ivec2 pixelCoord = ivec2(gl_GlobalInvocationID.xy);
    ivec2 bloomRes = ivec2(viewWidth, viewHeight * 0.5);
    if (any(greaterThanEqual(pixelCoord, bloomRes))) {
        return;
    }
    
    int totalMipLevels = textureQueryLevels({{RT_BACK}});
    int usableMipLevels = min(totalMipLevels - 2, BLOOM_MAX_MIPS); // Skip smallest 2 mips, cap at BLOOM_MAX_MIPS
    
    if (usableMipLevels <= 1) {
        imageStore({{IMG_BLOOM}}, pixelCoord, vec4(0.0, 0.0, 0.0, 1.0));
        return;
    }
    
    // Calculate which mip level this pixel belongs to
    // Mip levels are arranged horizontally: [mip1][mip2]...[mipN-2]
    int xOffset = 0;
    int targetMipLevel = -1;
    ivec2 mipCoord = ivec2(0);
    ivec2 mipSize = ivec2(0);
    
    for (int i = 1; i < usableMipLevels; i++) {
        mipSize = max(ivec2(viewWidth, viewHeight) >> i, ivec2(1));
        if (pixelCoord.x >= xOffset && pixelCoord.x < xOffset + mipSize.x) {
            targetMipLevel = i;
            mipCoord = pixelCoord - ivec2(xOffset, 0);
            break;
        }
        xOffset += mipSize.x;
    }
    
    if (targetMipLevel == -1) {
        // Pixel is in unused area of bloom buffer (past the last mip region)
        imageStore({{IMG_BLOOM}}, pixelCoord, vec4(0.0, 0.0, 0.0, 1.0));
        return;
    }
    
    // Sample with horizontal 3-pixel Gaussian blur
    vec3 color = sampleWithHorizontalBlur(mipCoord, targetMipLevel, mipSize);
    
    // Apply bloom threshold and knee to extract highlights
    float luma = getBrightness(color);
    float threshold = BLOOM_THRESHOLD;
    float knee = max(BLOOM_KNEE, 1e-4);
    float soft = clamp((luma - threshold + knee) / (2.0 * knee), 0.0, 1.0);
    float highPass = max(luma - threshold, 0.0) + soft * soft * knee;
    
    // Only write if above threshold
    if (highPass > 0.0) {
        color *= highPass / max(luma, 1e-4);
        imageStore({{IMG_BLOOM}}, pixelCoord, vec4(color, 1.0));
    } else {
        imageStore({{IMG_BLOOM}}, pixelCoord, vec4(0.0, 0.0, 0.0, 1.0));
    }
}
#endif
