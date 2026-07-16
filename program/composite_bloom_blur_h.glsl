// ============================================================================
// composite_bloom_blur_h  —  全屏四边形水平高斯模糊（FS，利用 Iris buffer flip）
// ============================================================================

// {{SHADER_FRAG}}
#ifdef {{SHADER_FRAG}}
#include "/lib/common.glsl"
#include "/lib/options.glsl"

uniform sampler2D {{RT_BLOOM}};
uniform float viewWidth;
uniform float viewHeight;

/* RENDERTARGETS: {RT_BLOOM} */
layout(location = 0) out vec4 outColor;

// 9-tap 高斯权重，σ ≈ 1.0
const float gaussianWeights[5] = float[](
    0.227027, 0.194594, 0.121621, 0.054054, 0.016216
);

const int MAX_MIPS = 16;

void main()
{
    ivec2 atlasCoord = ivec2(gl_FragCoord.xy);
    ivec2 atlasSize  = textureSize({{RT_BLOOM}}, 0);

    // 越界像素输出黑色（viewPort 可能略大于图集）
    if (any(greaterThanEqual(atlasCoord, atlasSize))) {
        outColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // ── 预计算所有 mip AABB ──────────────────────────────────
    float scaleX = float(atlasSize.x) / (viewWidth  * 1.505);
    float scaleY = float(atlasSize.y) / (viewHeight * 1.02);
    int vw = int(viewWidth), vh = int(viewHeight);
    int maxMips = findMSB(int(max(viewWidth, viewHeight))) + 1;

    int mipXMin[MAX_MIPS], mipXMax[MAX_MIPS];
    int mipYMin[MAX_MIPS], mipYMax[MAX_MIPS];
    int mipCount = 0;

    mipXMin[0] = 0;
    mipXMax[0] = int((float(vw) + 2.0) * scaleX + 0.5);
    mipYMin[0] = 0;
    mipYMax[0] = int((float(vh) + 2.0) * scaleY + 0.5);
    mipCount = 1;

    float desiredY = 0.0;
    for (int m = 1; m < maxMips; m++) {
        int mw = max(vw >> m, 1), mh = max(vh >> m, 1);
        if (min(mw, mh) < 4) break;
        float dxMin = float(vw) + 2.0;
        mipXMin[m] = int(dxMin * scaleX + 0.5);
        mipXMax[m] = int((dxMin + float(mw) + 2.0) * scaleX + 0.5);
        mipYMin[m] = int(desiredY * scaleY + 0.5);
        mipYMax[m] = int((desiredY + float(mh) + 2.0) * scaleY + 0.5);
        desiredY += float(mh) + 2.0;
        mipCount = m + 1;
    }

    // ── 查找当前像素属于哪个 mip ─────────────────────────────
    int foundMip = -1;
    for (int m = 0; m < mipCount; m++) {
        if (atlasCoord.x >= mipXMin[m] && atlasCoord.x < mipXMax[m]
            && atlasCoord.y >= mipYMin[m] && atlasCoord.y < mipYMax[m]) {
            foundMip = m; break;
        }
    }
    if (foundMip < 0) { outColor = vec4(0.0, 0.0, 0.0, 1.0); return; }

    int xMin = mipXMin[foundMip], xMax = mipXMax[foundMip];
    int yMin = mipYMin[foundMip], yMax = mipYMax[foundMip];

    // ── 水平高斯模糊（texelFetch，双轴 clamp）─────────────────
    vec3 color = texelFetch({{RT_BLOOM}}, atlasCoord, 0).rgb * gaussianWeights[0];

    for (int i = 1; i < 5; i++) {
        int leftX  = clamp(atlasCoord.x - i, xMin, xMax - 1);
        int rightX = clamp(atlasCoord.x + i, xMin, xMax - 1);
        int sampY  = clamp(atlasCoord.y,     yMin, yMax - 1);
        color += texelFetch({{RT_BLOOM}}, ivec2(leftX,  sampY), 0).rgb * gaussianWeights[i];
        color += texelFetch({{RT_BLOOM}}, ivec2(rightX, sampY), 0).rgb * gaussianWeights[i];
    }

    outColor = vec4(color, 1.0);
}
#endif

// {{SHADER_VERT}}
#ifdef {{SHADER_VERT}}
out vec2 texcoord;

void main()
{
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
#endif
