# Bloom 金字塔降采样/升采样实现 - 改进说明

## 概述
完成了一个完整的、健壮的金字塔式Bloom实现，包括：
- ✅ 改进的降采样 (Downsample)
- ✅ 分离式高斯模糊 (Horizontal + Vertical blur)
- ✅ 金字塔升采样 (Upsample)
- ✅ 改进的最终合成

## 架构

### 执行流程 (build.py COMPOSITE_INDEX)
```
1. mipmap              → 为colortex0生成Mipmap金字塔
2. lightingLUT        → 生成光照查询表
3. bloom_downsample   → 从colortex0金字塔提取亮点，放入RT_BLOOM
4. bloom_blur_horiz   → 水平高斯模糊 (3-tap)
5. bloom_blur_vert    → 垂直高斯模糊 (3-tap)
6. bloom_upsample     → 金字塔升采样，混合不同分辨率
7. bloom              → 最终Bloom合成到输出
8. exposure           → 曝光调整
9. final              → 最终输出
```

## 详细改进

### 1. composite_bloom_downsample_cs.glsl (改进)
**目的**: 从colortex0的Mipmap金字塔中提取高亮，应用阈值

**改进内容**:
- ✅ 更好的边界采样：使用 `max()/min()` 而非条件判断
- ✅ 改进的阈值处理：使用 `smoothstep()` 实现软阈值而非硬阈值
- ✅ 数值稳定性：添加 `1e-5` epsilon 防止除以零
- ✅ 防止伪影：使用 `clamp()` 限制色值范围
- ✅ 水平预模糊：在这一pass就进行水平3-tap高斯

**关键代码**:
```glsl
// 软阈值处理
float soft = smoothstep(threshold - knee, threshold + knee, luma);
float highPass = max(0.0, luma - threshold + knee * soft);

// 防止NaN
color *= highPass / lumaSafe;
color = clamp(color, vec3(0.0), vec3(1e2));
```

### 2. composite_bloom_blur_horiz_cs.glsl (新增)
**目的**: 应用水平3-tap高斯模糊到RT_BLOOM

**特点**:
- 独立的水平模糊pass，配合垂直pass实现分离式高斯
- 稳健的边界处理：使用 `min(x+1, mipSize.x-1)` 夹值
- 对每个Mip单独进行处理
- 权重: `[0.25, 0.5, 0.25]`

### 3. composite_bloom_blur_vert_cs.glsl (改进)
**目的**: 应用垂直3-tap高斯模糊到RT_BLOOM

**改进内容**:
- ✅ 更清晰的坐标夹值逻辑
- ✅ 移除了冗余的条件判断
- ✅ 添加数值稳定性检查
- ✅ 权重: `[0.25, 0.5, 0.25]`

**金字塔布局** (水平排列):
```
┌─────────────┬──────────────┬──────────────┐
│   Mip 1     │    Mip 2     │   Mip N-2    │
│ W/2 x H/2   │  W/4 x H/4   │ W/2^N x H/2^N│
└─────────────┴──────────────┴──────────────┘
```

### 4. composite_bloom_upsample_cs.glsl (新增)
**目的**: 金字塔升采样 - 将低分辨率Mip混合回高分辨率Mip

**实现方式**:
- 对于每个Mip，查找对应的较低分辨率Mip
- 进行双线性映射（坐标变换）
- 混合：`blend = mix(currentColor, lowerColor, blendFactor)`
- 混合因子随Mip级别增加（较低分辨率贡献更大）

**优点**:
- 平滑地重建金字塔
- 防止Mipmap级别之间的不连续性
- 可控的混合强度

**代码示例**:
```glsl
// 从低分辨率Mip采样
int lowerMip = currentMip + 1;
ivec2 lowerCoord = mipCoord >> 1;  // 坐标变换
vec3 lowerColor = texelFetch(RT_BLOOM, ..., 0).rgb;

// 自适应混合
float blendFactor = 0.25 * float(currentMip - 1);
blendFactor = clamp(blendFactor, 0.0, 0.5);
currentColor = mix(currentColor, lowerColor, blendFactor);
```

### 5. composite_bloom_cs.glsl (改进)
**目的**: 最终Bloom合成 - 将处理后的Bloom混合到基础色

**改进内容**:
- ✅ 改进的权重计算：`weight = pow(0.97, float(i-1))`
- ✅ 动态归一化：`bloomSum /= totalWeight`
- ✅ 更好的混合函数：使用 `mix()` 和BLOOM_STRENGTH参数
- ✅ 数值安全：`max()` 防止负值
- ✅ Dither控制：使用BLOOM_DITHER选项参数化

**采样策略**:
- 多尺度3x3采样：从不同Mip级别采集
- 自适应权重衰减
- 总权重归一化处理

## 鲁棒性增强

### 数值稳定性
1. **防止除以零**: `max(value, 1e-4)` 和 `max(value, 1e-5)`
2. **夹值处理**: `clamp(color, vec3(0.0), vec3(1e2))`
3. **NaN防护**: 所有颜色输出都通过`max(vec3(0.0))`

### 边界处理
1. **采样边界**: 使用 `min(x, maxX)` 和 `max(x, 0)` 而非if语句
2. **Mip区域检查**: 精确的像素坐标验证
3. **纹理坐标夹值**: 所有非中心像素都被夹在有效范围内

### 伪影消除
1. **黑色条纹**: 通过robust边界夹值消除
2. **接缝**:  通过升采样的混合平滑处理
3. **过度泛滥**: 通过BLOOM_STRENGTH控制和范围夹值

## 配置参数 (lib/options.glsl)

```glsl
#define BLOOM_STRENGTH 0.5       // 最终Bloom强度 [0.00~0.50]
#define BLOOM_THRESHOLD 0.2      // 亮度阈值 [0.50~2.00]
#define BLOOM_KNEE 0.25          // 软阈值范围 [0.05~0.50]
#define BLOOM_MAX_MIPS 8         // 最多使用的Mip级别 [3~8]
#define BLOOM_DITHER 1.75        // Dither强度 [0.00~2.00]
```

## 性能特性

- **分离式模糊**: H和V分开处理，降低计算复杂度
- **局部工作组**: 8x8工作组，GPU缓存友好
- **纹理重用**: 多个pass操作同一RT_BLOOM
- **Mipmap金字塔**: GPU硬件加速生成
- **早期退出**: 对超出Mip范围的像素早期返回

## 使用建议

### 优化建议
1. 调整BLOOM_THRESHOLD获得合适的高亮提取
2. 使用BLOOM_KNEE创建平滑过渡，避免硬边缘
3. BLOOM_STRENGTH控制最终混合强度（建议0.3-0.5）
4. BLOOM_MAX_MIPS在3-8之间（8为最完整金字塔）

### 调试方法
1. 在composite_bloom_cs.glsl的imageStore之前visualize bloomSum
2. 检查各Mip级别的内容（在composite_bloom_upsample_cs后）
3. 逐个禁用pass观察效果

## 文件清单

| 文件 | 类型 | 说明 |
|------|------|------|
| composite_bloom_downsample_cs.glsl | 改进 | 提取高亮 + 水平模糊 |
| composite_bloom_blur_horiz_cs.glsl | 新增 | 水平高斯模糊pass |
| composite_bloom_blur_vert_cs.glsl | 改进 | 垂直高斯模糊pass |
| composite_bloom_upsample_cs.glsl | 新增 | 金字塔升采样混合 |
| composite_bloom_cs.glsl | 改进 | 最终合成和blending |
| build.py | 改进 | 更新COMPOSITE_INDEX启用完整管道 |

## 兼容性

- ✅ OpenGL 4.6 Compute Shader
- ✅ 支持R11F_G11F_B10F格式
- ✅ 支持动态Mipmap查询
- ✅ 与现有options/common框架兼容

## 验证步骤

1. 运行build.py生成着色器
2. 检查生成的composite*.csh文件
3. 在Minecraft加载着色包测试
4. 调整BLOOM_*参数观察效果变化
5. 验证没有视觉伪影（黑色条纹、闪烁等）
