// SHADER_COMP
#ifdef SHADER_COMP
#include "/lib/common.glsl"
#include "/lib/options.glsl"

uniform float frameTime;
uniform sampler2D colortex0;
uniform sampler2D colortex6;

layout(rgba16f) uniform writeonly image2D colorimg6;
layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(1, 1, 1);

void main()
{
    barrier();
    int level = max(textureQueryLevels(colortex0) - 2, 0);
    float prevValue = texelFetch(colortex6, ivec2(11, 0), 0).r;
    float currentValue = getBrightness(textureLod(colortex0, vec2(0.5), level).rgb);
    float nextValue = mix(prevValue, pow(currentValue, 0.7), frameTime * 1.0);
    imageStore(colorimg6, ivec2(11, 0), vec4(nextValue, 0.0, 0.0, 1.0));
}
#endif
