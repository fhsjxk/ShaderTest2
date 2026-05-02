// {{SHADER_FRAG}}
#ifdef {{SHADER_FRAG}}

/* RENDERTARGETS: 15 */
layout(location = 0) out vec4 color;

flat in int index;

void main()
{
    color.rgb = vec3(1.0);
    color.rgb += (index % 3) / 100;
    //color.rgb = uv.xyx * color1 * brightness;
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
layout(points, max_vertices = 170) out;

flat out int index;

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;

uniform sampler2D stardirtex;
uniform sampler2D starcoltex;

const int TEX_SIZE = 512;
const int STARS_PER_PATCH = 204;

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

void emitStar(vec3 dir, float size) {

    vec3 worldPos = dir;
    vec4 viewPos = gbufferModelView * vec4(worldPos, 1.0);
    float invDist = 1.0 / max(0.001, -viewPos.z);

    gl_Position = gbufferProjection * viewPos;
    gl_PointSize = size;

    EmitVertex();
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
        float size = texelFetch(starcoltex, uv, 0).a * 5;

        if (!inView(dir)) continue;

        emitStar(dir, size);
    }
}
#endif