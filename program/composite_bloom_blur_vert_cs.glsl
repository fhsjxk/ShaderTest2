// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/common.glsl"
#include "/lib/options.glsl"

uniform sampler2D {{RT_BLOOM}};

uniform float viewWidth;
uniform float viewHeight;
uniform int bloomMipCount; // Number of usable mip levels in the bloom atlas (total - 2)

/* RENDERTARGETS: {RT_BLOOM} */
layout({{IMG_BLOOM_FORMAT}}) uniform writeonly image2D {{IMG_BLOOM}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
const vec2 workGroupsRender = vec2(2.0, 1.0); // Match RT_BLOOM dimensions (2x screen width)

// Apply vertical 3-pixel Gaussian blur to the bloom atlas
// Read from and write to RT_BLOOM (in-place blur)
// Use clamping at mip boundaries to avoid sampling black pixels

vec3 sampleWithVerticalBlur(ivec2 coord, int mipLevel, ivec2 mipSize, int xOffset)
{
    // Gaussian weights for 3-tap vertical blur: [0.25, 0.5, 0.25]
    const float weightTop = 0.25;
    const float weightCenter = 0.5;
    const float weightBottom = 0.25;
    
    vec3 color = vec3(0.0);
    
    // Sample top pixel with clamping
    ivec2 topCoord = ivec2(coord.x, coord.y - 1);
    if (topCoord.y >= 0) {
        color += texelFetch({{RT_BLOOM}}, xOffset + topCoord, 0).rgb * weightTop;
    } else {
        // Clamp to edge
        color += texelFetch({{RT_BLOOM}}, xOffset + ivec2(coord.x, 0), 0).rgb * weightTop;
    }
    
    // Sample center pixel
    color += texelFetch({{RT_BLOOM}}, xOffset + coord, 0).rgb * weightCenter;
    
    // Sample bottom pixel with clamping
    ivec2 bottomCoord = ivec2(coord.x, coord.y + 1);
    if (bottomCoord.y < mipSize.y) {
        color += texelFetch({{RT_BLOOM}}, xOffset + bottomCoord, 0).rgb * weightBottom;
    } else {
        // Clamp to edge
        color += texelFetch({{RT_BLOOM}}, xOffset + ivec2(coord.x, mipSize.y - 1), 0).rgb * weightBottom;
    }
    
    return color;
}

void main()
{
    ivec2 pixelCoord = ivec2(gl_GlobalInvocationID.xy);
    
    int usableMipLevels = bloomMipCount;
    
    if (usableMipLevels <= 1) { // Need at least mip level 1 for meaningful blur
        return;
    }
    
    // Calculate which mip level this pixel belongs to
    // Mip levels are arranged horizontally: [mip1][mip2]...[mipN-2]
    // Note: We start from i=1, so mip0 is not included in the atlas for blur
    int xOffset = 0;
    int targetMipLevel = -1;
    ivec2 mipCoord = ivec2(0);
    ivec2 mipSize = ivec2(0);
    
    for (int i = 1; i < usableMipLevels; i++) { // Start from i=1 as specified
        mipSize = ivec2(viewWidth, viewHeight) >> i;
        if (pixelCoord.x >= xOffset && pixelCoord.x < xOffset + mipSize.x &&
            pixelCoord.y >= 0 && pixelCoord.y < mipSize.y) {
            targetMipLevel = i;
            mipCoord = pixelCoord - ivec2(xOffset, 0);
            break;
        }
        xOffset += mipSize.x;
    }
    
    if (targetMipLevel == -1) {
        // Pixel is outside of any mip region (or is mip 0 which we skip)
        return;
    }
    
    // Apply vertical 3-pixel Gaussian blur with edge clamping
    vec3 color = sampleWithVerticalBlur(mipCoord, targetMipLevel, mipSize, xOffset);
    
    imageStore({{IMG_BLOOM}}, pixelCoord, vec4(color, 1.0));
}
#endif
