# ShaderTest2 命名规范文档

> 本文档分析了项目中存在的命名不一致问题，并制定了统一规范。

---

## 一、发现的问题汇总

### 1. 函数命名风格不统一

| 风格 | 示例 | 文件 |
|------|------|------|
| camelCase（主流） | `adjustSaturationFast()` | `lib/common.glsl` |
| camelCase | `getBrightness()` | `lib/common.glsl` |
| camelCase | `specularGGX()` | `lib/common.glsl` |
| **PascalCase** ❌ | `RoughnessToExponent()` | `lib/common.glsl` |
| **PascalCase** ❌ | `RgbFromSpectral()` | `program/deferred_sky_cs.glsl` |

> **问题**：`RoughnessToExponent` 和 `RgbFromSpectral` 使用 PascalCase，而其他所有函数使用 camelCase。

### 2. 常量重复定义

| 文件 | 定义 |
|------|------|
| `lib/common.glsl:8` | `#define PI 3.141592653589793` |
| `lib/atmosphere.glsl:5` | `const float PI = 3.14159265358979323846;` |

> **问题**：`PI` 在两个文件中被重复定义，且精度不同（15位 vs 20位）。`atmosphere.glsl` 中额外定义了 `INV_PI` 和 `INV_4PI`，但 `common.glsl` 中的函数可能也需要这些值。

### 3. 函数重复定义

| 函数 | 文件 |
|------|------|
| `distortShadowClipPos()` | `program/deferred_lighting_cs.glsl:31` |
| `distortShadowClipPos()` | `program/shadow_common.glsl:14` |

> **问题**：同一函数在两个文件中分别定义，应提取到 `shadow_common.glsl` 并只在需要的文件中 `#include`。

### 4. 着色器类型标记不一致

| 文件 | 标记方式 |
|------|---------|
| `gbuffers_common.glsl` | `// {{SHADER_FRAG}}` ✅ |
| `gbuffers_skybasic.glsl` | `// SHADER_FRAG` ❌ (缺少模板括号) |
| `shadow_common.glsl` | `// {{SHADER_FRAG}}` ✅ |
| `deferred_lighting_cs.glsl` | `// {{SHADER_COMP}}` ✅ |

> **问题**：`gbuffers_skybasic.glsl` 的 `SHADER_FRAG` 和 `SHADER_VERT` 标记缺少 `{{}}`，不会被构建脚本的模板替换处理。

### 5. 文件命名风格混乱

| 命名模式 | 示例 | 
|----------|------|
| 纯 snake_case ✅ | `gbuffers_common.glsl`, `shadow_common.glsl`, `common_mipmap.glsl` |
| **snake_case 内嵌 camelCase** ❌ | `composite_lightingLUT_cs.glsl`, `prepare_atmosphereLUT_cs.glsl` |
| **snake_case 内嵌 camelCase** ❌ | `prepare_transmitLUT_cs.glsl`, `prepare_lightingLUT_cs.glsl` |

> **问题**：`lightingLUT`、`atmosphereLUT`、`transmitLUT` 在文件名的 snake_case 中混入了 camelCase。应全小写为 `lighting_lut`、`atmosphere_lut`、`transmit_lut`。

### 6. 模板占位符命名不完全一致

| 模式 | 示例 |
|------|------|
| `{{IMG_*}}` | `{{IMG_BLOOM}}`, `{{IMG_SKY}}`, `{{IMG_TRANSMIT_LUT}}` |
| `{{IMG_*_SAMPLER}}` | `{{IMG_BLOOM_SAMPLER}}`, `{{IMG_TRANSMIT_LUT_SAMPLER}}` |
| `{{IMG_*_FORMAT}}` | `{{IMG_BACK_FORMAT}}`, `{{IMG_SKY_FORMAT}}` |
| **`{{RT_*_IMG}}`** ❌ | `{{RT_BACK_IMG}}`（仅在 `deferred_lighting_cs.glsl` 中一处使用） |

> **问题**：对于 Render Target 的 image 引用，使用了 `_IMG` 后缀，与 `IMG_*` 前缀命名体系的语义冲突。`deferred_lighting_cs.glsl:118` 使用了 `{{RT_BACK_IMG}}`，但其他统一使用 `{{IMG_BACK}}`。

### 7. 大括号风格不一致

```glsl
// K&R 风格（多数文件）
void main() {
    ...
}

// Allman 风格（部分文件）
void main()
{
    ...
}
```

> **问题**：`deferred_sky_cs.glsl`、`lib/atmosphere.glsl`、`lib/common.glsl` 等使用 Allman 风格（大括号换行），而 `deferred_lighting_cs.glsl` 混合使用两种风格（`getShadow` 用 K&R，`main` 用 Allman）。

### 8. 缩进风格不一致

| 文件 | 缩进 |
|------|------|
| `lib/common.glsl` | 4 空格 |
| `lib/atmosphere.glsl` | 4 空格 |
| `program/deferred_lighting_cs.glsl` | 4 空格（部分）与 Tab 混用 |
| `program/gbuffers_skybasic.glsl` | Tab |
| `program/shadow_common.glsl` | 混合（Tab 和空格） |

### 9. 缩写不一致

| 概念 | 出现的缩写变体 |
|------|---------------|
| Atmosphere | `Atm` / `atmos` / `ATM` / `ATMOSPHERE` |
| Transmittance | `transmit` / `transmittance` / `TRANSMITTANCE` / `TRANSMIT` |
| Scattering | `Scat` / `SCAT` / `INSCATTERING` / `scattering` |
| Direction | `dir` / `Dir` / `Direction` / `direction` |
| Position | `pos` / `Pos` / `Coord` / `coord` / `position` |
| Distance | `dist` / `Dist` / `Distortion` (不同词，但 `dist` 容易误解) |
| Coefficient | `coefficients` / `coeff` (未出现但应规范) |

### 10. 变量前缀命名不统一

| 变量 | 说明 |
|------|------|
| `outBaseColor`, `outNormal` | `out` 前缀表示输出 |
| `baseColor`, `normal` | 同文件中的本地变量无前缀 |
| `fakeGI`, `fakeGIFactor` | 缩写与完整词混合 |
| `sunLightAmount` | 完整词 |
| `prevValue`, `currentValue` | 完整词 |

---

## 二、命名规范（推荐采用）

### A. 文件命名

```
规则：全小写 snake_case
格式：{类别}_{功能}[_{阶段}].glsl

✅ 正确示例：
  gbuffers_common.glsl
  shadow_common.glsl
  deferred_lighting_cs.glsl
  deferred_sky_cs.glsl
  composite_final.glsl
  composite_bloom_cs.glsl
  composite_exposure_cs.glsl
  composite_lighting_lut_cs.glsl      ← 修正
  prepare_atmosphere_lut_cs.glsl      ← 修正
  prepare_lighting_lut_cs.glsl        ← 修正
  prepare_transmit_lut_cs.glsl        ← 修正
  common_mipmap.glsl
  gbuffers_skybasic.glsl

❌ 错误示例：
  composite_lightingLUT_cs.glsl       ← 混合 camelCase
  prepare_atmosphereLUT_cs.glsl       ← 混合 camelCase
```

### B. 函数命名

```
规则：camelCase（首字母小写）
格式：{动词}{名词}[{修饰词}]()

✅ 正确示例：
  getBrightness()                     ← 动词 + 名词
  adjustSaturationFast()              ← 动词 + 名词 + 修饰
  specularGGX()                       ← 名词 + 专有缩写
  raySphereIntersect()                ← 名词 + 名词 + 动词
  computeTransmittance()              ← 动词 + 名词
  distortShadowClipPos()              ← 动词 + 名词短语
  tileHasSky()                        ← 名词 + 动词 + 名词（布尔返回值）

❌ 需要修正：
  RoughnessToExponent()               → roughnessToExponent()
  RgbFromSpectral()                   → rgbFromSpectral()
```

### C. 变量命名

```
规则：camelCase（首字母小写）
- 局部变量/参数：camelCase
- 输出变量（out）：out + PascalCase 前缀
- 布尔变量：使用 is/has/should 等前缀

✅ 正确示例：
  float cosTheta;
  vec3 rayOrigin;
  float sunLightAmount;
  bool insideAtm;        ← 已有，合理
  bool tileHasSky;       ← 函数名，合理
  vec4 outBaseColor;     ← 输出变量
```

### D. 常量与宏

```
规则：SCREAMING_SNAKE_CASE
- 编译时常量（const）：SCREAMING_SNAKE_CASE
- 宏定义（#define）：SCREAMING_SNAKE_CASE
- 应统一在 common.glsl 中定义全局常量

✅ 正确示例：
  const float PI = 3.14159265358979323846;
  const float INV_PI = 0.31830988618379067154;
  const int TRANSMITTANCE_STEPS = 32;
  #define SPECULAR_GGX
  #define BLOOM_MAX_MIPS 8
```

### E. 模板占位符

```
规则：{{SCREAMING_SNAKE_CASE}}
- Render Target 引用：{{RT_*}}
- Custom Image 引用：{{IMG_*}}
- 采样器引用：{{IMG_*_SAMPLER}}
- 格式引用：{{RT_*_FORMAT}} 或 {{IMG_*_FORMAT}}
- 着色器类型标记：{{SHADER_COMP}}, {{SHADER_FRAG}}, {{SHADER_VERT}}, {{SHADER_GEOM}}

✅ 正确示例：
  {{RT_BACK}}
  {{RT_BASE_COLOR}}
  {{IMG_BLOOM}}
  {{IMG_BLOOM_SAMPLER}}
  {{IMG_SKY_FORMAT}}
  {{SHADER_FRAG}}

❌ 需要修正：
  {{RT_BACK_IMG}}        → 统一使用 {{IMG_BACK}}
  // SHADER_FRAG          → 改为 // {{SHADER_FRAG}}（添加模板括号）
```

### F. 着色器类型标记

```
规则：所有文件必须使用 {{}} 模板括号包裹

✅ 正确：
  // {{SHADER_FRAG}}
  #ifdef {{SHADER_FRAG}}
  // {{SHADER_VERT}}
  #ifdef {{SHADER_VERT}}

❌ 错误（gbuffers_skybasic.glsl）：
  // SHADER_FRAG
  #ifdef SHADER_FRAG
```

### G. 大括号风格

```
规则：统一使用 Allman 风格（大括号换行）
理由：更适合 GLSL 着色器代码，与 Iris Shaders 官方风格一致

✅ 正确：
  void main()
  {
      ...
  }

  if (condition)
  {
      ...
  }

❌ 避免：
  void main() {
      ...
  }
```

### H. 缩进规则

```
规则：统一使用 4 空格缩进，禁止 Tab
```

### I. 缩写规范

| 完整词 | 缩写 | 使用场景 |
|--------|------|---------|
| Atmosphere | `atmosphere` | 常量/变量全称（避免 `atm`/`atmos`） |
| Transmittance | `transmittance` | 函数/变量全称 |
| Scattering | `scattering` | 函数/变量全称 |
| Direction | `direction` | 变量全称；`dir` 仅用于极短的局部变量 |
| Position | `position` | 变量全称；`pos` 仅用于极短的局部变量 |
| Coefficient | `coeff` 或 `coef` | 统一用 `coeff`（复数 `coeffs`） |
| Distance | `distance` | 避免 `dist`（容易与 distortion 混淆） |
| Look-Up Table | `LUT` | 专有缩写，始终大写 |
| GGX | `GGX` | 专有缩写，始终大写 |

### J. 代码组织建议

1. **`lib/common.glsl`** — 所有全局常量和通用工具函数
2. **`lib/atmosphere.glsl`** — 大气散射相关（应移除重复的 `PI` 定义，改为 `#include "/lib/common.glsl"`）
3. **`lib/options.glsl`** — 所有用户可配置宏
4. **`lib/shadow_common.glsl`** — 阴影相关共享函数（将 `distortShadowClipPos` 只保留在此文件）

---

## 三、需要修正的文件清单（全部已修正 ✅）

| 优先级 | 文件 | 问题 | 状态 |
|--------|------|------|------|
| 🔴 高 | `lib/common.glsl` | `PI` 重复定义；`RoughnessToExponent` 命名 | ✅ |
| 🔴 高 | `lib/atmosphere.glsl` | 缺少 `#include`；`PI` 重复；缩写展开 | ✅ |
| 🔴 高 | `program/shadow_common.glsl` | 与 deferred_lighting 重复 `distortShadowClipPos` | ✅ |
| 🔴 高 | `program/deferred_lighting_cs.glsl` | `{{RT_BACK_IMG}}`；重复定义；Allman风格 | ✅ |
| 🟡 中 | `program/gbuffers_skybasic.glsl` | 缺少 `{{}}` 模板括号 | ✅ |
| 🟡 中 | 4 个文件 | 文件名混合 camelCase | ✅ |
| 🟢 低 | 全项目 | 大括号风格统一为 Allman | ✅ |
| 🟢 低 | 全项目 | 缩写展开(`Pos`→`Position`,`coord`→`coordinate`等) | ✅ |

---

## 四、执行计划建议

> ✅ **已全部完成** (2026-06-22)

### 已执行的修正

| 步骤 | 状态 | 内容 |
|------|------|------|
| 1 | ✅ | `lib/common.glsl`: `#define PI` → `const float PI`(高精度)，添加 `INV_PI`/`INV_4PI`，`RoughnessToExponent` → `roughnessToExponent` |
| 2 | ✅ | `lib/atmosphere.glsl`: 添加 `#include "/lib/common.glsl"`，移除重复常量，全部缩写展开 |
| 3 | ✅ | `program/deferred_lighting_cs.glsl`: 移除重复 `distortShadowClipPos`，`#include shadow_common`，`{{RT_BACK_IMG}}`→`{{IMG_BACK}}` |
| 4 | ✅ | `program/gbuffers_skybasic.glsl`: 修复 `{{}}` 模板括号 |
| 5 | ✅ | `program/deferred_sky_cs.glsl`: `RgbFromSpectral` → `rgbFromSpectral` |
| 6 | ✅ | 文件重命名: `lightingLUT`→`lighting_lut`, `atmosphereLUT`→`atmosphere_lut`, `transmitLUT`→`transmit_lut` |
| 7 | ✅ | `build.py`: 更新 `PREPARE_INDEX`/`COMPOSITE_INDEX` 引用 |
| 8 | ✅ | 全项目: 统一 Allman 大括号风格、4空格缩进、缩写展开、`Pos`→`Position`/`coord`→`coordinate` |

### `$` 标记说明

所有被修改的命名处，下方均添加了 `//原代码行$` 格式的注释，便于回溯原始代码。
