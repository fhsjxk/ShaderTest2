// {{SHADER_COMP}}
#ifdef {{SHADER_COMP}}
#include "/lib/prelude.glsl"
#include "/lib/lighting/brdf.glsl"
#include "/lib/lighting/tuning.glsl"
#include "/lib/utility/color.glsl"
#include "/lib/lighting/shadow.glsl"
#include "/lib/atmosphere/all.glsl"

uniform sampler2D depthtex0;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D noisetex;
uniform sampler2D {{RT_ALBEDO}};
uniform sampler2D {{RT_NORMAL}};
uniform sampler2D {{RT_LIGHTMAP}};
uniform sampler2D {{RT_HDR}};
uniform sampler2D {{IMG_SKY_SAMPLER}};
uniform sampler2D {{IMG_TRANSMIT_LUT_SAMPLER}};

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 sunDirection;
uniform float eyeAltitude;
uniform float viewWidth;
uniform float viewHeight;

// 注意很多值都可以从vs/ps等转移到cpu端计算的uniform比如sunDirection，尽量这么做以优化性能
// 仓库里有两个iris文档，其中一个似乎较老，有不适用的，发现后记录下来
// 星星渲染实际早已实现，下一步迭代到对话中的优化方法渲染

// TODO：TAA，此处只是记录，不代表在这个pass中
// TODO：草地（不是草本身，是草方块的草即草方块顶面）会有高光的backscatter，后期需要实现
// TODO：使用GS生成精灵来渲染的镜头光晕，这包含在那份对话中
// TODO：使用orennayar渲染的月亮，月亮贴图和法线贴图在资源中
// TODO：下雨的积水动画，法线贴图在资源中
// TODO：shaders\textures\projects有各种设想
// TODO：GTAO
// TODO：这些TODO不一定是对于这个文件的
// TODO：没有且不会有正经的光线追踪，但是会作为各类光线追踪模组的shaderpack发布
// TODO：floodfill或其它算法再光线步进做的体素体积光，给光源用，太阳的用光线步进和shadowmap，体素信息要从shadow pass获取
// TODO：体积云之类的体积光照得半分辨率甚至更底，然后深度感知上采样，或者用可变速率渲染，需要taa
// TODO：延迟pass里的天空渲染也是在地平线处有Aliasing，可以使用可变速率渲染
// TODO：需要在某个文件中暴露各种噪声算法
// TODO：高频法线贴图导致bloom闪烁的可能，有现有解决方法（过滤？）
// TODO：可以提高skyview的分辨率，减低spp然后通过时域计算补充

layout({{RT_HDR_FORMAT}}) uniform writeonly image2D {{RT_HDR_IMG}};
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
const vec2 workGroupsRender = vec2(1.0, 1.0);

void main()
{
    ivec2 pixelCoordinate = ivec2(gl_GlobalInvocationID.xy);
    ivec2 fullResolution = ivec2(viewWidth, viewHeight);
    if (any(greaterThanEqual(pixelCoordinate, fullResolution)))
    {
        return;
    }

    vec2 uv = (vec2(pixelCoordinate) + 0.5) / vec2(viewWidth, viewHeight);
    float depth = texelFetch(depthtex0, pixelCoordinate, 0).r;
    vec2 clipXY = uv * 2.0 - 1.0;
    vec3 viewRay = mat3(gbufferModelViewInverse) * (gbufferProjectionInverse * vec4(clipXY, 1.0, 1.0)).xyz;

    // Transmittance from the eye towards the sun; converts the extraterrestrial
    // irradiance into the irradiance reaching the scene.
    float eyeRadius = PLANET_RADIUS_KM + altitudeFromEyePosition(eyeAltitude);
    vec34 sunTransmittance = transmittanceFromLUT({{IMG_TRANSMIT_LUT_SAMPLER}}, eyeRadius, clamp(sunDirection.y, -1.0, 1.0));
    #ifdef ENABLE_SPECTRAL
    sunTransmittance.rgb = rgbFromSpectral(sunTransmittance) * 0.2;
    #endif

    if (depth == 1.0)
    {
        vec3 viewDir = normalize(viewRay);
        vec34 trans = transmittanceFromLUT({{IMG_TRANSMIT_LUT_SAMPLER}}, eyeRadius, clamp(viewRay.y, -1.0, 1.0));
        #ifdef ENABLE_SPECTRAL
        trans.rgb = rgbFromSpectral(trans) * 0.2;
        #endif

        vec3 stars = texelFetch({{RT_HDR}}, pixelCoordinate, 0).rgb * trans.rgb;

        vec3 dither = (getNoise(noisetex, uv, vec2(viewWidth, viewHeight)).rgb - 0.5) * 0.03;
        vec3 sky = texture({{IMG_SKY_SAMPLER}}, uv).rgb;
        sky = sky * (1.0 + dither) + dither * 0.01;
        sky += stars;

        // Solar disc, attenuated by the same transmittance as the direct beam and
        // shaded with the limb-darkening profile. One output pixel in rho units
        // comes from the projection, so the limb's antialiasing follows the
        // resolution: the disc is only ~8 px wide at 1080p.
        float sunCosAngle = dot(viewDir, normalize(sunDirection));
        //float rhoPerPixel  = (2.0 * max(gbufferProjectionInverse[1][1], EPS) / viewHeight) / SUN_ANGULAR_RADIUS_RAD;
        sky += sunDiscMask(sunCosAngle) * SUN_DISC_RENDER_RADIANCE * trans.rgb;

        // The `stars` block reads this buffer back, so a non-finite pixel here
        // would be carried forward forever. Guarded per GUARD_LEVEL: the
        // half-float ceiling is clamped, NaN is left visible at the default
        // level because it is the bug itself.
        sky = guardHalf(sky);

        imageStore({{RT_HDR_IMG}}, pixelCoordinate, vec4(sky, 1.0));
        return;
    }

    vec3 albedo   = texelFetch({{RT_ALBEDO}}, pixelCoordinate, 0).rgb;
    vec4 normal   = texelFetch({{RT_NORMAL}}, pixelCoordinate, 0);
    vec4 lightmap = texelFetch({{RT_LIGHTMAP}}, pixelCoordinate, 0);


    // 注意现在各处会散落这类注释，看到后记入一个md中整理
    // 注意现在各处会散落这类注释，看到后记入一个md中整理
    // 注意现在各处会散落这类注释，看到后记入一个md中整理
    // 注意现在各处会散落这类注释，看到后记入一个md中整理
    // 注意现在各处会散落这类注释，看到后记入一个md中整理

    // 这里阴影相关的一大片都是从某个示例里抄来的，也是临时实现，后期需要重构/重写，要添加pcss和各种pcf参数调整以及优化性能和效果，比如硬件pcf和阴影边缘的余弦衰减

    // 注意现在各处会散落这类注释，看到后记入一个md中整理
    // 注意现在各处会散落这类注释，看到后记入一个md中整理
    // 注意现在各处会散落这类注释，看到后记入一个md中整理
    // 注意现在各处会散落这类注释，看到后记入一个md中整理
    // 注意现在各处会散落这类注释，看到后记入一个md中整理

    vec3 NDCPosition = vec3(clipXY, depth * 2.0 - 1.0);
    vec3 viewPosition = projectAndDivide(gbufferProjectionInverse, NDCPosition);
    vec3 feetPlayerPosition = (gbufferModelViewInverse * vec4(viewPosition, 1.0)).xyz;
    vec3 shadowViewPosition = (shadowModelView * vec4(feetPlayerPosition, 1.0)).xyz;
    vec4 shadowClipPosition = shadowProjection * vec4(shadowViewPosition, 1.0);

    vec3 shadow = getSoftShadow(shadowtex0, shadowtex1, shadowcolor0, noisetex, shadowClipPosition, uv, vec2(viewWidth, viewHeight));

    vec3 N = normalize(normal.xyz * 2.0 - 1.0);
    vec3 V = mat3(gbufferModelViewInverse) * normalize(-viewPosition);
    vec3 L = normalize(sunDirection);

    // normal.a and normal.a again from the gbuffer: .a holds N.L against the sun
    // as computed in the vertex stage, the shadow map adds occlusion.
    float NdotL = max(normal.a, 0.0);
    float sunVisibility = min(normal.a, float(shadow));
    float NdotV = max(dot(N, V), EPS);

    // ── Direct sun ──────────────────────────────────────────
    // Irradiance on the surface (units) = extraterrestrial irradiance * T.
    vec34 sunIrradiance = SUN_IRRADIANCE * sunTransmittance;
    #ifdef ENABLE_SPECTRAL
    vec3 sunIrradianceRGB = rgbFromSpectral(sunIrradiance);
    #else
    vec3 sunIrradianceRGB = sunIrradiance;
    #endif

    // Cook-Torrance specular: F0 * E * cos(theta) with the full BRDF.
    vec3 specular = specularBRDF(N, V, L, SURFACE_ROUGHNESS, SURFACE_F0, SURFACE_F90)
                  * sunIrradianceRGB * sunVisibility * NdotL;

    // ── Sky and block light ─────────────────────────────────
    // Lightmap .g is skylight, .b is ambient occlusion, .r is block light.
    float skyVisibility = lightmap.g * lightmap.b;
    float blockLight    = lightmap.r;

    // ── Fake GI (medium quality tier) ───────────────────────
    // A real GI solution would add light bounced off nearby surfaces. This stands
    // in for it using the cheapest available signal: how much sky and sun the
    // surface is missing. Higher quality tiers replace this with a physical
    // solution, so the whole approximation is confined to this block.
    float missingLight = (1.0 - skyVisibility) * (1.0 - NdotL) * float(shadow);
    // 这些中文注释仅作开发的临时注释，最终不需要
    float fakeGI = 1.0 + FAKE_GI_GAIN * missingLight; // 假gi只在较低预设下使用，高预设不用，所以需要宏包住

    // The bounce light carries the colour of its surroundings, which reads as a
    // small saturation lift where the fake GI term is strongest.
    float fakeGISaturation = max(1.0 + FAKE_GI_SATURATION * (fakeGI - 1.0), EPS);
    vec3 surfaceAlbedo = adjustSaturationFast(albedo, fakeGISaturation);

    vec3 skyIrradiance   = vec3(nitsToUnits(SKY_ILLUMINANCE_LUX)) * skyVisibility * vec3(0.4, 0.6, 1.0); // 临时的值，后面使用球谐光或者ibl代替
    vec3 blockIrradiance = vec3(nitsToUnits(BLOCK_LIGHT_ILLUMINANCE_LUX)) * blockLight; // 方块光照也是临时的

    // 这个shaderpack的很多地方都是临时的，不是最终的，同时也有很多magicnumber，继续编写时需要注意这个，一旦发现疑似临时的东西先不要动或者继续写，先报告

    // Lambertian diffuse: L = albedo/pi * E * cos(theta).
    vec3 diffuse = albedo * INV_PI * sunIrradianceRGB * sunVisibility * fakeGI;

    vec3 ambient = surfaceAlbedo * INV_PI * (skyIrradiance + blockIrradiance);

    vec3 outColor = diffuse + specular + ambient;

    // Nothing non-finite may reach RT_HDR: one NaN poisons the exposure measure
    // (log2 of it) and bloom turns it into a full-brightness dot, because min()
    // returns the *other* operand for a NaN on some drivers. Guarded per
    // GUARD_LEVEL -- the half-float ceiling is clamped, NaN is left to show.
    outColor = guardHalf(outColor);

    imageStore({{RT_HDR_IMG}}, pixelCoordinate, vec4(outColor, 1.0));
}
#endif
