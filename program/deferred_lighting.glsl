// {{SHADER_FRAG}}
#ifdef {{SHADER_FRAG}}
#include "/lib/common.glsl"
#include "/lib/options.glsl"

uniform sampler2D depthtex0;

uniform sampler2D shadowtex1;
uniform sampler2D shadowtex0;
uniform sampler2D shadowcolor0;

uniform sampler2D {{RT_BACK}};
uniform sampler2D {{RT_BASE_COLOR}};
uniform sampler2D {{RT_NORMAL}};
uniform sampler2D {{RT_LIGHTING0}};
uniform sampler2D {{RT_SKYVIEW}};

uniform sampler2D noisetex;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 sunDirection;

uniform float fakeGIAmount;
uniform float ambientAmount;

uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;
in vec3 viewRay;

#define SHADOW_RANGE 3
#define SHADOW_RADIUS 0.5

vec3 distortShadowClipPos(vec3 shadowClipPos){
  float distortionFactor = length(shadowClipPos.xy); // distance from the player in shadow clip space
  distortionFactor += 0.1; // very small distances can cause issues so we add this to slightly reduce the distortion

  shadowClipPos.xy /= distortionFactor;
  shadowClipPos.z *= 0.5; // increases shadow distance on the Z axis, which helps when the sun is very low in the sky
  return shadowClipPos;
}

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

const vec3 blocklightColor = vec3(1.0, 0.5, 0.08);
const vec3 skylightColor = vec3(0.05, 0.15, 0.3);
const vec3 sunlightColor = vec3(1.0);
const vec3 ambientColor = vec3(0.1);

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position){
	vec4 homPos = projectionMatrix * vec4(position, 1.0);
	return homPos.xyz / homPos.w;
}

vec3 getShadow(vec3 shadowScreenPos){
  float transparentShadow = step(shadowScreenPos.z, texture(shadowtex0, shadowScreenPos.xy).r); // sample the shadow map containing everything

  /*
  note that a value of 1.0 means 100% of sunlight is getting through
  not that there is 100% shadowing
  */

  if(transparentShadow == 1.0){
    /*
    since this shadow map contains everything,
    there is no shadow at all, so we return full sunlight
    */
    return vec3(1.0);
  }

  float opaqueShadow = step(shadowScreenPos.z, texture(shadowtex1, shadowScreenPos.xy).r); // sample the shadow map containing only opaque stuff

  if(opaqueShadow == 0.0){
    // there is a shadow cast by something opaque, so we return no sunlight
    return vec3(0.0);
  }

  // contains the color and alpha (transparency) of the thing casting a shadow
  vec4 shadowColor = texture(shadowcolor0, shadowScreenPos.xy);


  /*
  we use 1 - the alpha to get how much light is let through
  and multiply that light by the color of the caster
  */
  return shadowColor.rgb * (1.0 - shadowColor.a);
}

vec4 getNoise(vec2 coord){
  ivec2 screenCoord = ivec2(coord * vec2(viewWidth, viewHeight)); // exact pixel coordinate onscreen
  ivec2 noiseCoord = screenCoord % 64; // wrap to range of noiseTextureResolution
  return texelFetch(noisetex, noiseCoord, 0);
}

vec3 getSoftShadow(vec4 shadowClipPos){
  float noise = getNoise(texcoord).r;

  float theta = noise * radians(360.0); // random angle using noise value
  float cosTheta = cos(theta);
  float sinTheta = sin(theta);

  mat2 rotation = mat2(cosTheta, -sinTheta, sinTheta, cosTheta); // matrix to rotate the offset around the original position by the angle

  vec3 shadowAccum = vec3(0.0); // sum of all shadow samples
  const int samples = SHADOW_RANGE * SHADOW_RANGE * 4; // we are taking 2 * SHADOW_RANGE * 2 * SHADOW_RANGE samples

  for(int x = -SHADOW_RANGE; x < SHADOW_RANGE; x++){
    for(int y = -SHADOW_RANGE; y < SHADOW_RANGE; y++){
      vec2 offset = vec2(x, y) * SHADOW_RADIUS / float(SHADOW_RANGE);
      offset = rotation * offset; // rotate the sampling kernel using the rotation matrix we constructed
      offset /= shadowMapResolution; // offset in the rotated direction by the specified amount. We divide by the resolution so our offset is in terms of pixels
      vec4 offsetShadowClipPos = shadowClipPos + vec4(offset, 0.0, 0.0); // add offset
      offsetShadowClipPos.z -= 0.001; // apply bias
      offsetShadowClipPos.xyz = distortShadowClipPos(offsetShadowClipPos.xyz); // apply distortion
      vec3 shadowNDCPos = offsetShadowClipPos.xyz / offsetShadowClipPos.w; // convert to NDC space
      vec3 shadowScreenPos = shadowNDCPos * 0.5 + 0.5; // convert to screen space
      shadowAccum += getShadow(shadowScreenPos); // take shadow sample
    }
  }

  return shadowAccum / float(samples); // divide sum by count, getting average shadow
}

void main() {
	float depth = texture(depthtex0, texcoord).r;
	if (depth == 1.0)
  {
    color.rgb = texture({{RT_SKYVIEW}}, texcoord).rgb;
    //color.rgb += float(dot(normalize(viewRay), normalize(sunDirection)) > 0.9999) * 1000.0;
		return;
	}

  vec3 baseColor = texture({{RT_BASE_COLOR}}, texcoord).rgb;
  vec4 normal = texture({{RT_NORMAL}}, texcoord);
  vec4 lighting0 = texture({{RT_LIGHTING0}}, texcoord);

	vec3 NDCPos = vec3(texcoord.xy, depth) * 2.0 - 1.0;
	vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDCPos);
	vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
	vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;
	vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);

	vec3 shadow = getSoftShadow(shadowClipPos);

  float sunLightAmount = min(normal.a, float(shadow));

  vec3 H = normalize(normalize(viewRay) + -sunDirection);

  float spec = specularGGX(dot(normal.rgb*2.0-1.0, H), 0.7);
  //float fakeGIAmount = 4.0 * abs(sunDirection.y) * (1.0 - abs(sunDirection.y)) * 0.6 + 0.3;
  //float fakeGI = 1.0 + (lighting0.a * -1.0 + 1.0) * sunLightAmount * fakeGIAmount * pow(1 - normal.a, 2) * 30.0;
  //float lambert = saturate(dot(sunDirection, normal.rgb * 2.0 - 1.0) + 1.0);

  //float ignoreShadow = step(0.97, min(min(lighting0.x, lighting0.y), lighting0.z));
  //float shadowFactor = mix(float(shadow), 1.0, ignoreShadow);
  //float fakeGI =
  //    1.0 +
  //    (1.0 - lighting0.a) *
  //    (1.0 - normal.a) *
  //    shadowFactor * lambert * 2.0;
	//color.rgb = adjustSaturationFast(baseColor, fakeGI * 0.2 + 0.8) * (fakeGI * vec3(0.95, 0.88, 0.84) * 0.5 * lighting0.rgb + sunLightAmount * 2.0 * vec3(0.95, 0.88, 0.84) + 0.5 * lighting0.rgb * lighting0.a * ambientAmount * vec3(0.4, 0.6, 1.0));

  float fakeGI = 1.0 + (1.0 - lighting0.b) * (1 - normal.a) * float(shadow) * 3.0;

  float fakeGIFactor = fakeGI * 0.05 + 0.95; 
  vec3  baseAlbedo = adjustSaturationFast(baseColor, fakeGIFactor);

  vec3 sunColor = vec3(0.95, 0.88, 0.84);
  vec3 diffuseSun = sunLightAmount * (fakeGI * lighting0.g + 3.0 * sunColor);

  vec3 skyColor = vec3(0.4, 0.6, 1.0);
  vec3 ambientLight = ambientAmount * lighting0.g * lighting0.b * skyColor;

  vec3 localLightColor = vec3(1.0, 0.6, 0.2);
  vec3 localLight = pow(lighting0.r, 3.0) * localLightColor * 3.0;

  const float masterGain = 0.6;
  color.rgb = baseAlbedo * (diffuseSun + ambientLight + localLight) * masterGain; // Temp
  //color.rgb += spec.xxx * 0.05;
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