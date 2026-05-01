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
const vec2 workGroupsRender = vec2(2.0, 1.0); // Width is 2x screen size to hold all mip levels

// Pack mipmaps from RT_BACK into RT_BLOOM as a texture atlas
// Layout: Each mip level is placed side by side horizontally
// Skip the smallest 2 mip levels (highest indices)
// Apply horizontal 3-pixel Gaussian blur during sampling

vec3 sampleWithHorizontalBlur(ivec2 coord, int mipLevel, ivec2 mipSize)
{
    // Gaussian weights for 3-tap horizontal blur: [0.25, 0.5, 0.25]
    const float weightLeft = 0.25;
    const float weightCenter = 0.5;
    const float weightRight = 0.25;
    
    vec3 color = vec3(0.0);
    
    // Sample left pixel
    if (coord.x - 1 >= 0) {
        color += texelFetch({{RT_BACK}}, ivec2(coord.x - 1, coord.y), mipLevel).rgb * weightLeft;
    } else {
        color += texelFetch({{RT_BACK}}, coord, mipLevel).rgb * weightLeft;
    }
    
    // Sample center pixel
    color += texelFetch({{RT_BACK}}, coord, mipLevel).rgb * weightCenter;
    
    // Sample right pixel
    if (coord.x + 1 < mipSize.x) {
        color += texelFetch({{RT_BACK}}, ivec2(coord.x + 1, coord.y), mipLevel).rgb * weightRight;
    } else {
        color += texelFetch({{RT_BACK}}, coord, mipLevel).rgb * weightRight;
    }
    
    return color;
}

void main()
{
    ivec2 pixelCoord = ivec2(gl_GlobalInvocationID.xy);
    
    int totalMipLevels = textureQueryLevels({{RT_BACK}});
    int usableMipLevels = totalMipLevels - 2; // Skip smallest 2 mips
    
    if (usableMipLevels <= 0) {
        return;
    }
    
    // Calculate which mip level this pixel belongs to
    // Mip levels are arranged horizontally: [mip0][mip1][mip2]...[mipN-2]
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
    
    // Sample with horizontal 3-pixel Gaussian blur
    vec3 color = sampleWithHorizontalBlur(mipCoord, targetMipLevel, mipSize);
    
    // Apply bloom threshold and knee to extract highlights
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
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
