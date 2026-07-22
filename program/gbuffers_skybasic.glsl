// {{SHADER_FRAG}}
#ifdef {{SHADER_FRAG}}
#include "/lib/common.glsl"

uniform sampler2D starColorTex;

mediump in vec2 uv;
mediump flat in int index;

/* RENDERTARGETS: {RT_BACK} */
layout(location = 0) out vec4 outColor;

void main()
{
    // ── Soft disc from distance to triangle center ────────────
    float dist = length(uv);
    float disc = 1.0 - smoothstep(0.3, 0.5, dist);

    // ── Read star color from data texture ─────────────────────
    ivec2 starUV = ivec2(index % 512, index / 512);
    vec3 starCol = texelFetch(starColorTex, starUV, 0).rgb * 0.05;

    outColor = vec4(starCol * disc, 1.0);
}
#endif

// {{SHADER_VERT}}
#ifdef {{SHADER_VERT}}

void main()
{
    gl_Position = gl_Vertex;
}
#endif

// {{SHADER_GEOM}}
#ifdef {{SHADER_GEOM}}
#include "/lib/settings.glsl"

layout(triangles) in;
layout(triangle_strip, max_vertices = 146) out;

mediump out vec2 uv;
mediump flat out int index;

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform vec3 sunDirection;

uniform sampler2D starDirectionTex;
uniform sampler2D starColorTex;

const int TEX_SIZE = 512;
const int STARS_PER_PATCH = 68;

const vec2 offsets[3] = vec2[](
        vec2(-0.866025, -0.5),
        vec2( 0.866025, -0.5),
        vec2( 0.0, 1.0)
    );

ivec2 indexToUV(int idx)
{
    int x = idx % TEX_SIZE;
    int y = idx / TEX_SIZE;
    return ivec2(x, y);
}

bool inView(vec3 p)
{
    vec4 clip = gbufferProjection * (gbufferModelView * vec4(p, 1.0));

    float margin = clip.w * 0.1;

    return abs(clip.x) < clip.w + margin &&
           abs(clip.y) < clip.w + margin &&
           clip.z > -margin;
}

void emitStar(vec3 dir, float size, int starIndex)
{
    vec4 viewPosition = gbufferModelView * vec4(dir * 1e3, 1.0);

    index = starIndex;

    for (int i = 0; i < 3; i++)
    {
        vec4 p = viewPosition;

        p.xy += offsets[i] * size * 1e3;

        gl_Position = gbufferProjection * p;

        uv = offsets[i];

        EmitVertex();
    }

    EndPrimitive();
}

void main()
{
    int baseIndex = gl_PrimitiveIDIn * STARS_PER_PATCH;

    int maxStars = TEX_SIZE * TEX_SIZE;

    // ── Starfield rotation (follows sun azimuth + tilt) ───────
    vec3 sunDir = normalize(sunDirection);
    float angle = atan(-sunDir.y, sunDir.x) + radians(sunPathRotation);
    float c = cos(angle);
    float s = sin(angle);
    mat3 rotZ = mat3(
        vec3( c, -s, 0),
        vec3( s,  c, 0),
        vec3( 0,  0, 1)
    );

    for (int i = 0; i < STARS_PER_PATCH; i++)
    {
        int starIndex = baseIndex + i;

        if (starIndex >= maxStars) break;

        ivec2 uv = indexToUV(starIndex);

        vec3 dir = rotZ * texelFetch(starDirectionTex, uv, 0).rgb;

        vec4 data = texelFetch(starColorTex, uv, 0);
        float size = data.a * 0.003;

        if (!inView(dir * 1e3)) continue;

        emitStar(dir, size, starIndex);
    }
}
#endif