// SHADER_COMP
#ifdef SHADER_COMP
#include "/lib/common.glsl"
#include "/lib/options.glsl"

uniform sampler2D noisetex;
uniform sampler2D colortex0;

uniform float viewWidth;
uniform float viewHeight;

layout(r11f_g11f_b10f) uniform writeonly image2D colorimg0;
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

const vec2 workGroupsRender = vec2(1.0, 1.0);

/* // Convert screen UV and mip level to Bloom Atlas UV
vec2 encodeBloomAtlasUV(vec2 uv, int mipLevel) {
    // Calculate the horizontal offset for this mip level in the atlas
    // Atlas layout: [mip1][mip2]...[mipN-2]
    float xOffset = 0.0;
    for (int i = 1; i < mipLevel; i++) {
        vec2 mipSize = vec2(viewWidth, viewHeight) / pow(2.0, float(i));
        xOffset += mipSize.x;
    }
    
    // Get current mip size
    vec2 mipSize = vec2(viewWidth, viewHeight) / pow(2.0, float(mipLevel));
    
    // Convert normalized UV to pixel coordinates within the mip
    vec2 pixelCoord = uv * mipSize;
    
    // Add the offset and convert back to normalized atlas UV
    // Note: We assume RT_BLOOM width is large enough (e.g., 2.0x screen width)
    vec2 atlasPixelCoord = vec2(xOffset + pixelCoord.x, pixelCoord.y);
    vec2 atlasSize = vec2(textureSize(colortex12, 0));
    
    return atlasPixelCoord / atlasSize;
}

// Decode Bloom Atlas UV to get the original mip level and local UV
// Returns: vec3(localUv.x, localUv.y, float(mipLevel))
vec3 decodeBloomAtlasUV(vec2 atlasUV) {
    vec2 atlasSize = vec2(textureSize(colortex12, 0));
    vec2 atlasPixelCoord = atlasUV * atlasSize;
    
    float currentX = 0.0;
    int foundMip = -1;
    vec2 localUV = vec2(0.0);
    
    int totalMips = textureQueryLevels(colortex0);
    
    for (int i = 1; i < totalMips - 1; i++) {
        vec2 mipSize = vec2(viewWidth, viewHeight) / pow(2.0, float(i));
        
        if (atlasPixelCoord.x >= currentX && atlasPixelCoord.x < currentX + mipSize.x &&
            atlasPixelCoord.y >= 0.0 && atlasPixelCoord.y < mipSize.y) {
            foundMip = i;
            localUV = (atlasPixelCoord - vec2(currentX, 0.0)) / mipSize;
            break;
        }
        currentX += mipSize.x;
    }
    
    return vec3(localUV, float(foundMip));
} */

void main()
{
    ivec2 pixelCoord = ivec2(gl_GlobalInvocationID.xy);
    ivec2 fullRes = ivec2(viewWidth, viewHeight);
    if (any(greaterThanEqual(pixelCoord, fullRes))) {
        return;
    }

    vec2 uv = (vec2(pixelCoord) + 0.5) / vec2(viewWidth, viewHeight);

    vec3 color = texelFetch(colortex0, pixelCoord, 0).rgb;
    
    float w = 4.0 / viewWidth;
    float h = 4.0 / viewHeight;

    float intensity = 1.0;

    vec2 dither = (texture(noisetex, uv * vec2(viewWidth, viewHeight) / 128.0).rg - 0.5) * 0.005;
    
    vec3 bloomSum = vec3(0);

    int mips = textureQueryLevels(colortex0);
    for(int i = 2; i < mips - 1; i++)
    {
        vec3 bloom = vec3(0);

        bloom += textureLod(colortex0, uv + dither + vec2(-w, h), i).rgb * 0.1;
        bloom += textureLod(colortex0, uv + dither + vec2(0, h), i).rgb * 0.2;
        bloom += textureLod(colortex0, uv + dither + vec2(w, h), i).rgb * 0.1;

        bloom += textureLod(colortex0, uv + dither + vec2(-w, 0), i).rgb * 0.2;
        bloom += textureLod(colortex0, uv + dither + vec2(0, 0), i).rgb * 0.2;
        bloom += textureLod(colortex0, uv + dither + vec2(w, 0), i).rgb * 0.2;

        bloom += textureLod(colortex0, uv + dither + vec2(-w, -h), i).rgb * 0.1;
        bloom += textureLod(colortex0, uv + dither + vec2(0, -h), i).rgb * 0.2;
        bloom += textureLod(colortex0, uv + dither + vec2(w, -h), i).rgb * 0.1;

        bloomSum += bloom * intensity;

        w *= 2.0;
        h *= 2.0;
        dither *= 2.0;
        intensity *= 0.97;
    }

    bloomSum /= float(mips - 3);

    vec3 finalColor = mix(color, bloomSum, 0.2);

    imageStore(colorimg0, pixelCoord, vec4(finalColor, 1.0));
}
#endif
