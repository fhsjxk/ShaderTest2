// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/atmosphere.glsl"

uniform sampler2D depthtex0;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform float eyeAltitude;
uniform float viewWidth;
uniform float viewHeight;

/* RENDERTARGETS: {RT_SKYVIEW} */
layout({{RT_SKYVIEW_FORMAT_IMG}}) uniform writeonly image2D {{RT_SKYVIEW_IMG}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
const vec2 workGroupsRender = vec2(0.125, 0.125);

bool tileHasSky(ivec2 tileMin, ivec2 fullRes)
{
    ivec2 tileMax = min(tileMin + ivec2(7), fullRes - ivec2(1));
    ivec2 c = (tileMin + tileMax) / 2;

    float d0 = texelFetch(depthtex0, tileMin, 0).r;
    float d1 = texelFetch(depthtex0, ivec2(tileMax.x, tileMin.y), 0).r;
    float d2 = texelFetch(depthtex0, ivec2(tileMin.x, tileMax.y), 0).r;
    float d3 = texelFetch(depthtex0, tileMax, 0).r;
    float d4 = texelFetch(depthtex0, c, 0).r;

    return max(max(max(d0, d1), max(d2, d3)), d4) >= 1.0;
}

void main()
{
    ivec2 fullRes = ivec2(viewWidth, viewHeight);
    ivec2 skyRes = max(ivec2(1), (fullRes + ivec2(7)) / 8);
    ivec2 pixelCoord = ivec2(gl_GlobalInvocationID.xy);
    if (any(greaterThanEqual(pixelCoord, skyRes))) {
        return;
    }

    ivec2 tileMin = min(pixelCoord * 8, fullRes - ivec2(1));
    if (!tileHasSky(tileMin, fullRes)) {
        imageStore({{RT_SKYVIEW_IMG}}, pixelCoord, vec4(0.0));
        return;
    }

    vec2 uv = (vec2(pixelCoord) + 0.5) / vec2(skyRes);
    vec3 clipPos = vec3(uv * 2.0 - 1.0, 1.0);
    vec3 viewPos = (gbufferProjectionInverse * vec4(clipPos, 1.0)).xyz;
    vec3 viewRay = mat3(gbufferModelViewInverse) * viewPos;

    vec3 sky = RgbFromSpectral(computeInscattering(normalize(viewRay.xzy), max((eyeAltitude - 64.0) * 0.01, 0.01)));
    imageStore({{RT_SKYVIEW_IMG}}, pixelCoord, vec4(sky, 1.0));
}
#endif
