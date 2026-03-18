// {{SHADER_FRAG}}
#ifdef {{SHADER_FRAG}}
#include "/lib/atmosphere.glsl"

uniform sampler2D {{RT_BACK}};

uniform float eyeAltitude;

in vec2 texcoord;
in vec3 viewRay;

// LOCAL SETTINGS
const bool {{RT_BACK}}MipmapEnabled = true;

/* RENDERTARGETS: {RT_SKYVIEW} */
layout(location = 0) out vec4 color;

void main()
{
	//float depth = texelFetch({{RT_BACK}}, ivec2(gl_FragCoord.xy) + ivec2(0, 1), 3).r;
	float depth = textureLod({{RT_BACK}}, texcoord, 4).r;
	if (depth < 1.0)
  {
		return;
	}
  color.rgb = RgbFromSpectral(computeInscattering(normalize(viewRay.xzy), max((eyeAltitude - 64.0) * 0.05, 0.01)));
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