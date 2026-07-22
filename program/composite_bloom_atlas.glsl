// ============================================================================
// composite_bloom_atlas  —  将 mipmap 链打包到图集纹理中
// ============================================================================
//
// 图集布局（书架式 / Shelf Layout，mip0 与 mip1 四边形相邻不重叠）：
//   ┌──────────────────────┬┬──────────────┐
//   │                      ││   mip1       │  ← y=0
//   │       mip0           ││  (vw/2×vh/2) │
//   │     (vw × vh)        │├──────────────┤
//   │                      ││   mip2       │  ← y=vh/2+3
//   │                      ││  (vw/4×vh/4) │
//   │                      │├──────────────┤
//   │                      ││ mip3 │ mip4..│  ← 继续向下堆叠
//   └──────────────────────┴┴──────────────┘
//   x=0                 x=vw+1           x=vw+3
//
//   mip0 quad: [0, vw+2), content [1, vw+1), 右出血 x=vw+1
//   mip1 quad: [vw+2, ...), content [vw+3, ...), 左出血 x=vw+2
//
//   图集尺寸：≈ 1.505×viewWidth × 1.02×viewHeight
//
//   每个 mip 四周有 1px 出血边，防止双线性采样时跨 mip 出血。
//   mip0 与 mip1 出血边相邻（x=vw+1 和 x=vw+2）但不重叠。
//
//   管线阶段：
//     VS → 全屏三角形 → GS → 为每个 mip 发射带出血边的四边形 → FS → texelFetch 拷贝
// ============================================================================

// {{SHADER_VERT}}
#ifdef {{SHADER_VERT}}
#include "/lib/options.glsl"

uniform float viewWidth;
uniform float viewHeight;

out vec2 baseUV;

void main()
{
    // 向几何着色器传递一个覆盖全屏的三角形
    // 顶点顺序：左下 → 右下 → 左上
    int vertexID = gl_VertexID;
    baseUV = vec2(
        (vertexID == 1) ? 2.0 : 0.0,
        (vertexID == 2) ? 2.0 : 0.0
    );
    gl_Position = vec4(baseUV * 2.0 - 1.0, 0.0, 1.0);
}
#endif

// {{SHADER_GEOM}}
#ifdef {{SHADER_GEOM}}
#include "/lib/options.glsl"

layout(triangles) in;
layout(triangle_strip, max_vertices = 40) out;

uniform float viewWidth;
uniform float viewHeight;

out vec2 sampleUV;          // 从源 mip 采样的 UV，∈ [0,1] 覆盖整个四边形（含边框）
flat out int mipLevel;      // 当前 mip 层级

void main()
{
    // ── 图集尺寸 ─────────────────────────────────────────────
    // RT_BLOOM 相对尺寸为 1.505×1.02（含 2px mip 间隙）
    float atlasW = viewWidth * 1.505;
    float atlasH = viewHeight * 1.02;

    // 右侧列起始 x：mip0 quad 右边界 = vw+2（不含），加 1px 死空间后从 vw+3 开始
    // mip0 quad: [0, vw+2), content: [1, vw+1)
    // right-column quad: [vw+3-1, ...) = [vw+2, ...), content: [vw+3, ...)
    float rightColumnX = viewWidth + 3.0;

    // ── 计算 mip 数量 ────────────────────────────────────────
    int maxMips = findMSB(int(max(viewWidth, viewHeight))) + 1;

    // ── 逐 mip 发射四边形 ────────────────────────────────────
    // 四边形 = 内容 + 四周各 1px 边框。UV 保持 [0,1] 覆盖整个四边形。
    // 片段着色器将 [1/mw, 1-1/mw] 映射回 [0,1]，边框部分 clamp 到边缘。
    // 效果：每个 mip 的边界像素向外复制一份，防止合成时双线性过滤出血。
    float xOffset = 1.0;    // mip0 内容起始 x（1px 左边框）
    float yOffset = 1.0;    // mip0 内容起始 y（1px 上边框）

    for (int mip = 0; mip < maxMips; mip++)
    {
        if (mip >= maxMips) break;

        // 当前 mip 的内容尺寸（不含边框）
        int mw = (mip == 0) ? int(viewWidth)  : max(int(viewWidth)  >> mip, 1);
        int mh = (mip == 0) ? int(viewHeight) : max(int(viewHeight) >> mip, 1);

        // 过小的 mip 无意义，停止
        if (min(mw, mh) < 4) break;

        mipLevel = mip;

        if (mip == 1)
        {
            // 切换到右侧列：x=vw+2，y 回到顶部
            xOffset = rightColumnX;
            yOffset = 1.0;
        }
        else if (mip > 1)
        {
            // 右侧列继续向下堆叠，xOffset 不变，yOffset 已在上次迭代末尾更新
            xOffset = rightColumnX;
        }
        // mip == 0：xOffset=1.0, yOffset=1.0（已在初始化时设置）

        // ── 四边形 clip-space 位置 ────────────────────────────
        // 四边形 = 内容 + 四周各 1px 边框
        // 四边形 x ∈ [xOff-1, xOff+mw+1)，y ∈ [yOff-1, yOff+mh+1)
        float padPx = 1.0;
        float l = ((xOffset - padPx) / atlasW) * 2.0 - 1.0;
        float r = ((xOffset + float(mw) + padPx) / atlasW) * 2.0 - 1.0;
        float b = ((yOffset - padPx) / atlasH) * 2.0 - 1.0;
        float t = ((yOffset + float(mh) + padPx) / atlasH) * 2.0 - 1.0;

        // ── 采样 UV：填充整个四边形 [0,1]，片段着色器负责向内收缩 ──
        // 四边形 = 内容 + 四周各 1px 边框，但 UV 保持 [0,1]
        // 片段着色器将 [1/mw, 1-1/mw] 映射到 [0,1]，边框部分 clamp 到边缘

        // ── 三角形条带四边形：BL → BR → TL → TR ──────────────
        sampleUV = vec2(0.0, 0.0);
        gl_Position = vec4(l, b, 0.0, 1.0); EmitVertex();
        sampleUV = vec2(1.0, 0.0);
        gl_Position = vec4(r, b, 0.0, 1.0); EmitVertex();
        sampleUV = vec2(0.0, 1.0);
        gl_Position = vec4(l, t, 0.0, 1.0); EmitVertex();
        sampleUV = vec2(1.0, 1.0);
        gl_Position = vec4(r, t, 0.0, 1.0); EmitVertex();

        EndPrimitive();

        // ── 更新下一 mip 的偏移量 ─────────────────────────────
        if (mip == 0)
        {
            // mip0 之后切换到右侧列
            xOffset = rightColumnX;
            yOffset = 1.0;
        }
        else
        {
            // 右侧列：四边形总高 = mh + 2（上下各 1px 边框）
            // 下一 mip 的 yOffset += mh + 2（四边形高度）
            yOffset += float(mh) + 2.0;
        }
    }
}
#endif

// {{SHADER_FRAG}}
#ifdef {{SHADER_FRAG}}
#include "/lib/common.glsl"
#include "/lib/options.glsl"
#include "/lib/color.glsl"

uniform sampler2D {{RT_BACK}};
uniform float viewWidth;
uniform float viewHeight;

/* RENDERTARGETS: {RT_BLOOM} */
layout(location = 0) out vec4 outColor;

in vec2 sampleUV;
flat in int mipLevel;

void main()
{
    // ── 计算当前 mip 的内容尺寸 ──────────────────────────────
    int mw = (mipLevel == 0) ? int(viewWidth)  : max(int(viewWidth)  >> mipLevel, 1);
    int mh = (mipLevel == 0) ? int(viewHeight) : max(int(viewHeight) >> mipLevel, 1);

    // ── 将四边形 UV 映射到内容像素坐标，clamp 实现边缘出血 ────
    // 四边形 = 内容 + 四周各 1px 出血边，尺寸为 (mw+2) × (mh+2)
    // sampleUV ∈ [0,1] 覆盖整个四边形
    // 内容像素在四边形中的局部索引 ∈ [1, mw]，出血边索引为 0 和 mw+1
    // contentCoord = floor(sampleUV * quadSize) - 1，clamp 到 [0, mw-1]
    ivec2 contentCoord = ivec2(sampleUV * vec2(float(mw + 2), float(mh + 2))) - ivec2(1);
    contentCoord = clamp(contentCoord, ivec2(0), ivec2(mw - 1, mh - 1));

    // ── texelFetch 采样源纹理 ─────────────────────────────────
    vec4 color = texelFetch({{RT_BACK}}, contentCoord, mipLevel);

    // ── 阈值过滤：仅保留亮部用于 bloom ───────────────────────
    float brightness = getBrightness(color.rgb);
    float t = BLOOM_THRESHOLD;
    float k = max(BLOOM_KNEE, 0.001);
    float weight = smoothstep(t - k, t + k, brightness) * (1.0 - BLOOM_MIN) + BLOOM_MIN;
    color.rgb *= weight;
    brightness = getBrightness(color.rgb);
    //color.rgb *= sqrt(brightness);

    // ── 分辨率自适应的 mip 强度（相同像素尺寸 → 相同强度）─────
    //float intensity = sqrt(float(mw) * float(mh)) / 63106.0 / (mipLevel + 0.01) + 1.0 ;
    //color.rgb *= intensity;

    outColor = vec4(color.rgb, 1.0);
}
#endif
