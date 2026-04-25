// {{SHADER_FRAG}}
#ifdef {{SHADER_FRAG}}
#include "/lib/common.glsl"
#include "/lib/options.glsl"

uniform sampler2D {{RT_BACK}};

in vec2 texcoord;

// Enable mipmap generation for RT_BACK in this pass
const bool {{RT_BACK}}MipmapEnabled = true;

/* RENDERTARGETS: {RT_BACK} */
layout(location = 0) out vec4 color;

void main()
{
    // Copy pass to trigger mipmap regeneration
    // This is necessary because Iris doesn't automatically regenerate mipmaps 
    // after compute shader writes to the texture
    color = texelFetch({{RT_BACK}}, ivec2(gl_FragCoord.xy), 0);
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