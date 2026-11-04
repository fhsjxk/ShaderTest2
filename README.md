# ShaderTest2

一个面向 Minecraft Java 版（Iris）的着色器包源码仓库。

**目标：下限极低、上限极高、几乎完全写实。** 低画质档要在低配机器上流畅运行，
高画质档要能用上平台的全部特性达到影视级效果。详细的目标、可用特性清单、
档位规划与关键设计决策见 [`docs/DESIGN_GOALS.md`](docs/DESIGN_GOALS.md)。
当前仓库的参数集合视为**中档**。

已经定下方案但尚未实现的设计（水面平面反射、水底焦散、体积雾、3D 大气 LUT、
瑞利相位混合、FSR3 超分、星空与银河）见 [`docs/DESIGN_IDEAS.md`](docs/DESIGN_IDEAS.md)。

**仓库的 `shaders/` 目录与最终 shaderpack 的 `shaders/` 一一对应**：同样的路径、同样的文件名。
`build.py` 只做两件事——按路径 1:1 复制并替换占位符、生成 `world0/` 的 Iris 槽位薄壳。
所以「在仓库里看到的文件」与「游戏里加载的文件」是一一可追溯的。

---

## 快速开始

### 环境

- Python 3.10+（`build.py` 使用了 `X | None` 语法）
- Minecraft + Iris（开发目标是 1.21.x）

### 构建

1. 修改 `build.py` 顶部的输出路径（换机器时必须改）：

   ```python
   SHADERPACK = Path("E:/Minecraft/.minecraft/versions/1.21.11-Fabric/shaderpacks/ShaderTest2/shaders/")
   ```

2. 运行：

   ```
   python build.py
   ```

   该命令会**清空并重建**输出目录，然后写入全部着色器。

3. 进入游戏，在「视频设置 → 着色器包」中选 `ShaderTest2`。
   调试时建议同时观察 `<shaderpacks>/ShaderTest2/shaders/world0/` 下生成的入口文件。

> 输出目录是构建产物，不要在里面手改——下次构建会被覆盖。

---

## 目录

```
build.py                 开发期构建器（模板替换 + 薄壳生成）
docs/DESIGN_GOALS.md     项目目标、允许的特性、档位规划、关键决策  ← 先读这个
docs/ARCHITECTURE.md     缓冲区表、pass 表、保留通道、已知缺陷
docs/DESIGN_IDEAS.md     已定方案但未实现的设计（含 DeepSeek 对话索引）
docs/DEV_NOTES.md        源码中文注释盘点与待清理项
docs/VOLUMETRIC_CLOUD_EVAL.md  体积云"神经网络代理光照"方案评估与推进顺序
NAMING_CONVENTION.md     命名与文件分类规范（含占位符体系）
shaders/                 与包同构的源码树
  lib/                   纯函数库，按域分目录
  program/               pass 实现，按管线阶段分目录
  world0/                【生成】薄壳，不入库
  textures/              随包资源
```

---

## 新增一个 pass

1. 在 `shaders/program/<阶段>/` 新建实现文件，例如 `program/post/my_pass_cs.glsl`
   （计算阶段用 `_cs` 后缀；frag/vert 共用文件写成多段，用 `// {{SHADER_FRAG}}` 标记分段）。
2. 文件开头引入唯一入口：`#include "/lib/prelude.glsl"`，再按需引入其他库。
3. 若需要新的缓冲：在 `build.py` 的 `RT_LIST` 里加一项（格式 + 相对尺寸），
   然后才能使用 `{{RT_<NAME>}}` / `_IMG` / `_SLOT` / `_FORMAT` / `_SIZE_X` 这些占位符。
4. 在 `build.py` 的 `PIPELINE` 里插入一个 `Pass`（顺序即执行顺序）：

   ```python
   Pass("composite13", "program/post/my_pass_cs.glsl", ("comp",)),
   ```

   一个源文件服务多个槽位时，用 `defines` 传差异，例如 `("MY_LEVEL 2",)`。
5. 运行 `python build.py`，确认 `world0/` 出现对应槽位文件。
6. 若该 pass 需要用户可调的参数，见下一节。

> 槽位名必须符合 Iris 的命名（`setup1`、`prepare1`、`deferred1`、`composite1..12` 等）。

---

## 新增一个可调选项

1. 在 `shaders/options.glsl` 增加 `#define`，行尾用 Iris 语法给出可选值：

   ```glsl
   #define MY_OPTION 1.0 // [0.0 0.5 1.0 1.5 2.0]
   ```

2. 把宏名加入 `shaders/shaders.properties` 的 `sliders` 列表，否则 UI 不会显示。
3. 在代码里直接使用该宏（所有 `program/` 都会经 `prelude.glsl` 拿到 `options.glsl`）。

---

## 占位符

`build.py` 在构建时替换 `{{...}}`。只有 **Iris 在宏替换前读取**的东西才需要占位符
（`RENDERTARGETS` 注释、`layout(...)` 格式、`colortexN`/`colorimgN` 名字、properties 里的尺寸）。
其余一律用 `#define` / `const`。

完整清单见 [`NAMING_CONVENTION.md`](NAMING_CONVENTION.md) 的「E. 模板占位符」。

---

## 约定

- 缩进 4 空格、Allman 大括号、CRLF（见 `.editorconfig`）。
- `lib/` 内不得出现 `main()`，不得声明 Iris uniform。
- 不要在代码里写裸 `colortexN`；使用占位符。
- 保留通道（`RT_SPECULAR`、`RT_VERTEX_LIGHT`）不要当死代码删除，见 `docs/ARCHITECTURE.md` §5。

---

## 已知问题

见 [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) §6。当前最需要注意的是**水面 pass 的输出会被
`deferred2` 覆盖**，因此水面反射实际不显示。

---

## 许可

尚未指定。仓库目前没有 `LICENSE` 文件，发布前需要补充。
