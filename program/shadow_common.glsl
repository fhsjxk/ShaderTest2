// SHADER_FRAG
#ifdef SHADER_FRAG
uniform sampler2D gtexture;

in float alpha;
in vec2 texcoord;

void main() {
	if(texture(gtexture, texcoord).a * alpha < 0.52){
		discard;
	}
}
#endif

// SHADER_VERT
// NEED REFACTOR
#ifdef SHADER_VERT
out float alpha;
out vec2 texcoord;

vec3 distortShadowClipPos(vec3 shadowClipPos)
{
  float distortionFactor = length(shadowClipPos.xy);
  distortionFactor += 0.1;
  shadowClipPos.xy /= distortionFactor;
  shadowClipPos.z *= 0.5;
  return shadowClipPos;
}

void main()
{
	gl_Position = ftransform();
	gl_Position.xyz = distortShadowClipPos(gl_Position.xyz);
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	alpha = gl_Color.a;
}
#endif