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

// Apply horizontal 3-pixel Gaussian blur to the bloom atlas
// This is the second pass of separable 2D Gaussian blur
// Use robust edge clamping to avoid sampling outside mip boundaries

vec3 sampleWithHorizontalBlur(ivec2 coord, int mipLevel, ivec2 mipSize, int xOffset)
{
    // Gaussian weights for 3-tap horizontal blur: [0.25, 0.5, 0.25]
    const float weightLeft = 0.25;
    const float weightCenter = 0.5;
    const float weightRight = 0.25;
    
    vec3 color = vec3(0.0);
    
    // Clamp X coordinates to valid range
    int x = coord.x;
    int xLeft = max(0, x - 1);
    int xRight = min(x + 1, mipSize.x - 1);
    
    // Sample left pixel
    color += texelFetch({{RT_BLOOM}}, xOffset + ivec2(xLeft, coord.y), 0).rgb * weightLeft;
    
    // Sample center pixel
    color += texelFetch({{RT_BLOOM}}, xOffset + coord, 0).rgb * weightCenter;
    
    // Sample right pixel
    color += texelFetch({{RT_BLOOM}}, xOffset + ivec2(xRight, coord.y), 0).rgb * weightRight;
    
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
    int xOffset = 0;
    int targetMipLevel = -1;
    ivec2 mipCoord = ivec2(0);
    ivec2 mipSize = ivec2(0);
    
    for (int i = 1; i < usableMipLevels; i++) {
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
        // Pixel is outside of any mip region
        return;
    }
    
    // Apply horizontal 3-pixel Gaussian blur with edge clamping
    vec3 color = sampleWithHorizontalBlur(mipCoord, targetMipLevel, mipSize, xOffset);
    
    // Ensure numerical stability
    color = max(color, vec3(0.0));
    
    imageStore({{IMG_BLOOM}}, pixelCoord, vec4(color, 1.0));
}
#endif
