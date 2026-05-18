#!/bin/bash
cd E:\Users\qwert\Desktop\ShaderTest\ShaderTest2.worktrees\agents-pyramid-resampling-bloom-enhancement
git add program/composite_bloom*.glsl build.py BLOOM_IMPROVEMENTS.md COMPLETION_REPORT.md
git commit -m "feat: Complete pyramid bloom pyramid resampling with enhanced robustness" \
  -m "Implement comprehensive bloom pipeline:

- Add composite_bloom_blur_horiz_cs.glsl: Horizontal Gaussian blur pass
- Add composite_bloom_upsample_cs.glsl: Pyramid upsampling and mip blending
- Improve composite_bloom_downsample_cs.glsl: Soft threshold, edge clamping, numerical stability
- Improve composite_bloom_blur_vert_cs.glsl: Clarified coordinate clamping
- Improve composite_bloom_cs.glsl: Adaptive weight decay and proper normalization
- Update build.py: Enable complete bloom pipeline in COMPOSITE_INDEX

Key enhancements:
* Separable Gaussian blur (H and V passes) for better efficiency
* Full pyramid reconstruction via upsampling and blending
* Robust numerical stability with epsilon protection
* Smart edge clamping eliminates black stripe artifacts
* Soft threshold processing for smooth highlight extraction
* Adaptive mip-level blending for seamless pyramid

Documentation:
* BLOOM_IMPROVEMENTS.md: Detailed technical documentation
* COMPLETION_REPORT.md: Implementation summary and validation

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
echo "Commit completed"
git log --oneline -1
