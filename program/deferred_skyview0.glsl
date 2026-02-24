// {{SHADER_FRAG}}
#ifdef {{SHADER_FRAG}}
#include "/lib/common.glsl"
#include "/lib/options.glsl"

uniform sampler2D depthtex0;
uniform sampler2D {RT_BACK};

in vec2 texcoord;

/* RENDERTARGETS: {{RT_BACK}} */
layout(location = 0) out vec4 color;

void main()
{
	//color.rgb = texelFetch({RT_BACK}, ivec2(gl_FragCoord.xy), 0).rgb;
	color.r = float(texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).r == 1.0) * 100.0;
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