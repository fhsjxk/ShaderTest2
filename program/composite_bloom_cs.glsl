// ============================================================================
// composite_bloom  —  从图集双线性采样所有 mip 并合成到场景颜色
// ============================================================================
//
// 对每个屏幕像素：
//   1. 读取原始场景颜色（RT_BACK mip 0）
//   2. 从 bloom 图集（RT_BLOOM，书架布局）双线性采样所有 mip 级别（含 mip0）
//   3. 使用抖动噪声减少色带
//   4. 将 bloom 叠加到原始颜色，写回 RT_BACK
//
// UV 计算对应出血前的内容区（比图集实际像素范围小一圈），
// 出血像素仅由双线性过滤在内容边界处自然触及，防止跨 mip 出血。
//
// 图集布局（书架式，含 1px 出血边，mip0 与 mip1 四边形相邻不重叠）：
//   ┌─ 出血 ┬──────────────────────┬─ 出血 ┬ 出血 ┬──────────────┐
//   │        │                      │ (mip0) │(mip1)│   mip1       │  ← y=0 (出血)
//   │        │       mip0           │        │       │  (vw/2×vh/2) │  ← y=1
//   │        │     (vw × vh)        │        │       ├──────────────┤
//   │        │                      │        │       │   mip2       │  ← 继续向下
//   └────────┴──────────────────────┴────────┴───────┴──────────────┘
//   x=0      x=1               x=vw+1  x=vw+2  x=vw+3       x=vw+3+mw
//
//   mip0 内容区：x ∈ [1, vw+1)，右出血 x=vw+1
//   mip1+ 内容区：x ∈ [vw+3, vw+3+mw)，左出血 x=vw+2
//   出血像素位于每个 mip 内容区外围 1px，相邻 mip 出血边紧挨但不重叠
// ============================================================================

// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/common.glsl"
#include "/lib/options.glsl"

uniform sampler2D noisetex;
uniform sampler2D {{RT_BACK}};
uniform sampler2D {{RT_BLOOM}};

uniform float viewWidth;
uniform float viewHeight;

layout({{IMG_BACK_FORMAT}}) uniform writeonly image2D {{IMG_BACK}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

const vec2 workGroupsRender = vec2(1.0, 1.0);

void main()
{
    ivec2 pixelCoord = ivec2(gl_GlobalInvocationID.xy);
    ivec2 fullRes    = ivec2(viewWidth, viewHeight);

    if (any(greaterThanEqual(pixelCoord, fullRes)))
    {
        return;
    }

    // ── 读取原始场景颜色 ─────────────────────────────────────
    vec3 color = texelFetch({{RT_BACK}}, pixelCoord, 0).rgb;

    // ── 确定可用的 mip 数量 ──────────────────────────────────
    int totalMipLevels = textureQueryLevels({{RT_BACK}});

    if (totalMipLevels <= 1)
    {
        imageStore({{IMG_BACK}}, pixelCoord, vec4(color, 1.0));
        return;
    }

    // ── 图集参数 ─────────────────────────────────────────────
    vec2 atlasSize = vec2(textureSize({{RT_BLOOM}}, 0));
    int vw = int(viewWidth);
    int vh = int(viewHeight);
    int rightColumnX = vw + 3;      // mip1+ 内容区起始 x（mip0 quad 右边界 vw+2 + 1px 死空间）
    int maxMips = findMSB(int(max(viewWidth, viewHeight))) + 1;

    // ── 抖动偏移 ─────────────────────────────────────────────
    vec2 noiseUv = vec2(pixelCoord) / 128.0;
    vec2 ditherPixels = (texture(noisetex, noiseUv).rg - 0.5);
    vec2 ditherUv = ditherPixels / atlasSize;

    // ── 类双三次上采样：每 mip 取 4 点 offset，平滑 bloom ────
    vec3 bloomAccum = vec3(0.0);

    // mip0：内容区 x∈[1, vw+1)，y∈[1, vh+1)
    {
        vec2 mipPos = (vec2(pixelCoord) + 0.5) / vec2(viewWidth, viewHeight) * vec2(float(vw), float(vh));
        vec2 baseUV = (vec2(1.0, 1.0) + mipPos) / atlasSize;
        vec3 s = vec3(0.0);
        s += texture({{RT_BLOOM}}, baseUV + vec2(-0.25, -0.25) / atlasSize + ditherUv).rgb;
        s += texture({{RT_BLOOM}}, baseUV + vec2( 0.25, -0.25) / atlasSize + ditherUv).rgb;
        s += texture({{RT_BLOOM}}, baseUV + vec2(-0.25,  0.25) / atlasSize + ditherUv).rgb;
        s += texture({{RT_BLOOM}}, baseUV + vec2( 0.25,  0.25) / atlasSize + ditherUv).rgb;
        bloomAccum += s * 0.25;
    }

    // mip1+：内容区 x∈[rightColumnX, rightColumnX+mw)，y 逐 mip 下移
    int yOff = 1;
    int actualMips = 1; // mip0
    for (int mip = 1; mip < maxMips; mip++)
    {
        int mw = max(vw >> mip, 1);
        int mh = max(vh >> mip, 1);
        if (min(mw, mh) < 4) break;

        vec2 mipPos = (vec2(pixelCoord) + 0.5) / vec2(viewWidth, viewHeight) * vec2(float(mw), float(mh));
        vec2 baseUV = (vec2(float(rightColumnX), float(yOff)) + mipPos) / atlasSize;

        vec3 s = vec3(0.0);
        s += texture({{RT_BLOOM}}, baseUV + vec2(-0.25, -0.25) / atlasSize + ditherUv).rgb;
        s += texture({{RT_BLOOM}}, baseUV + vec2( 0.25, -0.25) / atlasSize + ditherUv).rgb;
        s += texture({{RT_BLOOM}}, baseUV + vec2(-0.25,  0.25) / atlasSize + ditherUv).rgb;
        s += texture({{RT_BLOOM}}, baseUV + vec2( 0.25,  0.25) / atlasSize + ditherUv).rgb;
        bloomAccum += s * 0.25;
        actualMips++;

        yOff += mh + 2;
    }

    // ── 归一化并应用 bloom 强度 ──────────────────────────────
    //float bloomWeight = 1.0 / max(float(actualMips), 1.0) / BLOOM_THRESHOLD;
    float bloomWeight = BLOOM_THRESHOLD / max(float(actualMips), 1.0);
    vec3 bloomContrib = bloomAccum * bloomWeight;
    bloomContrib = max(bloomContrib, vec3(0.0));

    // ── 叠加 bloom（加法混合）─────────────────────────────────
    vec3 finalColor = color + bloomContrib;

    imageStore({{IMG_BACK}}, pixelCoord, vec4(finalColor, 1.0));
}
#endif
