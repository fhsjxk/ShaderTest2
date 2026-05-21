// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/common.glsl"
#include "/lib/options.glsl"

uniform sampler2D {{RT_BACK}};
uniform sampler2D {{RT_BLOOM}};

uniform float viewWidth;
uniform float viewHeight;

/* RENDERTARGETS: {RT_BLOOM} */
layout({{IMG_BLOOM_FORMAT}}) uniform writeonly image2D {{IMG_BLOOM}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
// RT_BLOOM size is 1.0 0.5 (full width, half height)
const vec2 workGroupsRender = vec2(1.0, 0.5);

// Apply vertical 3-pixel Gaussian blur to the bloom atlas (separable from horizontal pass)
// Read from and write to RT_BLOOM (in-place blur)
// Use clamping at mip boundaries to avoid sampling black pixels from adjacent mip regions or unused area

vec3 sampleWithVerticalBlur(ivec2 coord, int mipLevel, ivec2 mipSize, int xOffset)
{
    // Gaussian weights for 5-tap vertical blur (Pascal triangle): [1,4,6,4,1] / 16
    const float weightOuterTop = 0.0625;
    const float weightInnerTop = 0.25;
    const float weightCenter   = 0.375;
    const float weightInnerBot = 0.25;
    const float weightOuterBot = 0.0625;
    
    vec3 color = vec3(0.0);
    
    // Outer-top tap (offset -2)
    ivec2 outerTopCoord = ivec2(coord.x, coord.y - 2);
    if (outerTopCoord.y >= 0) {
        color += texelFetch({{RT_BLOOM}}, ivec2(xOffset + outerTopCoord.x, outerTopCoord.y), 0).rgb * weightOuterTop;
    } else {
        color += texelFetch({{RT_BLOOM}}, ivec2(xOffset + coord.x, 0), 0).rgb * weightOuterTop;
    }
    
    // Inner-top tap (offset -1)
    ivec2 innerTopCoord = ivec2(coord.x, coord.y - 1);
    if (innerTopCoord.y >= 0) {
        color += texelFetch({{RT_BLOOM}}, ivec2(xOffset + innerTopCoord.x, innerTopCoord.y), 0).rgb * weightInnerTop;
    } else {
        color += texelFetch({{RT_BLOOM}}, ivec2(xOffset + coord.x, 0), 0).rgb * weightInnerTop;
    }
    
    // Center tap
    color += texelFetch({{RT_BLOOM}}, ivec2(xOffset + coord.x, coord.y), 0).rgb * weightCenter;
    
    // Inner-bottom tap (offset +1)
    ivec2 innerBotCoord = ivec2(coord.x, coord.y + 1);
    if (innerBotCoord.y < mipSize.y) {
        color += texelFetch({{RT_BLOOM}}, ivec2(xOffset + innerBotCoord.x, innerBotCoord.y), 0).rgb * weightInnerBot;
    } else {
        color += texelFetch({{RT_BLOOM}}, ivec2(xOffset + coord.x, mipSize.y - 1), 0).rgb * weightInnerBot;
    }
    
    // Outer-bottom tap (offset +2)
    ivec2 outerBotCoord = ivec2(coord.x, coord.y + 2);
    if (outerBotCoord.y < mipSize.y) {
        color += texelFetch({{RT_BLOOM}}, ivec2(xOffset + outerBotCoord.x, outerBotCoord.y), 0).rgb * weightOuterBot;
    } else {
        color += texelFetch({{RT_BLOOM}}, ivec2(xOffset + coord.x, mipSize.y - 1), 0).rgb * weightOuterBot;
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
    int usableMipLevels = min(totalMipLevels - 2, BLOOM_MAX_MIPS);
    
    if (usableMipLevels <= 1) { // Need at least mip level 1 for meaningful blur
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
        // Pixel is outside of any mip region
        return;
    }
    
    // Apply vertical 3-pixel Gaussian blur with edge clamping
    vec3 color = sampleWithVerticalBlur(mipCoord, targetMipLevel, mipSize, xOffset);
    
    imageStore({{IMG_BLOOM}}, pixelCoord, vec4(color, 1.0));
}
#endif
