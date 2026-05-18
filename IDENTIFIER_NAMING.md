# ShaderTest2 项目标识符命名规范

## 📋 目录

1. [变量命名规范](#变量命名规范)
2. [函数命名规范](#函数命名规范)
3. [结构体和类型命名规范](#结构体和类型命名规范)
4. [着色器阶段输出命名](#着色器阶段输出命名)
5. [坐标和纹理相关命名](#坐标和纹理相关命名)
6. [光照相关命名](#光照相关命名)
7. [缩写使用规范](#缩写使用规范)

---

## 变量命名规范

### 1. 方向和向量类

| 概念 | 推荐命名 | 示例 | 说明 |
|------|---------|------|------|
| **方向** | `Direction`（完整拼写） | `sunDirection`, `viewDirection`, `lightDirection` | 避免使用 `Dir`，保持清晰 |
| **位置** | `Pos`（缩写） | `viewPos`, `worldPos`, `shadowViewPos`, `feetPlayerPos` | 位置统一使用 `Pos` 而非 `Position` 或 `Location` |
| **法线** | `N`（单字母）或 `Normal` | `N`, `normal` | 局部变量可用 `N`，uniform/全局用 `normal` |
| **射线** | `Ray` | `viewRay`, `lightRay` | 表示从某点出发的方向向量 |
| **切线** | `T` 或 `Tangent` | `T`, `tangent` | 与法线类似 |
| **副法线** | `B` 或 `Bitangent` | `B`, `bitangent` | 与法线类似 |

**规则总结**：
- ✅ `sunDirection`（方向用完整拼写）
- ✅ `viewPos`（位置用缩写 Pos）
- ❌ `sunDir`（避免方向缩写）
- ❌ `viewPosition`（避免位置完整拼写）

---

### 2. 颜色和亮度类

| 概念 | 推荐命名 | 示例 | 说明 |
|------|---------|------|------|
| **颜色** | `Color` | `baseColor`, `skyColor`, `sunColor`, `localLightColor` | 统一使用 `Color` |
| **反照率** | `Albedo` | `baseAlbedo` | 特指经过光照调整后的颜色 |
| **亮度/强度** | `Amount` 或 `Intensity` | `sunLightAmount`, `ambientAmount`, `lightIntensity` | 标量强度用 `Amount` |
| **辐射度** | `Radiance` | `SUN_RADIANCE` | 物理准确的辐射度量 |
| **饱和度** | `Saturation` | `fakeGIFactor`（间接表示） | 较少直接使用 |

**规则总结**：
- ✅ `baseColor`（基础颜色）
- ✅ `sunLightAmount`（光照强度）
- ✅ `baseAlbedo`（反照率，特指受光照影响的颜色）
- ❌ `baseColour`（不使用英式拼写）

---

### 3. 坐标和空间类

| 概念 | 推荐命名 | 示例 | 说明 |
|------|---------|------|------|
| **像素坐标** | `pixelCoord` | `pixelCoord` | 整数屏幕坐标 |
| **归一化坐标** | `uv` | `uv` | 0-1 范围的纹理坐标 |
| **裁剪空间** | `ClipPos` 或 `NDCPos` | `shadowClipPos`, `NDCPos`, `clipXY` | 区分齐次裁剪空间和归一化设备坐标 |
| **视图空间** | `ViewPos` | `viewPos`, `shadowViewPos` | 相机坐标系 |
| **世界空间** | `WorldPos` | `worldPos` | 世界坐标系 |
| **对象空间** | `ObjectPos` | `objectPos` | 模型本地坐标系 |

**规则总结**：
- ✅ `pixelCoord`（像素坐标，整数）
- ✅ `uv`（归一化纹理坐标，最常用）
- ✅ `shadowClipPos`（阴影裁剪空间坐标）
- ❌ `texcoord`（仅在特定上下文使用，见后文）

---

### 4. 矩阵和变换类

| 概念 | 推荐命名 | 示例 | 说明 |
|------|---------|------|------|
| **模型视图** | `ModelView` | `gbufferModelViewInverse`, `shadowModelView` | 包含 `Inverse` 后缀表示逆矩阵 |
| **投影** | `Projection` | `gbufferProjectionInverse`, `shadowProjection` | 同上 |
| **变换矩阵** | `Transform` 或直接描述 | `rotation`（旋转矩阵） | 根据用途命名 |

**规则总结**：
- ✅ `gbufferModelViewInverse`（GBuffer 模型视图逆矩阵）
- ✅ `shadowProjection`（阴影投影矩阵）
- 矩阵名通常包含空间转换信息

---

### 5. 尺寸和范围类

| 概念 | 推荐命名 | 示例 | 说明 |
|------|---------|------|------|
| **宽度/高度** | `Width`/`Height` | `viewWidth`, `viewHeight`, `shadowMapResolution` | 完整拼写 |
| **分辨率** | `Resolution` 或 `Res` | `skyRes`, `fullRes`, `shadowMapResolution` | 局部变量可用 `Res` |
| **半径** | `Radius` | `SHADOW_RADIUS`, `PLANET_RADIUS` | 完整拼写 |
| **范围** | `Range` | `SHADOW_RANGE` | 完整拼写 |
| **厚度** | `Thickness` | `ATM_THICKNESS` | 可缩写为 `THICKNESS` |
| **比例/缩放** | `Scale` | `AEROSOL_HEIGHT_SCALE` | 完整拼写 |

**规则总结**：
- ✅ `viewWidth`, `viewHeight`（视口尺寸）
- ✅ `skyRes`（天空分辨率，局部变量可缩写）
- ✅ `SHADOW_RADIUS`（阴影采样半径，常量全大写）

---

### 6. 索引和计数类

| 概念 | 推荐命名 | 示例 | 说明 |
|------|---------|------|------|
| **索引** | `i`, `j`, `k` 或 `{name}Index` | `i`（循环）, `mipLevel` | 简单循环用单字母 |
| **计数** | `Count` 或 `Num` | `bloomMipCount`, `totalMips`, `samples` | 总数用 `Count` 或 `Total` |
| **层级** | `Level` | `mipLevel`, `lod` | Mipmap 层级 |
| **步数** | `Steps` | `TRANSMITTANCE_STEPS`, `INSCATTERING_STEPS` | 迭代次数 |

**规则总结**：
- ✅ `mipLevel`（Mipmap 层级）
- ✅ `totalMips`（总 Mipmap 数量）
- ✅ `i`, `x`, `y`（循环变量，简短即可）

---

## 函数命名规范

### 1. 获取/计算类函数

| 功能类型 | 推荐前缀 | 示例 | 说明 |
|---------|---------|------|------|
| **直接获取值** | `get` | `getShadow()`, `getNoise()`, `getBrightness()`, `getSoftShadow()` | 从纹理、缓冲区或简单计算获取 |
| **复杂计算** | 描述性动词 | `adjustSaturationFast()`, `projectAndDivide()`, `distortShadowClipPos()` | 涉及多步变换或算法 |
| **转换/映射** | `{Input}To{Output}` | `RoughnessToExponent()` | 明确的输入输出转换 |
| **物理计算** | 物理术语 | `specularGGX()`, `specularBlinnPhong()` | 使用标准物理模型名称 |
| **钳制/限制** | `saturate`, `clamp` | `saturate()` | 数学运算直接用函数名 |

**规则总结**：
- ✅ `getShadow()`（简单获取阴影值）
- ✅ `adjustSaturationFast()`（复杂的饱和度调整）
- ✅ `RoughnessToExponent()`（明确的转换关系）
- ❌ `calculateShadow()`（避免冗余的 `calculate`）
- ❌ `calcBrightness()`（避免 `calc` 缩写）

---

### 2. 函数命名模式

```glsl
// ✅ 推荐：直接获取
vec3 getShadow(vec3 shadowScreenPos);
float getBrightness(vec3 color);
vec4 getNoise(vec2 coord);

// ✅ 推荐：描述性操作
vec3 adjustSaturationFast(vec3 color, float s);
vec3 projectAndDivide(mat4 projectionMatrix, vec3 position);
vec3 distortShadowClipPos(vec3 shadowClipPos);

// ✅ 推荐：转换函数
float RoughnessToExponent(float roughness);

// ✅ 推荐：物理模型
float specularGGX(float NoH, float roughness);
float specularBlinnPhong(float NoH, float exponent);

// ❌ 避免：冗余前缀
vec3 calculateShadow(...);  // 应改为 getShadow
float calcBrightness(...);  // 应改为 getBrightness
```

---

## 结构体和类型命名规范

### 1. 结构体命名

| 类型 | 命名风格 | 示例 | 说明 |
|------|---------|------|------|
| **结构体** | PascalCase | `LightData`, `MaterialInfo` | 首字母大写 |
| **枚举** | PascalCase | `LightType`, `MaterialType` | 首字母大写 |
| **typedef** | PascalCase | `Ray`, `Transform` | 首字母大写 |

**注意**：当前项目中暂未大量使用结构体，但遵循此规范。

---

## 着色器阶段输出命名

### 1. 片段着色器输出（Fragment Shader Output）

| 输出类型 | 推荐命名 | 示例 | 说明 |
|---------|---------|------|------|
| **主颜色** | `color` | `color`, `outColor` | 通用颜色输出 |
| **深度** | `gl_FragDepth` 或自定义 | - | 使用内置或明确命名 |
| **多目标** | `color{n}` 或描述性 | `gbufferColor`, `gbufferNormal` | 根据 Render Target 用途 |

**示例**：
```glsl
layout(location = 0) out vec4 color;  // ✅ 推荐
void main() {
    color.rgb = vec3(1.0);
    color.a = 1.0;
}
```

---

### 2. Compute Shader 输出

| 输出类型 | 推荐命名 | 示例 | 说明 |
|---------|---------|------|------|
| **图像存储** | 无特定命名 | `imageStore(colorimg0, pixelCoord, vec4(...))` | 直接使用 imageStore |
| **共享内存** | `shared` + 描述性 | `shared float tileHasSky` | 工作组内共享 |

---

## 坐标和纹理相关命名

### 1. UV vs TexCoord

| 场景 | 推荐命名 | 示例 | 说明 |
|------|---------|------|------|
| **归一化纹理坐标 (0-1)** | `uv` | `uv`, `localUV`, `atlasUV` | **最常用**，简洁明了 |
| **顶点着色器传递的纹理坐标** | `vTexcoord` 或 `texcoord` | `vTexcoord[]`（GS 输入） | 仅在 GS/VS 接口中使用 |
| **像素坐标（整数）** | `pixelCoord` | `pixelCoord`, `noiseCoord` | 屏幕空间整数坐标 |
| **裁剪/ND 空间坐标** | `clipPos`, `NDCPos` | `shadowClipPos`, `NDCPos` | 区分不同空间 |

**规则总结**：
- ✅ `uv`（90% 的情况使用这个）
- ✅ `vTexcoord`（仅在 Geometry Shader 中作为 VS 输入）
- ❌ `texcoord`（避免在 FS/CS 中使用，容易混淆）

**示例**：
```glsl
// Fragment/Compute Shader
vec2 uv = (vec2(pixelCoord) + 0.5) / vec2(viewWidth, viewHeight);  // ✅
vec3 color = texture(colortex0, uv).rgb;  // ✅

// Geometry Shader（从 VS 接收）
in vec2 vTexcoord[];  // ✅
out vec2 texcoord;    // ✅ 传递给 FS
```

---

### 2. 纹理图集相关

| 概念 | 推荐命名 | 示例 | 说明 |
|------|---------|------|------|
| **图集 UV** | `atlasUV` | `atlasUV`, `encodeBloomAtlasUV()` | 明确是图集坐标 |
| **局部 UV** | `localUV` | `localUV` | 图集中某个 mip 的局部坐标 |
| **偏移量** | `Offset` | `xOffset`, `currentX` | 水平/垂直偏移 |
| **尺寸** | `Size` 或 `mipSize` | `mipSize`, `atlasSize` | 纹理尺寸 |

---

## 光照相关命名

### 1. 光照变量命名顺序

| 概念 | 推荐格式 | 示例 | 说明 |
|------|---------|------|------|
| **局部光照** | `localLight` | `localLight`, `localLightColor` | **形容词在前** |
| **环境光** | `ambientLight` | `ambientLight`, `ambientAmount` | 同上 |
| **太阳光** | `sun` + 属性 | `sunDirection`, `sunColor`, `sunLightAmount` | 太阳作为修饰词 |
| **漫反射** | `diffuse` + 光源 | `diffuseSun` | 光照类型在前 |
| **高光** | `specular` + 模型 | `specularGGX`, `specularBlinnPhong` | 使用标准模型名 |

**规则总结**：
- ✅ `localLight`（局部光，形容词在前）
- ✅ `sunDirection`（太阳的方向）
- ✅ `diffuseSun`（太阳的漫反射分量）
- ❌ `lightLocal`（避免名词在前）
- ❌ `directionSun`（不符合语义）

---

### 2. 光照强度和颜色

```glsl
// ✅ 推荐命名
vec3 sunColor = vec3(0.95, 0.88, 0.84);          // 太阳颜色
float sunLightAmount = min(normal.a, shadow);    // 太阳光强度
vec3 diffuseSun = sunLightAmount * lighting;     // 太阳漫反射
vec3 ambientLight = ambientAmount * skyColor;    // 环境光
vec3 localLightColor = vec3(1.0, 0.6, 0.2);      // 局部光颜色
vec3 localLight = intensity * localLightColor;   // 局部光贡献

// ❌ 避免
vec3 colorSun;           // 语义不清
float amountSunLight;    // 顺序混乱
vec3 sunDiffuse;         // 可以，但 diffuseSun 更清晰
```

---

## 缩写使用规范

### 1. 允许使用的缩写

| 完整词 | 缩写 | 使用场景 | 示例 |
|-------|------|---------|------|
| Position | `Pos` | **所有位置相关** | `viewPos`, `worldPos`, `shadowViewPos` |
| Coordinate | `Coord` | 像素/噪声坐标 | `pixelCoord`, `noiseCoord` |
| Resolution | `Res` | 局部变量 | `skyRes`, `fullRes` |
| Normal | `N` | 局部变量（单字母） | `N`（法线向量） |
| Tangent | `T` | 局部变量（单字母） | `T`（切线向量） |
| Bitangent | `B` | 局部变量（单字母） | `B`（副法线） |
| Texture | `tex` | 采样器后缀 | `noisetex`, `depthtex0` |
| Image | `img` | 图像后缀 | `colorimg0` |
| Level of Detail | `LOD` 或 `lod` | Mipmap 层级 | `textureLod()`, `lod` |
| Normalized Device Coordinates | `NDC` | 坐标空间 | `NDCPos`, `shadowNDCPos` |
| Inverse | `Inverse` | **不缩写** | `gbufferModelViewInverse` |
| Direction | **不缩写** | **永远完整拼写** | `sunDirection`, `viewDirection` |
| Color | **不缩写** | **永远完整拼写** | `baseColor`, `skyColor` |
| Light | **不缩写** | **永远完整拼写** | `localLight`, `ambientLight` |

---

### 2. 禁止使用的缩写

| 错误缩写 | 正确形式 | 原因 |
|---------|---------|------|
| `Dir` | `Direction` | 方向必须完整 |
| `Col` / `Clr` | `Color` | 颜色必须完整 |
| `Loc` | `Location` 或 `Pos` | 位置用 `Pos`，避免 `Loc` |
| `Calc` | `Calculate` 或直接用动词 | 避免冗余前缀 |
| `Amt` | `Amount` | 强度建议完整 |
| `Int` | `Intensity` | 容易与 `int` 类型混淆 |
| `Num` | `Count` 或 `Total` | 计数用 `Count` 更清晰 |

---

### 3. 单字母变量使用规范

| 字母 | 含义 | 使用场景 | 示例 |
|------|------|---------|------|
| `i`, `j`, `k` | 循环索引 | for/while 循环 | `for (int i = 0; ...)` |
| `x`, `y`, `z` | 坐标分量/循环变量 | 嵌套循环或向量访问 | `vec3(x, y, z)` |
| `N` | 法线向量 | 局部变量 | `vec3 N = normalize(normal.xyz)` |
| `T` | 切线向量 | 局部变量 | `vec3 T = tangent` |
| `B` | 副法线向量 | 局部变量 | `vec3 B = bitangent` |
| `u`, `v` | 纹理坐标分量 | 解构 UV | `float u = uv.x, v = uv.y` |
| `r`, `g`, `b`, `a` | 颜色分量 | 解构颜色 | `float r = color.r` |
| `w`, `h` | 宽高临时变量 | Bloom 等效果 | `float w = 4.0 / viewWidth` |

**规则**：
- ✅ 循环变量、向量分量可以使用单字母
- ❌ 重要状态变量不应使用单字母（如光照强度、位置等）

---

## 综合示例

### ✅ 推荐的完整代码风格

```glsl
// Uniform 变量
uniform vec3 sunDirection;
uniform float viewWidth;
uniform float viewHeight;
uniform mat4 gbufferModelViewInverse;

// 常量
const float SHADOW_RADIUS = 0.5;
const int SHADOW_RANGE = 3;

// 函数：获取阴影
vec3 getSoftShadow(vec4 shadowClipPos, vec2 uv) {
    vec3 shadowAccum = vec3(0.0);
    
    for (int x = -SHADOW_RANGE; x < SHADOW_RANGE; x++) {
        for (int y = -SHADOW_RANGE; y < SHADOW_RANGE; y++) {
            vec2 offset = vec2(x, y) * SHADOW_RADIUS;
            // ... 计算阴影
        }
    }
    
    return shadowAccum / float(samples);
}

// 主函数
void main() {
    ivec2 pixelCoord = ivec2(gl_GlobalInvocationID.xy);
    vec2 uv = (vec2(pixelCoord) + 0.5) / vec2(viewWidth, viewHeight);
    
    vec3 baseColor = texelFetch(colortex1, pixelCoord, 0).rgb;
    vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDCPos);
    
    vec3 sunColor = vec3(0.95, 0.88, 0.84);
    float sunLightAmount = min(normal.a, shadow);
    vec3 diffuseSun = sunLightAmount * sunColor;
    
    vec3 localLightColor = vec3(1.0, 0.6, 0.2);
    vec3 localLight = pow(intensity, 3.0) * localLightColor;
    
    vec3 outColor = baseColor * (diffuseSun + localLight);
    imageStore(colorimg0, pixelCoord, vec4(outColor, 1.0));
}
```

---

## 📌 快速参考表

| 概念 | 推荐命名 | 禁止/避免 |
|------|---------|----------|
| 方向 | `Direction` | `Dir` |
| 位置 | `Pos` | `Position`, `Location`, `Loc` |
| 颜色 | `Color` | `Col`, `Clr` |
| 光照 | `Light`（形容词在前） | `lightLocal` |
| 获取值函数 | `getXXX()` | `calculateXXX()`, `calcXXX()` |
| 转换函数 | `AToB()` | `convertAToB()` |
| UV 坐标 | `uv` | `texcoord`（FS/CS 中） |
| 像素坐标 | `pixelCoord` | `screenPos`（易混淆） |
| 法线（局部） | `N` | `normal`（局部变量） |
| 计数 | `Count`, `Total` | `Num`, `Amt` |

---

遵循这些规范可以确保代码的一致性和可读性，便于团队协作和长期维护！🎯
