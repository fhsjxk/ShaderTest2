#ifndef TONEMAP
#define TONEMAP

// -----------------------------------------------------------------------------
// GT7 Tone Mapping（GLSL 移植版）
//
// 移植自 Polyphony Digital Inc. 的 C++ 示例实现（MIT License）。
// 该着色器实现了 Gran Turismo 7 的色调映射算子：
//   - 使用统一的感知均匀色彩空间（UCS：ICtCp 或 Jzazbz）分离亮度与色度
//   - 逐通道（带"偏斜"）亮度曲线 + 肩部收敛
//   - 通过色度滚动（chroma roll-off）在高光处衰减色度
//   - 支持 HDR 目标显示峰值亮度（250 ~ 10000 nit）与 SDR（250 nit 纸白）两种模式
//
// 用法（简便入口）：
//     vec3 mapped = gt7ToneMap(inputRec2020, targetNits, paperWhiteNits, isHDR);
//
// 其中：
//   - inputRec2020  : 线性 Rec.2020 帧缓冲值
//   - targetNits    : HDR 目标显示峰值亮度（cd/m^2），SDR 模式时忽略
//   - paperWhiteNits: HDR 模式下的参考纸白亮度（用于缩放输入），SDR 模式时忽略
//   - isHDR         : 是否 HDR 输出
//
// 输出：
//   - SDR 模式 : 映射到 [0, 1]，可直接应用 sRGB OETF
//   - HDR 模式 : 映射到 [0, framebufferLuminanceTarget]，可直接应用 PQ 逆 EOTF
// -----------------------------------------------------------------------------

// 选择 UCS 色彩空间：0 = ICtCp，1 = Jzazbz
#define TONE_MAPPING_UCS_ICTCP  0
#define TONE_MAPPING_UCS_JZAZBZ 1
#define TONE_MAPPING_UCS        TONE_MAPPING_UCS_ICTCP

// 用于色调映射的 SDR 参考纸白（通常为 250 nit）
#define GRAN_TURISMO_SDR_PAPER_WHITE 250.0 // cd/m^2

// 帧缓冲空间 1.0 对应的物理亮度（通常为 100 cd/m^2）
#define REFERENCE_LUMINANCE 250.0 // cd/m^2 <-> 1.0

// -----------------------------------------------------------------------------
// 亮度换算辅助函数
// -----------------------------------------------------------------------------
// 将线性帧缓冲值转换为物理亮度（cd/m^2），其中 1.0 对应 REFERENCE_LUMINANCE
float frameBufferValueToPhysicalValue(float fbValue)
{
    return fbValue * REFERENCE_LUMINANCE;
}

// 将物理亮度（cd/m^2）转换为线性帧缓冲值，其中 1.0 对应 REFERENCE_LUMINANCE
float physicalValueToFrameBufferValue(float physical)
{
    return physical / REFERENCE_LUMINANCE;
}

// -----------------------------------------------------------------------------
// 工具函数
// -----------------------------------------------------------------------------
// 色度滚动曲线，x 越接近 [a, b] 区间亮度，色度保留比例越低
float chromaCurve(float x, float a, float b)
{
    return 1.0 - smoothstep(a, b, x);
}

// -----------------------------------------------------------------------------
// "GT Tone Mapping" 肩部收敛曲线
// -----------------------------------------------------------------------------
struct GTToneMappingCurveV2
{
    float peakIntensity;
    float alpha;
    float midPoint;
    float linearSection;
    float toeStrength;
    float kA;
    float kB;
    float kC;
};

GTToneMappingCurveV2 gtToneMappingCurveInitialize(
    float monitorIntensity, float alpha, float grayPoint, float linearSection, float toeStrength)
{
    GTToneMappingCurveV2 c;
    c.peakIntensity = monitorIntensity;
    c.alpha         = alpha;
    c.midPoint      = grayPoint;
    c.linearSection = linearSection;
    c.toeStrength   = toeStrength;

    // 预计算肩部区域常量
    float k = (linearSection - 1.0) / (alpha - 1.0);
    c.kA = c.peakIntensity * linearSection + c.peakIntensity * k;
    c.kB = -c.peakIntensity * k * exp(linearSection / k);
    c.kC = -1.0 / (k * c.peakIntensity);

    return c;
}

float gtToneMappingCurveEvaluate(GTToneMappingCurveV2 c, float x)
{
    if (x < 0.0)
    {
        return 0.0;
    }

    float weightLinear = smoothstep(0.0, c.midPoint, x);
    float weightToe    = 1.0 - weightLinear;

    // 高光肩部映射
    float shoulder = c.kA + c.kB * exp(x * c.kC);

    if (x < c.linearSection * c.peakIntensity)
    {
        float toeMapped = c.midPoint * pow(x / c.midPoint, c.toeStrength);
        return weightToe * toeMapped + weightLinear * x;
    }
    else
    {
        return shoulder;
    }
}

// -----------------------------------------------------------------------------
// ST-2084（PQ）EOTF / 逆 EOTF
// 注：引入 exponentScaleFactor 以允许在 Jzazbz 中缩放指数
// -----------------------------------------------------------------------------
// PQ EOTF：将归一化 PQ (0-1) 转换为物理亮度（cd/m^2，线性光），再换算回帧缓冲线性尺度
float eotfSt2084(float n, float exponentScaleFactor)
{
    n = clamp(n, 0.0, 1.0);

    // SMPTE ST 2084:2014 基础系数（假设全量程 0-1）
    const float m1  = 0.1593017578125;                // (2610 / 4096) / 4
    const float m2  = 78.84375 * exponentScaleFactor; // (2523 / 4096) * 128
    const float c1  = 0.8359375;                      // 3424 / 4096
    const float c2  = 18.8515625;                     // (2413 / 4096) * 32
    const float c3  = 18.6875;                        // (2392 / 4096) * 32
    const float pqC = 10000.0;                        // PQ 支持的最大亮度（cd/m^2）

    float np = pow(n, 1.0 / m2);
    float l  = np - c1;
    l = max(l, 0.0);
    l = l / (c2 - c3 * np);
    l = pow(l, 1.0 / m1);

    // 将绝对亮度（cd/m^2）转换到帧缓冲线性尺度
    return physicalValueToFrameBufferValue(l * pqC);
}

// PQ 逆 EOTF：将（帧缓冲线性尺度的）亮度转换为归一化 PQ 值
float inverseEotfSt2084(float v, float exponentScaleFactor)
{
    const float m1  = 0.1593017578125;
    const float m2  = 78.84375 * exponentScaleFactor;
    const float c1  = 0.8359375;
    const float c2  = 18.8515625;
    const float c3  = 18.6875;
    const float pqC = 10000.0;

    // 将帧缓冲线性尺度转换为绝对亮度（cd/m^2）
    float physical = frameBufferValueToPhysicalValue(v);
    float y        = physical / pqC; // 归一化到 ST-2084 曲线

    float ym = pow(y, m1);
    return exp2(m2 * (log2(c1 + c2 * ym) - log2(1.0 + c3 * ym)));
}

// -----------------------------------------------------------------------------
// ICtCp 转换（输入/输出：线性 Rec.2020）
// 参考：ITU-R BT.2100 / ICtCp
// -----------------------------------------------------------------------------
vec3 rgbToICtCp(vec3 rgb)
{
    float l = (rgb.r * 1688.0 + rgb.g * 2146.0 + rgb.b * 262.0) / 4096.0;
    float m = (rgb.r * 683.0  + rgb.g * 2951.0 + rgb.b * 462.0) / 4096.0;
    float s = (rgb.r * 99.0   + rgb.g * 309.0  + rgb.b * 3688.0) / 4096.0;

    float lPQ = inverseEotfSt2084(l, 1.0);
    float mPQ = inverseEotfSt2084(m, 1.0);
    float sPQ = inverseEotfSt2084(s, 1.0);

    return vec3(
        (2048.0 * lPQ + 2048.0 * mPQ) / 4096.0,
        (6610.0 * lPQ - 13613.0 * mPQ + 7003.0 * sPQ) / 4096.0,
        (17933.0 * lPQ - 17390.0 * mPQ - 543.0 * sPQ) / 4096.0);
}

vec3 iCtCpToRgb(vec3 ictCp)
{
    float l = ictCp.x + 0.00860904 * ictCp.y + 0.11103 * ictCp.z;
    float m = ictCp.x - 0.00860904 * ictCp.y - 0.11103 * ictCp.z;
    float s = ictCp.x + 0.560031 * ictCp.y - 0.320627 * ictCp.z;

    float lLin = eotfSt2084(l, 1.0);
    float mLin = eotfSt2084(m, 1.0);
    float sLin = eotfSt2084(s, 1.0);

    return vec3(
        max(3.43661 * lLin - 2.50645 * mLin + 0.0698454 * sLin, 0.0),
        max(-0.79133 * lLin + 1.9836 * mLin - 0.192271 * sLin, 0.0),
        max(-0.0259499 * lLin - 0.0989137 * mLin + 1.12486 * sLin, 0.0));
}

// -----------------------------------------------------------------------------
// Jzazbz 转换（输入/输出：线性 Rec.2020）
// 参考：Safdar 等人, "Perceptually uniform color space for image signals
//       including high dynamic range and wide gamut," Opt. Express 25 (2017)
// -----------------------------------------------------------------------------
#define JZAZBZ_EXPONENT_SCALE_FACTOR 1.7 // 指数缩放因子

vec3 rgbToJzazbz(vec3 rgb)
{
    float l = rgb.r * 0.530004 + rgb.g * 0.355704 + rgb.b * 0.086090;
    float m = rgb.r * 0.289388 + rgb.g * 0.525395 + rgb.b * 0.157481;
    float s = rgb.r * 0.091098 + rgb.g * 0.147588 + rgb.b * 0.734234;

    float lPQ = inverseEotfSt2084(l, JZAZBZ_EXPONENT_SCALE_FACTOR);
    float mPQ = inverseEotfSt2084(m, JZAZBZ_EXPONENT_SCALE_FACTOR);
    float sPQ = inverseEotfSt2084(s, JZAZBZ_EXPONENT_SCALE_FACTOR);

    float iz = 0.5 * lPQ + 0.5 * mPQ;

    return vec3(
        (0.44 * iz) / (1.0 - 0.56 * iz) - 1.6295499532821566e-11,
        3.524000 * lPQ - 4.066708 * mPQ + 0.542708 * sPQ,
        0.199076 * lPQ + 1.096799 * mPQ - 1.295875 * sPQ);
}

vec3 jzazbzToRgb(vec3 jab)
{
    float jz = jab.x + 1.6295499532821566e-11;
    float iz = jz / (0.44 + 0.56 * jz);
    float a  = jab.y;
    float b  = jab.z;

    float l = iz + a * 1.386050432715393e-1 + b * 5.804731615611869e-2;
    float m = iz + a * -1.386050432715393e-1 + b * -5.804731615611869e-2;
    float s = iz + a * -9.601924202631895e-2 + b * -8.118918960560390e-1;

    float lLin = eotfSt2084(l, JZAZBZ_EXPONENT_SCALE_FACTOR);
    float mLin = eotfSt2084(m, JZAZBZ_EXPONENT_SCALE_FACTOR);
    float sLin = eotfSt2084(s, JZAZBZ_EXPONENT_SCALE_FACTOR);

    return vec3(
        lLin * 2.990669 + mLin * -2.049742 + sLin * 0.088977,
        lLin * -1.634525 + mLin * 3.145627 + sLin * -0.483037,
        lLin * -0.042505 + mLin * -0.377983 + sLin * 1.448019);
}

// -----------------------------------------------------------------------------
// 统一色彩空间（UCS）：ICtCp 或 Jzazbz
// -----------------------------------------------------------------------------
#if TONE_MAPPING_UCS == TONE_MAPPING_UCS_ICTCP
vec3 rgbToUcs(vec3 rgb)
{
    return rgbToICtCp(rgb);
}
vec3 ucsToRgb(vec3 ucs)
{
    return iCtCpToRgb(ucs);
}
#elif TONE_MAPPING_UCS == TONE_MAPPING_UCS_JZAZBZ
vec3 rgbToUcs(vec3 rgb)
{
    return rgbToJzazbz(rgb);
}
vec3 ucsToRgb(vec3 ucs)
{
    return jzazbzToRgb(ucs);
}
#else
#error "Unsupported TONE_MAPPING_UCS value. Define as TONE_MAPPING_UCS_ICTCP or TONE_MAPPING_UCS_JZAZBZ."
#endif

// -----------------------------------------------------------------------------
// GT7 色调映射器配置
// 通过 gt7ToneMappingInitializeParameters / gt7ToneMappingInitializeAsSDR / gt7ToneMappingInitializeAsHDR 构建
// -----------------------------------------------------------------------------
struct GT7ToneMapping
{
    float sdrCorrectionFactor;
    float framebufferLuminanceTarget;    // 帧缓冲尺度下的目标亮度
    float framebufferLuminanceTargetUcs; // UCS 空间中的目标亮度（I 或 Jz）
    GTToneMappingCurveV2 curve;
    float blendRatio;
    float fadeStart;
    float fadeEnd;
};

// 根据目标显示物理亮度初始化曲线及有关参数
GT7ToneMapping gt7ToneMappingInitializeParameters(float physicalTargetLuminance)
{
    GT7ToneMapping t;
    t.framebufferLuminanceTarget = physicalValueToFrameBufferValue(physicalTargetLuminance);

    // 初始化曲线（参数与 GT Sport 略有不同）
    t.curve = gtToneMappingCurveInitialize(
        t.framebufferLuminanceTarget, 0.25, 0.538, 0.444, 1.280);

    // 默认参数
    t.blendRatio = 0.6;
    t.fadeStart  = 0.98;
    t.fadeEnd    = 1.16;

    // 将目标亮度转换到 UCS 空间，取第一个分量（I 或 Jz）作为亮度
    vec3 ucs = rgbToUcs(vec3(t.framebufferLuminanceTarget));
    t.framebufferLuminanceTargetUcs = ucs.x;

    return t;
}

// 初始化 HDR（高动态范围）输出
// 输入：目标显示峰值亮度（nit，范围 250 ~ 10000）。
// 注：下限为 250，因为曲线参数基于 250 nit 的 SDR 纸白假设确定。
GT7ToneMapping gt7ToneMappingInitializeAsHDR(float physicalTargetLuminance)
{
    GT7ToneMapping t = gt7ToneMappingInitializeParameters(physicalTargetLuminance);
    t.sdrCorrectionFactor = 1.0;
    return t;
}

// 初始化 SDR（标准动态范围）输出
GT7ToneMapping gt7ToneMappingInitializeAsSDR()
{
    // 关于 SDR 输出：
    // 在 GT（Gran Turismo）中，SDR 输出的最大值 1.0 对应
    // GRAN_TURISMO_SDR_PAPER_WHITE（通常为 250 nit）。
    // 因此基于该纸白进行 SDR 输出的色调映射。
    // 但 sRGB 标准中 1.0 对应 100 nit，因此需要用 sdrCorrectionFactor 调整，
    // 使色调映射后的值匹配 sRGB 范围，并在 HDR/SDR 输出间保持亮度的视觉一致性。
    GT7ToneMapping t = gt7ToneMappingInitializeParameters(GRAN_TURISMO_SDR_PAPER_WHITE);
    t.sdrCorrectionFactor = 1.0 / physicalValueToFrameBufferValue(GRAN_TURISMO_SDR_PAPER_WHITE);
    return t;
}

// 应用 GT7 色调映射
// 输入 : 线性 Rec.2020 RGB（帧缓冲值）
// 输出 : 色调映射后的 RGB（帧缓冲值）
//         - SDR 模式 : 映射到 [0, 1]，可直接应用 sRGB OETF
//         - HDR 模式 : 映射到 [0, framebufferLuminanceTarget]，可直接应用 PQ 逆 EOTF
vec3 gt7ToneMappingApply(GT7ToneMapping t, vec3 rgb)
{
    // 转换到 UCS 以分离亮度与色度
    vec3 ucs = rgbToUcs(rgb);

    // 逐通道色调映射（"偏斜"色彩）
    vec3 skewedRgb = vec3(
        gtToneMappingCurveEvaluate(t.curve, rgb.r),
        gtToneMappingCurveEvaluate(t.curve, rgb.g),
        gtToneMappingCurveEvaluate(t.curve, rgb.b));

    vec3 skewedUcs = rgbToUcs(skewedRgb);

    float chromaScale =
        chromaCurve(ucs.x / t.framebufferLuminanceTargetUcs, t.fadeStart, t.fadeEnd);

    // 亮度取自偏斜色彩，色度分量按 chromaScale 缩放
    vec3 scaledUcs = vec3(skewedUcs.x, ucs.y * chromaScale, ucs.z * chromaScale);

    // 转换回 RGB
    vec3 scaledRgb = ucsToRgb(scaledUcs);

    // 最终在逐通道结果与 UCS 缩放结果间混合
    vec3 blended = mix(skewedRgb, scaledRgb, t.blendRatio);
    // SDR 时应用校正因子；HDR 时 sdrCorrectionFactor 为 1.0，无影响
    return t.sdrCorrectionFactor * min(blended, vec3(t.framebufferLuminanceTarget));
}

// -----------------------------------------------------------------------------
// 简便入口
// -----------------------------------------------------------------------------
// 输入：
//   - rgb            : 线性 Rec.2020 RGB（帧缓冲值）
//   - targetNits     : HDR 目标显示峰值亮度（cd/m^2），仅 HDR 模式使用
//   - paperWhiteNits : HDR 参考纸白亮度（cd/m^2），用于将输入缩放到物理尺度，仅 HDR 模式使用
//   - isHDR          : true 表示 HDR 输出，否则为 SDR 输出
// 输出：
//   - SDR 模式 : 映射到 [0, 1]，可直接应用 sRGB OETF
//   - HDR 模式 : 映射到 [0, framebufferLuminanceTarget]，可直接应用 PQ 逆 EOTF
vec3 gt7ToneMap(vec3 rgb, float targetNits, float paperWhiteNits, bool isHDR)
{
    GT7ToneMapping t;
    vec3 frameBufferRgb = max(rgb, 0.0);

    if (isHDR)
    {
        // 将输入从参考纸白缩放到物理尺度
        frameBufferRgb *= paperWhiteNits / REFERENCE_LUMINANCE;
        t = gt7ToneMappingInitializeAsHDR(targetNits);
    }
    else
    {
        t = gt7ToneMappingInitializeAsSDR();
    }

    return gt7ToneMappingApply(t, frameBufferRgb);
}

#endif