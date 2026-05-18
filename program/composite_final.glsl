// SHADER_FRAG
#ifdef SHADER_FRAG
#include "/lib/common.glsl"
#include "/lib/options.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex6;
//uniform sampler2D {{RT_SKY_TEST}};
uniform sampler2D colortex12;
uniform sampler2D colortex15;
uniform sampler2D starcoltex;
uniform sampler2D stardirtex;

uniform sampler2D vignettetex;

#ifdef DEBUG_VIEW
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex4;
#endif

in vec2 texcoord;

layout(location = 0) out vec4 color;

// LOCAL SETTINGS


vec3 aces(vec3 x) {
    const float a = 2.6;
    const float b = 0.7;
    const float c = 2.62;
    const float d = 0.4;
    const float e = 1.2;
    return (x * (a * x + b)) / (x * (c * x + d) + e);
}

void main()
{
    ivec2 pixelCoord = ivec2(gl_FragCoord.xy);
    //float value = texelFetch(colortex6, ivec2(11, 0), 0).r;
    //color.rgb = pow(aces(texelFetch(colortex0, pixelCoord, 0).rgb / mix(value, 1.0, 0.03) / 2.0), vec3(1.0/2.2));
    color.rgb = pow(aces(texelFetch(colortex0, pixelCoord, 0).rgb), vec3(1.0/2.2));
    //color.rgb = texture(colortex0, texcoord).rgb;
    #if defined VIGNETTE_AMOUNT && VIGNETTE_AMOUNT != 0.0
    float vignetteMask = texture(vignettetex, texcoord).r * VIGNETTE_AMOUNT + (1.0 - VIGNETTE_AMOUNT);
    color.rgb *= vignetteMask;
    #endif

    //color.rgb = texelFetch(stardirtex, pixelCoord, 0).rgb;
    color.rgb = color.rgb + texelFetch(colortex15, pixelCoord, 0).rgb;

    #ifdef DEBUG_VIEW
    vec2 viewCoord = fract(texcoord * 2.0);
    
    if (texcoord.x < 0.5 && texcoord.y >= 0.5) {
        color.rgb = pow(aces(texture(colortex0, viewCoord).rgb), vec3(1.0/2.2));
    } 
    else if (texcoord.x >= 0.5 && texcoord.y >= 0.5) {
        color.rgb = texture(colortex1, viewCoord).rgb;
    } 
    else if (texcoord.x < 0.5 && texcoord.y < 0.5) {
        color.rgb = texture(colortex2, viewCoord).rgb;
    } 
    else {
        color.rgb = texture(colortex4, viewCoord).rgb;
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

// SHADER_VERT
#ifdef SHADER_VERT
out vec2 texcoord;

void main()
{
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
#endif