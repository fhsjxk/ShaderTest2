// {{SHADER_FRAG}}
#ifdef {{SHADER_FRAG}}
#include "/lib/prelude.glsl"

uniform sampler2D starColorTex;

mediump in vec2 uv;
mediump flat in int index;

/* RENDERTARGETS: {RT_BACK} */
layout(location = 0) out vec4 outColor;

// Star disc falloff in quad UV space, and its peak radiance.
const float STAR_DISC_INNER   = 0.1;
const float STAR_DISC_OUTER   = 0.5;
const float STAR_BRIGHTNESS   = 0.05;

void main()
{
    float dist = length(uv);
    float disc = 1.0 - smoothstep(STAR_DISC_INNER, STAR_DISC_OUTER, dist);

    ivec2 starUV = ivec2(index % 512, index / 512);
    vec3 starCol = texelFetch(starColorTex, starUV, 0).rgb * STAR_BRIGHTNESS;

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
#include "/lib/prelude.glsl"

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

// Stars are emitted on a huge sphere; only the direction matters.
const float STAR_DISTANCE = 1e3;
// Quad radius per unit of the alpha channel stored in the star colour texture.
const float STAR_SIZE_SCALE = 0.003;
// Extra clip-space margin (fraction of w) so quads do not pop at the screen edge.
const float STAR_CULL_MARGIN = 0.1;

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

    float margin = clip.w * STAR_CULL_MARGIN;

    return abs(clip.x) < clip.w + margin &&
           abs(clip.y) < clip.w + margin &&
           clip.z > -margin;
}

void emitStar(vec3 dir, float size, int starIndex)
{
    vec4 viewPosition = gbufferModelView * vec4(dir * STAR_DISTANCE, 1.0);

    index = starIndex;

    for (int i = 0; i < 3; i++)
    {
        vec4 p = viewPosition;

        p.xy += offsets[i] * size * STAR_DISTANCE;

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
        float size = data.a * STAR_SIZE_SCALE;

        if (!inView(dir * STAR_DISTANCE)) continue;

        emitStar(dir, size, starIndex);
    }
}
#endif