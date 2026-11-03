# ShaderTest2 — 架构说明

> 单一真源：`build.py` 的 `RT_LIST` / `IMG_LIST` / `PIPELINE`。本文档中任何数字如与
> `build.py` 不一致，以 `build.py` 为准。

---

## 1. 目录职责

> 项目目标、允许使用的特性、档位规划与关键设计决策见 [`DESIGN_GOALS.md`](DESIGN_GOALS.md)。

```
shaders/
├── shaders.properties    Iris 属性（尺寸、blend、sliders、派生的自定义 uniform）
├── settings.glsl         Iris 内建常量（sunPathRotation、shadowMapResolution…）
├── options.glsl          用户可调宏（sliders 必须与此处一致）
├── lib/                  只有 include，禁止 main()、禁止 Iris uniform 声明
│   ├── prelude.glsl      唯一入口（settings → options → math → rt_formats）
│   ├── rt_formats.glsl   由 build.py 生成，勿手改
│   ├── utility/          math, color
│   ├── universal/        buffers（SSBO 声明）
│   ├── lighting/         brdf, shadow, tuning
│   └── atmosphere/       constants, geometry, phase, medium,
│                         transmittance, scattering, skyview, scene, all
├── program/              一个 stage 一个实现（可含 frag/vert/geom 多段）
│   ├── gbuffers/  shadow/  setup/  prepare/  deferred/  post/
├── world0/               【生成】Iris 槽位薄壳，不入库
└── textures/             随包资源（textures/projects/ 为制作工程，不进包）
```

构建：`python build.py` → 清空并重建 `<shaderpacks>/ShaderTest2/shaders/`。
构建只做两件事：**按路径 1:1 复制 + 占位符替换**、**生成 `world0/` 薄壳**。

---

## 2. 缓冲区

### 2.1 Render target（colortex）

| 槽 | 名称 | 格式 | 相对尺寸 | 写入者 | 读取者 |
|---|---|---|---|---|---|
| 0 | `RT_ALBEDO` | RGBA8 | 1.0 | gbuffers | deferred2 |
| 1 | `RT_NORMAL` | RGBA8 | 1.0 | gbuffers | deferred2 |
| 2 | `RT_SPECULAR` | RGBA8 | 1.0 | — | — | **保留通道（labPBR），当前不写入** |
| 3 | `RT_LIGHTMAP` | RGBA16F | 1.0 | gbuffers | deferred2 |
| 4 | `RT_VERTEX_LIGHT` | RGBA8 | 1.0 | — | — | **保留通道（顶点低频光照），当前不写入** |
| 5 | `RT_HDR` | RGBA16F | 1.0 | deferred2 | composite1、post 全链 |
| 6 | `RT_LUM` | RG16F | 0.03125 | composite1 | composite2 |
| 7 | `RT_BLOOM1` | RGBA16F | 0.5 | composite3、composite16 | final |
| 8 | `RT_BLOOM2` | RGBA16F | 0.25 | composite4、composite15 | composite14 |
| 9 | `RT_BLOOM3` | RGBA16F | 0.125 | composite5、composite14 | composite13 |
| 10 | `RT_BLOOM4` | RGBA16F | 0.0625 | composite6、composite13 | composite12 |
| 11 | `RT_BLOOM5` | RGBA16F | 0.03125 | composite7、composite12 | composite11 |
| 12 | `RT_BLOOM6` | RGBA16F | 0.015625 | composite8、composite11 | composite10 |
| 13 | `RT_BLOOM7` | RGBA16F | 0.0078125 | composite9、composite10 | composite9 |
| 14 | `RT_BLOOM8` | RGBA16F | 0.00390625 | composite10 | composite11 |

> Bloom 级数由 `build.py` 的 `BLOOM_LEVELS` 决定（当前 8）；缓冲、pass、本表都随之变化。
> 每级缓冲在 Iris 里会被 buffer flip 复制一份，8 级合计约占屏幕面积的 1/3。

G-buffer 写入布局：`RENDERTARGETS = RT_ALBEDO, RT_NORMAL, RT_LIGHTMAP`。
`RT_LIGHTMAP` 通道：`.r` 方块光 / `.g` 天光 / `.b` AO。

### 2.2 Custom image

| 名称 | 格式 | 尺寸 | 用途 |
|---|---|---|---|
| `IMG_TRANSMIT_LUT` | RGBA16F | 256×64 | 大气 transmittance LUT |
| `IMG_SKYVIEW` | RGBA16F | 512×256 | sky-view LUT（360°×仰角，含按 `SUN_DISC_RENDER_SCALE` 缩放后的太阳盘） |
| `IMG_SKY` | RGBA16F | 1/8 屏幕 | 天空 inscattering（tile 剔除后） |

### 2.3 SSBO

`ExposureBlock { float exposure; }`，binding 0，`bufferObject.0 = 4`（1 个 float）。
声明位置：[`shaders/lib/universal/buffers.glsl`](../shaders/lib/universal/buffers.glsl)。

---

## 3. Pass 顺序

| 槽位 | 源文件 | stage | 读 | 写 |
|---|---|---|---|---|
| `setup1` | `program/setup/exposure_init_cs.glsl` | comp | — | ExposureBlock |
| `prepare1` | `program/prepare/transmittance_lut_cs.glsl` | comp | — | IMG_TRANSMIT_LUT |
| `prepare2` | `program/prepare/skyview_cs.glsl` | comp | IMG_TRANSMIT_LUT | IMG_SKYVIEW |
| `shadow.*` | `program/shadow/shadow.glsl` | frag+vert | — | shadowtex0/1 |
| `deferred1` | `program/deferred/sky_cs.glsl` | comp | depthtex0, LUT | IMG_SKY |
| `deferred2` | `program/deferred/lighting_cs.glsl` | comp | gbuffer, shadow, IMG_SKY, LUT | RT_HDR |
| `composite1` | `program/post/exposure/measure_cs.glsl` | comp | RT_HDR | RT_LUM |
| `composite2` | `program/post/exposure/adapt_cs.glsl` | comp | RT_LUM | ExposureBlock |
| `composite3..10` | `program/post/bloom/downsample_cs.glsl` | comp | RT_HDR → BLOOMn | BLOOMn+1（先乘曝光，转显示参考空间） |
| `composite11..17` | `program/post/bloom/upsample_cs.glsl` | comp | BLOOMn+1 | BLOOMn（累加） |
| `final` | `program/post/final.glsl` | frag+vert | RT_HDR, BLOOM1, ExposureBlock | 背缓冲（屏幕） |

`downsample` / `upsample` 各只有一个源文件，靠薄壳注入的 `BLOOM_LEVEL` 区分槽位
（见 `build.py` 的 `Pass.defines`）。级别由 `BLOOM_LEVELS` 生成，因此串联 8 级时
downsample 占 8 个槽位（`BLOOM_LEVEL 0..7`）、upsample 占 7 个（`BLOOM_LEVEL 7..1`）。

```
    gbuffers ─┐                        ┌─> composite1 measure ─> composite2 adapt ─┐
              ├─> shadow ─> deferred2 ─┼─> composite3..10 downsample               ├─> final
    deferred1 ┘   (sky, 1/8)   RT_HDR  └─> composite11..17 upsample ───────────────┘
```

---

## 4. 关键算法位置

| 主题 | 位置 |
|---|---|
| 大气物理参数（含单位/来源） | `lib/atmosphere/constants.glsl` |
| 单次散射积分 + 多重散射双项近似（地面反弹 + 迎光解析叶） | `lib/atmosphere/scattering.glsl` |
| transmittance LUT 生成/查询 | `lib/atmosphere/transmittance.glsl` |
| 天空 1/8 分辨率 tile 剔除 | `program/deferred/sky_cs.glsl` |
| 假 GI（中档）、环境光、Cook-Torrance 高光 | `program/deferred/lighting_cs.glsl` + `lib/lighting/tuning.glsl` |
| 软阴影 PCF | `lib/lighting/shadow.glsl` |
| 曝光（对数平均 + 中心权重） | `program/post/exposure/{measure,adapt}_cs.glsl`，参数见 `lib/lighting/tuning.glsl` |
| Bloom（13-tap 降 / tent 上，8 级） | `program/post/bloom/{downsample_cs,upsample_cs}.glsl`，分级依据见 [`DESIGN_GOALS.md`](DESIGN_GOALS.md) §4 |
| 色调映射 / 暗角 | `program/post/final.glsl` |

**单位约定**：见 [`DESIGN_GOALS.md`](DESIGN_GOALS.md) §6。距离 km、系数 1/km、辐亮度与辐照度都以 `NITS_PER_UNIT`（200 cd/m²）为单位。所有 HDR 缓冲都是 16 位浮点。太阳盘物理辐亮度是 8e6 单位，超出半浮点上限 65504，因此写入缓冲时乘 `SUN_DISC_RENDER_SCALE`（1/256 → 3.1e4 单位）；bloom 源另有 `BLOOM_SOURCE_CEILING`（4096）兜底，防止高曝光下溢出成 inf 污染模糊链。

**调参入口**：

- 用户可见（slider）：`shaders/options.glsl` + `shaders/shaders.properties` 的 `sliders`
- 外观微调（不暴露给用户）：`lib/lighting/tuning.glsl`
- 物理常量：`lib/atmosphere/constants.glsl`

---

## 5. 保留通道（请勿当成死代码删除）

| 通道 | 规划用途 | 现状 |
|---|---|---|
| `RT_SPECULAR` | labPBR 高光 / 粗糙度 | 已分配、无写入者；`gbuffers/common.glsl` 的 labPBR 分支待恢复 |
| `RT_VERTEX_LIGHT` | G-buffer 顶点低频光照（环境光等），由 gbuffers 顶点阶段写入 | 已分配、无写入者 |
| `block.properties` / `entity.properties` | labPBR 材质 ID | 尚未创建 |

启用 labPBR 时需要同时改动：`gbuffers/common.glsl`（写 `RT_SPECULAR`）、
`program/deferred/lighting_cs.glsl`（读取并使用）、`shaders.properties`（材质 uniform）。

---

## 6. 已知缺陷 / 未完成

1. **水面 pass 的输出被丢弃**：`program/gbuffers/water.glsl` 写 `RT_HDR`，但 `deferred2` 会为**每个**像素覆写
   `RT_HDR`，所以水面反射实际不显示。修法：改为在 deferred 阶段按深度/掩码合成，或写独立 G-buffer 通道。
2. **顶点光照通道未实现**：`RT_VERTEX_LIGHT` 空转（见 §5）。
3. **只有主世界**：`build.py` 只生成 `world0/`；下界/末地需新增 `world-1/`、`world1/` 的生成逻辑。
4. **无画质档位**：当前参数即"**中档**"（见 [`DESIGN_GOALS.md`](DESIGN_GOALS.md) §3）；
   `shaders.properties` 尚未定义 `profile.*`，低/高/影视档位待补。
5. **构建器硬编码路径**：`build.py` 顶部的 `SHADERPACK` 指向本机 Minecraft 目录，换机器需修改。
6. **纹理未清理**：`textures/` 中 `caustic_*`、`cloud_coverage`、`moon*`、`rain_ripples_n` 目前无引用。
7. **exposure / bloom 参数为经验值**：`EXPOSURE_ADAPT_RATE`、`BLOOM_STRENGTH`、
   `BLOOM_SPREAD`、`BLOOM_THRESHOLD_SMOOTH` 等未做画面标定。

---

## 7. 修改检查清单

改动 `build.py` 的注册表后，运行 `python build.py`，然后确认：

- 输出包中不存在未替换的 `{{`（构建器已内置一条检查）
- `world0/` 里每个槽位都有对应的 `.csh/.fsh/.vsh/.gsh`
- 新增的缓冲在 `shaders.properties` 里有 `size.buffer.colortexN`
- 若新增 slider：`options.glsl` 的宏名与 `sliders` 列表一致
