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

// Reconstruct pyramid via upsampling: blend lower resolution mips back to higher resolution
// Each mip level is upsampled and blended into the next higher resolution mip
// Uses bilinear interpolation to smoothly reconstruct the pyramid

vec3 sampleBilinear(ivec2 coord, int mipLevel, int xOffset)
{
    // For now use simple texelFetch, could be improved with actual bilinear interpolation
    // if sampling non-integer coordinates
    return texelFetch({{RT_BLOOM}}, xOffset + coord, 0).rgb;
}

// Find which mip level a pixel belongs to and return the mip info
bool findMipLevel(ivec2 pixelCoord, out int mipLevel, out ivec2 mipCoord, out ivec2 mipSize, out int mipXOffset)
{
    int usableMipLevels = bloomMipCount;
    int xOffset = 0;
    
    for (int i = 1; i < usableMipLevels; i++) {
        mipSize = ivec2(viewWidth, viewHeight) >> i;
        if (pixelCoord.x >= xOffset && pixelCoord.x < xOffset + mipSize.x &&
            pixelCoord.y >= 0 && pixelCoord.y < mipSize.y) {
            mipLevel = i;
            mipCoord = pixelCoord - ivec2(xOffset, 0);
            mipXOffset = xOffset;
            return true;
        }
        xOffset += mipSize.x;
    }
    return false;
}

// Calculate the xOffset for a given mip level
int getMipXOffset(int mipLevel)
{
    int xOffset = 0;
    for (int i = 1; i < mipLevel; i++) {
        int mipWidth = int(viewWidth) >> i;
        xOffset += mipWidth;
    }
    return xOffset;
}

void main()
{
    ivec2 pixelCoord = ivec2(gl_GlobalInvocationID.xy);
    
    int bloomMips = bloomMipCount;
    if (bloomMips <= 1) {
        return;
    }
    
    // Find which mip this pixel belongs to
    int currentMip = -1;
    ivec2 mipCoord = ivec2(0);
    ivec2 mipSize = ivec2(0);
    int mipXOffset = 0;
    
    if (!findMipLevel(pixelCoord, currentMip, mipCoord, mipSize, mipXOffset)) {
        return;
    }
    
    // Read current mip value
    vec3 currentColor = texelFetch({{RT_BLOOM}}, pixelCoord, 0).rgb;
    
    // Blend in the contribution from the next lower resolution mip (if not the lowest)
    // Lower res mips are offset in the atlas, we need to find their position
    if (currentMip < bloomMips - 1) {
        // Calculate coordinates in the lower resolution mip
        int lowerMip = currentMip + 1;
        ivec2 lowerMipSize = ivec2(viewWidth, viewHeight) >> lowerMip;
        int lowerMipXOffset = getMipXOffset(lowerMip);
        
        // Map current mip coordinates to lower mip coordinates
        // Each pixel in lower mip corresponds to 2x2 pixels in higher mip
        ivec2 lowerCoord = mipCoord >> 1;
        
        // Fetch from lower resolution mip
        vec3 lowerColor = texelFetch({{RT_BLOOM}}, ivec2(lowerMipXOffset + lowerCoord.x, lowerCoord.y), 0).rgb;
        
        // Blend: keep most of current color, add some of lower mip
        // The blend factor increases for higher mip levels (lower resolution mips have more influence)
        float blendFactor = 0.25 * float(currentMip - 1); // Increases with mip level
        blendFactor = clamp(blendFactor, 0.0, 0.5);
        
        currentColor = mix(currentColor, lowerColor, blendFactor);
    }
    
    // Ensure numerical stability
    currentColor = max(currentColor, vec3(0.0));
    currentColor = clamp(currentColor, vec3(0.0), vec3(1e2));
    
    imageStore({{IMG_BLOOM}}, pixelCoord, vec4(currentColor, 1.0));
}
#endif
