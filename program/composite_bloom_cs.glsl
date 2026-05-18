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

void main()
{
    ivec2 pixelCoord = ivec2(gl_GlobalInvocationID.xy);
    ivec2 fullRes = ivec2(viewWidth, viewHeight);
    if (any(greaterThanEqual(pixelCoord, fullRes))) {
        return;
    }

    vec2 uv = (vec2(pixelCoord) + 0.5) / vec2(viewWidth, viewHeight);
    
    // Sample base color
    vec3 baseColor = texelFetch(colortex0, pixelCoord, 0).rgb;
    
    // Dither to reduce banding artifacts
    vec2 dither = (texture(noisetex, uv * vec2(viewWidth, viewHeight) / 128.0).rg - 0.5) * BLOOM_DITHER * 0.001;
    
    // Multi-scale bloom sampling from mipmap pyramid
    vec3 bloomSum = vec3(0.0);
    float totalWeight = 0.0;
    
    int mips = textureQueryLevels(colortex0);
    
    // Start from mip 2 (skip full resolution), stop before last 2 mips (too small)
    for(int i = 2; i < mips - 1; i++)
    {
        // Sample bloom with offset dither
        vec3 bloom = vec3(0.0);
        
        float w = 4.0 / viewWidth;
        float h = 4.0 / viewHeight;
        
        // 3x3 tap sampling for better quality
        bloom += textureLod(colortex0, uv + dither + vec2(-w, h), i).rgb * 0.1;
        bloom += textureLod(colortex0, uv + dither + vec2(0, h), i).rgb * 0.2;
        bloom += textureLod(colortex0, uv + dither + vec2(w, h), i).rgb * 0.1;
        
        bloom += textureLod(colortex0, uv + dither + vec2(-w, 0), i).rgb * 0.2;
        bloom += textureLod(colortex0, uv + dither + vec2(0, 0), i).rgb * 0.2;
        bloom += textureLod(colortex0, uv + dither + vec2(w, 0), i).rgb * 0.2;
        
        bloom += textureLod(colortex0, uv + dither + vec2(-w, -h), i).rgb * 0.1;
        bloom += textureLod(colortex0, uv + dither + vec2(0, -h), i).rgb * 0.2;
        bloom += textureLod(colortex0, uv + dither + vec2(w, -h), i).rgb * 0.1;
        
        // Weight decreases with mip level (higher mips contribute less)
        float weight = pow(0.97, float(i - 1));
        bloomSum += bloom * weight;
        totalWeight += weight;
    }
    
    // Normalize by total weight and mip count
    if (totalWeight > 1e-5) {
        bloomSum /= totalWeight;
    }
    
    // Apply bloom strength with smooth blending
    float bloomIntensity = BLOOM_STRENGTH;
    vec3 finalColor = mix(baseColor, bloomSum, bloomIntensity);
    
    // Clamp to prevent excessive blooming
    finalColor = max(finalColor, vec3(0.0));
    
    imageStore(colorimg0, pixelCoord, vec4(finalColor, 1.0));
}
#endif

