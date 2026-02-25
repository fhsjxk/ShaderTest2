// {{SHADER_FRAG}}
#ifdef {{SHADER_FRAG}}
#include "/lib/common.glsl"
#include "/lib/options.glsl"

uniform sampler2D {RT_BACK};
uniform sampler2D {RT_LIGHTING_LUT};
uniform sampler2D vignettetex;

#ifdef DEBUG_VIEW
uniform sampler2D {RT_BASE_COLOR};
uniform sampler2D {RT_NORMAL};
uniform sampler2D {RT_LIGHTING0};
#endif

in vec2 texcoord;

layout(location = 0) out vec4 color;

// LOCAL SETTINGS


vec3 aces(vec3 x) {
    const float a = 2.57;
    const float b = 0.637;
    const float c = 2.66;
    const float d = 0.0;
    const float e = 1.2;
    return (x * (a * x + b)) / (x * (c * x + d) + e);
}

void main()
{
    ivec2 pixelCoord = ivec2(gl_FragCoord.xy);
    //float value = texelFetch({RT_LIGHTING_LUT}, ivec2({{POS_LIGHTING_LUT_VALUE}}), 0).r;
    //color.rgb = pow(aces(texelFetch({RT_BACK}, pixelCoord, 0).rgb / mix(value, 1.0, 0.03) / 2.0), vec3(1.0/2.2));
    color.rgb = pow(aces(texelFetch({RT_BACK}, pixelCoord, 0).rgb), vec3(1.0/2.2));
    #ifdef VIGNETTE_AMOUNT != 0.0
    float vignetteMask = texture(vignettetex, texcoord).r * VIGNETTE_AMOUNT + (1.0 - VIGNETTE_AMOUNT);
    color.rgb *= vignetteMask;
    #endif

    #ifdef DEBUG_VIEW
    vec2 viewCoord = fract(texcoord * 2.0);
    
    if (texcoord.x < 0.5 && texcoord.y >= 0.5) {
        color.rgb = pow(aces(texture({RT_BACK}, viewCoord).rgb), vec3(1.0/2.2));
    } 
    else if (texcoord.x >= 0.5 && texcoord.y >= 0.5) {
        color.rgb = texture({RT_BASE_COLOR}, viewCoord).rgb;
    } 
    else if (texcoord.x < 0.5 && texcoord.y < 0.5) {
        color.rgb = texture({RT_NORMAL}, viewCoord).rgb;
    } 
    else {
        color.rgb = texture({RT_LIGHTING0}, viewCoord).rgb;
    }

    color.a = 1.0;

	vec2 localCoord = fract(texcoord * 2.0);
    vec2 diff = (localCoord - 0.5);

    float dist = length(diff);
    float dotSize = 0.001; 
    float dot = 1.0 - smoothstep(dotSize, dotSize + 0.001, dist);
    color.rgb = mix(color.rgb, vec4(1.0, 1.0, 1.0, 1.0).rgb, dot);
    #endif
}
#endif

// {{SHADER_VERT}}
#ifdef {{SHADER_VERT}}
out vec2 texcoord;

void main()
{
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
#endif