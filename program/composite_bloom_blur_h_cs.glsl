// ============================================================================
// composite_bloom_blur_h  —  对图集中的每个 mip 执行水平高斯模糊
// ============================================================================
//
// 此 compute shader 在图集生成之后、垂直模糊之前运行。
// 对图集中每个 mip（mip0 除外，它保持锐利）进行水平方向的高斯模糊。
//
// 使用 texelFetch 采样，clamp 在 mip 四边形边界内，防止采样到相邻 mip。
//
// 图集布局参见 composite_bloom_atlas.glsl。
// ============================================================================

// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/common.glsl"
#include "/lib/options.glsl"

uniform sampler2D {{RT_BLOOM}};
uniform float viewWidth;
uniform float viewHeight;

layout({{RT_BLOOM_FORMAT_IMG}}) uniform writeonly image2D {{RT_BLOOM_IMG}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
// atlas 覆盖整个图集：宽度 ≈ vw * 1.505，高度 ≈ vh * 1.02
const vec2 workGroupsRender = vec2(1.505, 1.02);

// ── 9-tap 高斯权重，σ ≈ 1.0 ──────────────────────────────────
const float gaussianWeights[5] = float[](
    0.227027, 0.194594, 0.121621, 0.054054, 0.016216
);

void main()
{
    ivec2 atlasCoord = ivec2(gl_GlobalInvocationID.xy);

    // ── 图集尺寸 ─────────────────────────────────────────────
    int atlasWidth  = int(viewWidth * 1.505);
    int atlasHeight = int(viewHeight * 1.02);

    // 越界检查
    if (any(greaterThanEqual(atlasCoord, ivec2(atlasWidth, atlasHeight))))
    {
        return;
    }

    // ── 确定当前像素属于哪个 mip ─────────────────────────────
    int vw = int(viewWidth);
    int vh = int(viewHeight);

    // mip0 四边形占据左侧 x ∈ [0, vw+2)，右侧列四边形从 rightColumnX-1 开始
    int rightColumnX = vw + 3;

    int mipLevel = -1;
    int quadXMin = 0, quadXMax = 0;   // 四边形 x 范围 [min, max)
    int quadYMin = 0, quadYMax = 0;   // 四边形 y 范围 [min, max)

    // 优先检查右侧列（处理与 mip0 的重叠像素）
    if (atlasCoord.x >= rightColumnX - 1)
    {
        int yCursor = 1;   // mip1 四边形从 y=1 开始
        int maxMips = findMSB(int(max(viewWidth, viewHeight))) + 1;

        for (int mip = 1; mip < maxMips; mip++)
        {
            int mwMip = max(vw >> mip, 1);
            int mhMip = max(vh >> mip, 1);

            if (min(mwMip, mhMip) < 4) break;

            // 四边形 y 范围：[yCursor, yCursor + mhMip + 2)
            if (atlasCoord.y >= yCursor && atlasCoord.y < yCursor + mhMip + 2)
            {
                mipLevel = mip;
                quadXMin = rightColumnX - 1;
                quadXMax = rightColumnX - 1 + mwMip + 2;
                quadYMin = yCursor;
                quadYMax = yCursor + mhMip + 2;
                break;
            }

            yCursor += mhMip + 2;
        }
    }
    // mip0 跳过水平模糊
    // (atlasCoord 在 mip0 四边形内时不处理)

    // 不在任何需要模糊的 mip 内
    if (mipLevel <= 0)
    {
        return;
    }

    // ── 水平高斯模糊（texelFetch，clamp 在四边形边界内）──────
    vec3 color = texelFetch({{RT_BLOOM}}, atlasCoord, 0).rgb * gaussianWeights[0];

    for (int i = 1; i < 5; i++)
    {
        int leftX  = clamp(atlasCoord.x - i, quadXMin, quadXMax - 1);
        int rightX = clamp(atlasCoord.x + i, quadXMin, quadXMax - 1);
        color += texelFetch({{RT_BLOOM}}, ivec2(leftX,  atlasCoord.y), 0).rgb * gaussianWeights[i];
        color += texelFetch({{RT_BLOOM}}, ivec2(rightX, atlasCoord.y), 0).rgb * gaussianWeights[i];
    }

    // 写回图集
    imageStore({{RT_BLOOM_IMG}}, atlasCoord, vec4(color, 1.0));
}
#endif
