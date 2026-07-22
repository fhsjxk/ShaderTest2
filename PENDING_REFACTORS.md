# 待实现：IMG_SKY → RT_HALF 重构

## 目标
- IMG_SKY 改为 RT_HALF（RT，支持 mipmap），尺寸 0.125×0.125
- 延迟光照后覆写为场景颜色（天空已合成进 RT_BACK）
- Mipmap 供曝光归约 + bloom 图集使用
- 曝光值在 composite_final 中应用（SSBO），消除跨工作组竞态

## 改动清单

### build.py
- [ ] RT_LIST 新增 `RT("RT_HALF", "R11F_G11F_B10F", size="0.125 0.125")`
- [ ] IMG_LIST 删除 `IMG("IMG_SKY", ...)`
- [ ] PIPELINE composite 插入：
  - `"half"` → RT_BACK mip1 → RT_HALF（全色降采样）
  - `"mipmap_half"` → RT_HALF mip 生成
  - 在 bloom_atlas 之前

### deferred_sky_cs.glsl
- [ ] `{{IMG_SKY_FORMAT}}` → `{{IMG_HALF_FORMAT}}`
- [ ] `{{IMG_SKY}}` → `{{IMG_HALF}}`

### deferred_lighting_cs.glsl
- [ ] `{{IMG_SKY_SAMPLER}}` → `{{RT_HALF}}`

### 新建 composite_half_cs.glsl
- [ ] RT_BACK mip1 → RT_HALF（全色，无处理）

### 新建 common_mipmap_half.glsl
- [ ] 复制 common_mipmap，RENDERTARGETS 改为 `{RT_HALF}`

### composite_exposure_cs.glsl
- [ ] 改为单工作组归约（1 workgroup）
- [ ] 读 RT_HALF 倒二 mip → sqrt(lum) × centerWeight → shared memory → SSBO
- [ ] 不再写 RT_BACK

### composite_final.glsl
- [ ] 读 `lightingLut.value` → 曝乘
- [ ] `color.rgb = pow(aces(color.rgb * exposure), 1/2.2)`

### bloom_atlas + bloom_blur_h/v + bloom_cs
- [ ] 改为读 RT_HALF 各 mip（替代原 RT_BACK）
- [ ] UV 计算适配新分辨率（1/8 或 1/4）

## 数据流
```
deferred_sky       → RT_HALF (天空 RGB)
deferred_lighting  → 读 RT_HALF → 合成到 RT_BACK
composite_half     → RT_BACK mip1 → RT_HALF (覆写为场景)
mipmap_half        → RT_HALF mip 链 (240→...→1)
bloom_*            → 读 RT_HALF mips → RT_BLOOM
exposure           → 读 RT_HALF 倒二 mip → SSBO
final              → 读 SSBO → 应用曝光
```

## 注意事项
- RT_HALF 倒二 mip 约 21 像素（手动 `mipLevel = max(0, levels - 2)`）
- fragment shader 在 CS dispatch 后执行，天然消除跨工作组竞态
