// {{SHADER_FRAG}}
#ifdef {{SHADER_FRAG}}

/* RENDERTARGETS: 15 */
layout(location = 0) out vec4 color;

void main()
{
    color.rgb = vec3(1.0);
    color.a = 1.0;
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

layout(triangles) in;
layout(triangle_strip, max_vertices = 256) out;

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;

uniform sampler2D stardirtex;
uniform sampler2D starcoltex;

const int TEX_SIZE = 512;
const int STARS_PER_PATCH = 80;

ivec2 indexToUV(int idx) {
    int x = idx % TEX_SIZE;
    int y = idx / TEX_SIZE;
    return ivec2(x, y);
}

bool inView(vec3 p) {
    vec4 clip = gbufferProjection * (gbufferModelView * vec4(p,1.0));

    float margin = clip.w * 0.1;

    return abs(clip.x) < clip.w + margin &&
           abs(clip.y) < clip.w + margin &&
           clip.z > -margin;
}

void emitStar(vec3 dir, vec3 color) {

    vec3 worldPos = dir * 1000.0;

    vec4 viewPos = gbufferModelView * vec4(worldPos, 1.0);

    float size = 2;

    const vec2 offsets[3] = vec2[](
        vec2(-0.866025, -0.5),
        vec2( 0.866025, -0.5),
        vec2( 0.0, 1.0)
    );

    for (int i = 0; i < 3; i++) {
        vec4 p = viewPos;
        p.xy += offsets[i] * size * p.w;

        gl_Position = gbufferProjection * p;


        EmitVertex();
    }

    EndPrimitive();
}

void main() {

    int baseIndex = gl_PrimitiveIDIn * STARS_PER_PATCH;

    int maxStars = TEX_SIZE * TEX_SIZE;

    for (int i = 0; i < STARS_PER_PATCH; i++) {

        int starIndex = baseIndex + i;

        if (starIndex >= maxStars) break;

        ivec2 uv = indexToUV(starIndex);

        vec3 dir = texelFetch(stardirtex, uv, 0).rgb;
        vec3 col = texelFetch(starcoltex, uv, 0).rgb;

         vec3 pos = dir * 1000.0;
         if (!inView(pos)) continue;

        emitStar(dir, col);
    }
}
#endif