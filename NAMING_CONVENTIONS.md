# ShaderTest2 项目命名规范

## 📁 目录结构

```
ShaderTest2/
├── lib/                    # 共享库文件
│   ├── common.glsl        # 通用函数和常量
│   ├── atmosphere.glsl    # 大气散射相关函数
│   └── options.glsl       # 用户可配置选项
├── program/               # 着色器源文件（.glsl）
│   ├── gbuffers_*.glsl   # GBuffer 阶段着色器
│   ├── shadow_*.glsl     # 阴影阶段着色器
│   ├── prepare_*.glsl    # 预处理 Compute Shader
│   ├── deferred_*.glsl   # 延迟渲染阶段着色器
│   ├── composite_*.glsl  # 合成阶段着色器
│   └── common_*.glsl     # 公共/共享着色器
├── build.py              # 构建脚本
├── global_settings.glsl  # 全局设置
└── shaders.properties    # Iris/OptiFine 配置
```

## 🎨 GLSL 文件命名规范

### 1. GBuffer 着色器 (`gbuffers_*.glsl`)

**用途**: 几何缓冲器填充阶段，负责渲染场景几何体到多个 render target。

**命名格式**: `gbuffers_{program_name}.glsl`

**示例**:
- `gbuffers_common.glsl` - 公共 GBuffer 代码（特殊文件，不参与程序列表）
- `gbuffers_skybasic.glsl` - 基础天空渲染
- `gbuffers_terrain.glsl` - 地形渲染
- `gbuffers_entities.glsl` - 实体渲染
- `gbuffers_hand.glsl` - 手部/物品渲染

**生成文件**: 
- `world0/gbuffers_{program_name}.fsh` (片段着色器)
- `world0/gbuffers_{program_name}.vsh` (顶点着色器)
- `world0/gbuffers_{program_name}.gsh` (几何着色器，如果源文件包含 `{{SHADER_GEOM}}`)

**内部结构**:
```glsl
// {{SHADER_FRAG}}
#ifdef {{SHADER_FRAG}}
// Fragment shader code
#endif

// {{SHADER_VERT}}
#ifdef {{SHADER_VERT}}
// Vertex shader code
#endif

// {{SHADER_GEOM}} (可选)
#ifdef {{SHADER_GEOM}}
// Geometry shader code
#endif
```

---

### 2. 阴影着色器 (`shadow_*.glsl`)

**用途**: 阴影映射生成阶段。

**命名格式**: `shadow_{program_name}.glsl`

**示例**:
- `shadow_common.glsl` - 公共阴影代码（特殊文件）
- `shadow.glsl` - 默认阴影着色器（program_name 为空）
- `shadow_terrain.glsl` - 地形阴影

**生成文件**:
- `world0/shadow{program_name}.fsh`
- `world0/shadow{program_name}.vsh`

**注意**: 如果 program_name 为空，文件名不包含下划线（如 `shadow.fsh`）。

---

### 3. 预处理 Compute Shader (`prepare_*.glsl`)

**用途**: 帧开始前的预计算，通常生成 LUT（查找表）或初始化数据。

**命名格式**: `prepare_{task_name}_cs.glsl`

**示例**:
- `prepare_lightingLUT_cs.glsl` - 生成光照 LUT
- `prepare_transmitLUT_cs.glsl` - 生成透射 LUT
- `prepare_atmosphereLUT_cs.glsl` - 生成大气散射 LUT

**执行顺序**: 由 `build.py` 中的 `PREPARE_INDEX` 列表控制。

**生成文件**: `world0/prepare{index}.csh`（index 从 1 开始）

---

### 4. 延迟渲染 Compute Shader (`deferred_*.glsl`)

**用途**: 延迟渲染阶段的光照计算、天空视图生成等。

**命名格式**: `deferred_{task_name}_cs.glsl`

**示例**:
- `deferred_lighting_cs.glsl` - 延迟光照计算
- `deferred_sky_cs.glsl` - 天空渲染
- `deferred_skyview_cs.glsl` - 天空视图生成

**执行顺序**: 由 `build.py` 中的 `DEFERRED_INDEX` 列表控制。

**生成文件**: `world0/deferred{index}.csh`

---

### 5. 合成阶段着色器 (`composite_*.glsl`)

**用途**: 后处理阶段，包括 Bloom、曝光、色调映射等。

**命名格式**: `composite_{task_name}_cs.glsl` (Compute Shader) 或 `composite_{task_name}.glsl` (Fragment/Vertex Shader)

**示例**:
- `composite_mipmap.glsl` - Mipmap 生成（Fragment Shader）
- `composite_bloom_downsample_cs.glsl` - Bloom 下采样（Compute Shader）
- `composite_bloom_blur_vert_cs.glsl` - Bloom 垂直模糊（Compute Shader）
- `composite_bloom_cs.glsl` - Bloom 合成（Compute Shader）
- `composite_exposure_cs.glsl` - 曝光调整（Compute Shader）
- `composite_final.glsl` - 最终输出（Fragment Shader）

**执行顺序**: 由 `build.py` 中的 `COMPOSITE_INDEX` 列表控制。

**生成文件**: 
- Compute Shader: `world0/composite{index}.csh`
- Fragment/Vertex Shader: `world0/composite{index}.fsh` 和 `.vsh`

---

### 6. 公共/共享着色器 (`common_*.glsl`)

**用途**: 在多个阶段之间共享的代码，通常用于触发特定功能（如 Mipmap 生成）。

**命名格式**: `common_{feature_name}.glsl`

**示例**:
- `common_mipmap.glsl` - 触发 Mipmap 生成

**特殊行为**: 
- 这些文件会被复制到对应的阶段索引位置
- 可以同时出现在 PREPARE/DEFERRED/COMPOSITE 列表中
- 避免重复处理（使用 `processed_common_files` 集合）

---

## 📝 变量和函数命名规范

### 1. GLSL 变量命名

#### Uniform 变量
- **采样器 (Sampler)**: 使用 `sampler2D`、`samplerCube` 等类型
  - `noisetex` - 噪声纹理
  - `depthtex0` - 深度纹理
  - `shadowtex0` - 阴影纹理
  - `shadowcolor0` - 阴影颜色纹理
  - `colortex{n}` - 颜色纹理（n 为 render target 索引）

- **矩阵 (Matrix)**: 
  - `gbufferModelViewInverse` - GBuffer 模型视图逆矩阵
  - `gbufferProjectionInverse` - GBuffer 投影逆矩阵
  - `shadowModelView` - 阴影模型视图矩阵
  - `shadowProjection` - 阴影投影矩阵

- **向量 (Vector)**:
  - `sunDirection` - 太阳方向向量
  - `viewWidth`, `viewHeight` - 视口尺寸

- **图像 (Image)**:
  - `colorimg{n}` - 颜色图像（n 为 render target 索引）

- **常量 (Const)**:
  - `workGroupsRender` - 工作组渲染范围
  - `ambientAmount` - 环境光强度

#### 全局常量宏
- 使用大写字母和下划线分隔：
  - `#define PI 3.141592653589793`
  - `#define SHADOW_RANGE 3`
  - `#define SHADOW_RADIUS 0.5`

### 2. GLSL 函数命名

#### 函数命名约定
- 使用驼峰命名法（camelCase）
- 描述性命名，清晰表达函数功能
- 示例：
  - `getBrightness(vec3 color)` - 获取亮度
  - `adjustSaturationFast(vec3 color, float s)` - 快速调整饱和度
  - `specularGGX(float NoH, float roughness)` - GGX 高光计算
  - `specularBlinnPhong(float NoH, float exponent)` - Blinn-Phong 高光计算
  - `RoughnessToExponent(float roughness)` - 粗糙度转指数
  - `saturate(float x)` - 饱和度函数（重载用于 float 和 vec3）
  - `distortShadowClipPos(vec3 shadowClipPos)` - 阴影裁剪坐标扭曲
  - `projectAndDivide(mat4 projectionMatrix, vec3 position)` - 投影和除法变换
  - `getShadow(vec3 shadowScreenPos)` - 获取阴影值
  - `getNoise(vec2 coord)` - 获取噪声值
  - `getSoftShadow(vec4 shadowClipPos, vec2 uv)` - 获取软阴影

#### 函数重载
- GLSL 支持函数重载，相同函数名但不同参数类型：
  ```glsl
  float saturate(float x)
  {
    return clamp(x, 0.0, 1.0);
  }

  vec3 saturate(vec3 x)
  {
    return clamp(x, vec3(0.0), vec3(1.0));
  }
  ```

### 3. Python 变量命名 (build.py)

- 使用下划线分隔的小写字母：
  - `FOLDER_SHADER` - Shader 目录路径
  - `FOLDER_LIB` - 库目录
  - `FOLDER_PROGRAM` - 程序目录
  - `GBUFFER_COMMON_FILE` - GBuffer 公共文件名
  - `SHADER_CONFIG` - 着色器配置字典
  - `gbuffer_programs` - GBuffer 程序列表
  - `source_file` - 源文件路径
  - `path_fsh` - 片段着色器路径

- 常量使用全大写字母和下划线：
  - `VERSION_HEADER = "#version 460 compatibility"`

### 4. 占位符命名规范
- 使用双花括号包围，全大写字母和下划线：
  - `{{SHADER_FRAG}}` - 片段着色器占位符
  - `{{SHADER_VERT}}` - 顶点着色器占位符
  - `{{SHADER_GEOM}}` - 几何着色器占位符
  - `{{SHADER_COMP}}` - Compute 着色器占位符
  - `{{RT_BACK}}` - Render Target 占位符
  - `{{IMG_BACK}}` - Image 占位符
  - `{{GLOBAL_SETTINGS}}` - 全局设置占位符

---

## 🔧 Build.py 索引列表

### PREPARE_INDEX
控制预处理 Compute Shader 的执行顺序：
```python
PREPARE_INDEX = [
    "lightingLUT",      # → prepare1.csh
    "transmitLUT",      # → prepare2.csh
    "atmosphereLUT"     # → prepare3.csh
]
```

### DEFERRED_INDEX
控制延迟渲染阶段的执行顺序：
```python
DEFERRED_INDEX = [
    "sky",              # → deferred1.csh
    "lighting",         # → deferred2.csh
    "mipmap"            # → deferred3.csh (或 .fsh/.vsh)
]
```

### COMPOSITE_INDEX
控制合成阶段的执行顺序：
```python
COMPOSITE_INDEX = [
    "mipmap",                   # → composite1.fsh/.vsh
    "lightingLUT",              # → composite2.csh
    "bloom_downsample",         # → composite3.csh
    "bloom_blur_vert",          # → composite4.csh
    "bloom",                    # → composite5.csh
    "exposure",                 # → composite6.csh
    "final"                     # → composite7.fsh/.vsh
]
```

---

## 📝 GLSL 占位符规范

### Stage 定义占位符
- `{{SHADER_FRAG}}` → `SHADER_FRAG` (片段着色器)
- `{{SHADER_VERT}}` → `SHADER_VERT` (顶点着色器)
- `{{SHADER_GEOM}}` → `SHADER_GEOM` (几何着色器)
- `{{SHADER_COMP}}` → `SHADER_COMP` (Compute Shader)

### Render Target 占位符
- `{{RT_BACK}}` → `colortex0` (Render Target 名称)
- `{{IMG_BACK}}` → `colorimg0` (Image 名称)
- `{{IMG_BACK_FORMAT}}` → `r11f_g11f_b10f` (Image 格式)

### 其他占位符
- `{{GLOBAL_SETTINGS}}` → 全局设置内容
- `{{POS_LIGHTING_LUT_VALUE}}` → `11, 0`

---

## 🚀 构建流程

1. **清理并创建目录结构**
2. **复制纹理文件** (`textures/` → `shaders/textures/`)
3. **处理 GBuffer Common** (`gbuffers_common.glsl`)
4. **自动检测 GBuffer 程序**:
   - 扫描 `program/` 目录中所有 `gbuffers_*.glsl` 文件
   - 排除 `gbuffers_common.glsl`
   - 为每个程序生成 `.fsh`、`.vsh` 和可选的 `.gsh`
5. **处理 Shadow Common** (`shadow_common.glsl`)
6. **处理 Shadow 程序** (由 `SHADOW_PROGRAMS` 列表控制)
7. **处理 Prepare/Deferred/Composite 阶段**:
   - 按索引列表顺序处理
   - 支持 `common_{feature}.glsl` 文件
   - 自动生成对应的 `.csh`、`.fsh`、`.vsh` 文件
8. **复制库文件** (`lib/` → `shaders/lib/`)
9. **复制程序文件** (`program/` → `shaders/program/`)

---

## ⚠️ 注意事项

### 文件检测规则
- **GBuffer**: 以 `gbuffers_` 开头，以 `.glsl` 结尾
- **Shadow**: 由 `SHADOW_PROGRAMS` 手动指定
- **Prepare/Deferred/Composite**: 由对应的 `*_INDEX` 列表指定
- **Common 文件**: 以 `common_` 开头，可以被多个阶段引用

### Geometry Shader 生成
- 如果源文件中包含 `{{SHADER_GEOM}}` 或 `SHADER_GEOM`，则额外生成 `.gsh` 文件
- 否则只生成 `.fsh` 和 `.vsh`

### Compute Shader 识别
- 文件名以 `_cs.glsl` 结尾的文件被视为 Compute Shader
- 生成 `.csh` 文件而非 `.fsh`/`.vsh`

### Mipmap 启用
- 在 Fragment Shader 中使用 `const bool colortexXMipmapEnabled = true;` 启用 Mipmap 生成
- X 是 render target 的索引（如 `colortex0MipmapEnabled`）

---

## 📦 Git 忽略规则

见 `.gitignore` 文件。
