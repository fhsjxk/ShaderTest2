// {{SHADER_FRAG}}
#ifdef {{SHADER_FRAG}}
#include "/lib/common.glsl"
#include "/lib/options.glsl"

uniform sampler2D {RT_BACK};

in vec2 texcoord;
in vec3 viewRay;

// LOCAL SETTINGS
const bool {RT_BACK}MipmapEnabled = true;

/* RENDERTARGETS: {{RT_SKYVIEW}} */
layout(location = 0) out vec4 color;

void main()
{
	//float depth = texelFetch({RT_BACK}, ivec2(gl_FragCoord.xy) + ivec2(0, 1), 3).r;
	float depth = textureLod({RT_BACK}, texcoord, 4).r;
	if (depth < 1.0)
  {
		return;
	}
  float b = pow(smoothstep(0.1, 1.0, normalize(viewRay).y + 0.2), 0.1);
  color.rgb = mix(vec3(0.5, 0.65, 0.9)*1.5, vec3(0.18, 0.4, 1.0)*0.3, vec3(pow(b,3.0))) * 0.6;
}
#endif

// {{SHADER_VERT}}
#ifdef {{SHADER_VERT}}
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

out vec2 texcoord;
out vec3 viewRay;

void main()
{
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    viewRay = mat3(gbufferModelViewInverse) * (gbufferProjectionInverse * vec4(gl_Position.xy, 1.0, 1.0)).xyz;
}
#endif