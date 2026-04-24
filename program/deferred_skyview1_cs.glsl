// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/atmosphere.glsl"

uniform sampler2D {{RT_BACK}};
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform float eyeAltitude;
uniform float viewWidth;
uniform float viewHeight;

/* RENDERTARGETS: {RT_SKYVIEW} */
layout({{RT_SKYVIEW_FORMAT_IMG}}) uniform writeonly image2D {{RT_SKYVIEW_IMG}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
const vec2 workGroupsRender = vec2(0.125, 0.125);

void main()
{
    ivec2 skyRes = max(ivec2(1), ivec2(viewWidth, viewHeight) / 8);
    ivec2 pixelCoord = ivec2(gl_GlobalInvocationID.xy);
    if (any(greaterThanEqual(pixelCoord, skyRes))) {
        return;
    }

    vec2 uv = (vec2(pixelCoord) + 0.5) / vec2(skyRes);
    float depth = textureLod({{RT_BACK}}, uv, 4).r;
    if (depth < 1.0) {
        imageStore({{RT_SKYVIEW_IMG}}, pixelCoord, vec4(0.0));
        return;
    }

    vec3 clipPos = vec3(uv * 2.0 - 1.0, 1.0);
    vec3 viewPos = (gbufferProjectionInverse * vec4(clipPos, 1.0)).xyz;
    vec3 viewRay = mat3(gbufferModelViewInverse) * viewPos;

    vec3 sky = RgbFromSpectral(computeInscattering(normalize(viewRay.xzy), max((eyeAltitude - 64.0) * 0.01, 0.01)));
    imageStore({{RT_SKYVIEW_IMG}}, pixelCoord, vec4(sky, 1.0));
}
#endif
