# ShaderTest2 命名规范文档

> 本文档分析了项目中存在的命名不一致问题，并制定了统一规范。

---

## 零、当前目录约定（2026-11 结构整理后）

**仓库 `shaders/` 目录与最终 shaderpack 的 `shaders/` 一一对应**（同路径、同文件名）；开发期由 `build.py` 做占位符替换并生成 `world0/` 薄壳，产物不含任何 `build.py` 的痕迹。

| 路径 | 职责 | 规则 |
|------|------|------|
| `shaders/options.glsl` | 用户可调开关与滑块 | 只有 `#define`；名字需同时出现在 `shaders.properties` 的 `sliders` 里才会显示 |
| `shaders/settings.glsl` | Iris 内建 uniform 常量 | 不得放用户选项；与包布局相关的值一律放 `build.py` |
| `shaders/lib/prelude.glsl` | **唯一入口** | 每个 stage 的第一条 include；聚合 settings/options/math/rt_formats |
| `shaders/lib/rt_formats.glsl` | 由 `build.py` 生成的 RT 格式声明 | 手写会与 `RT_LIST` 脱节，勿改 |
| `shaders/lib/<域>/*.glsl` | 纯函数库，按域分目录：`utility/`(math,color) `lighting/`(brdf,shadow,tuning) `atmosphere/`(9 个模块) | **不得包含 `main()`**，不得定义 Iris uniform；域内 ≥3 文件时提供 `all.glsl` 聚合器 |
| `shaders/program/<域>/*.glsl` | pass 的 include 体，域为 `gbuffers/ shadow/ setup/ prepare/ deferred/ post/` | 一个文件可同时含 frag/vert/geom 三段；compute pass 命名为 `*_cs.glsl`；一个文件可通过 `{{SLOT_DEFINES}}` 服务多个槽位 |
| `shaders/textures/` | 随包资源 | 只放被引用的文件；`textures/projects/` 为制作工程，不进包 |
| `shaders/world0/` | Iris 槽位薄壳 | **仅由 `build.py` 生成**，不手改、不入库 |
| `build.py`（仓库根） | 模板替换 + 入口生成 + 输出 | `PIPELINE` 决定 pass 顺序，`RT_LIST`/`IMG_LIST` 是缓冲区的唯一真源 |

约定要点：

- **尺寸常量不写死在 shader 里**：使用 `{{RT_<NAME>_SIZE_X}}` / `{{IMG_<NAME>_SIZE_X}}`，由 `RT_LIST`/`IMG_LIST` 生成。
- **`lib/` 内不得同时承担 pass 源码**（历史上的 `shadowmap.glsl` 同时含 `main()`，已拆分）。
- 用户可见颜色/强度参数放在 `shaders/options.glsl`；物理常量放在所属模块（如 `shaders/lib/atmosphere/constants.glsl`），必须带单位与来源注释。光照"外观调参"常量集中在 `shaders/lib/lighting/tuning.glsl`。

---

## 一、发现的问题汇总

> ⚠️ 本节与「四、执行计划」记录的是 **2026-06-22 那次整理之前**的状态，其中的文件路径
> （`lib/common.glsl`、`program/shadow_common.glsl`、`program/composite_*.glsl` 等）属于旧布局，
> 仅作历史参考。当前布局见上节「零、当前目录约定」与 [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)。

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
规则：单命名空间 {{SCREAMING_SNAKE_CASE}}，后缀表示"用在哪里"

缓冲（colortex）
  {{RT_<NAME>}}           → colortexN   sampler2D / 属性键 / flip 键
  {{RT_<NAME>_IMG}}       → colorimgN   image2D 句柄
  {{RT_<NAME>_SLOT}}      → N           RENDERTARGETS 索引
  {{RT_<NAME>_FORMAT}}    → rgba8 等    layout(...) 格式
  {{RT_<NAME>_SIZE}}      → 1.0 1.0     相对尺寸（含 _SIZE_X / _SIZE_Y）
自定义图（custom image）
  {{IMG_<NAME>}} / {{IMG_<NAME>_SAMPLER}} / {{IMG_<NAME>_FORMAT}} / {{IMG_<NAME>_SIZE_X}}
整块生成
  {{GENERATED_RT_FORMATS}} / {{GENERATED_RT_SIZES}} / {{GENERATED_IMG_DECLS}}
阶段标记
  {{SHADER_VERT}} {{SHADER_FRAG}} {{SHADER_GEOM}} {{SHADER_COMP}}
槽位附加宏（一个源文件服务多个 Iris 槽位时）
  {{SLOT_DEFINES}}        → 例如 #define BLUR_AXIS 1

✅ 正确示例：
  /* RENDERTARGETS: {{RT_ALBEDO_SLOT}},{{RT_NORMAL_SLOT}},{{RT_LIGHTMAP_SLOT}} */
  uniform sampler2D {{RT_HDR}};
  layout({{RT_HDR_FORMAT}}) uniform writeonly image2D {{RT_HDR_IMG}};
  vec2 workGroupsRender = vec2({{IMG_SKY_SIZE_X}}, {{IMG_SKY_SIZE_Y}});

❌ 禁止（已移除的旧写法）：
  {RT_HDR}                → 用 {{RT_HDR_SLOT}}（单花括号无法与双花括号区分）
  {{IMG_HDR}}             → RT 不提供 IMG_ 别名，用 {{RT_HDR_IMG}}
  {{RT_HDR_FORMAT_IMG}}   → 用 {{RT_HDR_FORMAT}}
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

1. **`lib/prelude.glsl`** — 唯一入口，聚合 `settings.glsl` / `options.glsl` / `utility/math.glsl` / `rt_formats.glsl`
2. **`lib/atmosphere/`** — 大气散射，按职责拆为 constants / geometry / phase / medium / transmittance / scattering / skyview / scene，`all.glsl` 聚合
3. **`lib/lighting/`** — `brdf.glsl`、`shadow.glsl`，以及集中放置外观调参的 `tuning.glsl`
4. **`lib/utility/`** — `math.glsl`、`color.glsl`；`program/` 侧同名域放 pass 本体

### K. 聚合器与多槽位复用

1. **聚合器**：域内文件 ≥3 个时提供 `all.glsl`（如 `lib/atmosphere/all.glsl`），内容只有按依赖顺序的 `#include`，不含逻辑。调用方只 include 聚合器，域内拆分对调用方不可见。
2. **多槽位复用**：一个源文件服务多个 Iris 槽位时，槽位差异**必须**通过 `build.py` 的 `Pass.defines` 注入（如 `("BLOOM_LEVEL 2",)`），不得复制文件、也不得在 properties 里另配一份。
3. **一个 stage 一个文件**：只有在文件确实需要同时提供多个 stage 时才用 `// {{SHADER_FRAG}}` 分段；单纯为了少建文件而在一个文件里塞多个 stage 是不允许的。

---

## 三、需要修正的文件清单（全部已修正 ✅）

| 优先级 | 文件 | 问题 | 状态 |
|--------|------|------|------|
| 🔴 高 | `lib/common.glsl` | `PI` 重复定义；`RoughnessToExponent` 命名 | ⚠️ 见勘误 |
| 🔴 高 | `lib/atmosphere.glsl` | 缺少 `#include`；`PI` 重复；缩写展开 | ✅ |
| 🔴 高 | `program/shadow_common.glsl` | 与 deferred_lighting 重复 `distortShadowClipPos` | ⚠️ 见勘误 |
| 🔴 高 | `program/deferred_lighting_cs.glsl` | `{{RT_BACK_IMG}}`；重复定义；Allman风格 | ✅ |
| 🟡 中 | `program/gbuffers_skybasic.glsl` | 缺少 `{{}}` 模板括号 | ✅ |
| 🟡 中 | 4 个文件 | 文件名混合 camelCase | ✅ |
| 🟢 低 | 全项目 | 大括号风格统一为 Allman | ✅ |
| 🟢 低 | 全项目 | 缩写展开(`Pos`→`Position`,`coord`→`coordinate`等) | ✅ |

---

## 四、执行计划建议

> ⚠️ **勘误（2026-11）**：下表中 2026-06-22 的记录有多处与当时的实际代码不符 ——
> `PI` 实际在 `math.glsl` 而非 `common.glsl`；`program/shadow_common.glsl` 从未被构建引用，
> 与 `lib/shadowmap.glsl` 重复。这些遗留问题已在 2026-11 的结构整理中按下方"零、当前目录约定"处理：
> `common.glsl` 拆为 `prelude.glsl` + `rt_formats.glsl`，`shadowmap.glsl` 拆为 `lib/shadow.glsl` + `program/shadow.glsl`，
> `shadow_common.glsl` 删除。

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
