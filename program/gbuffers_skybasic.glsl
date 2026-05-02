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
// 3 vertices × 10 copies = 30

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;

// 伪随机函数（fast hash）
float hash(vec3 p) {
    return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

vec3 hash3(vec3 p) {
    return vec3(
        hash(p + 1.0),
        hash(p + 2.0),
        hash(p + 3.0)
    );
}

bool inView(vec3 p) {
    vec4 clip = gbufferProjection * (gbufferModelView * vec4(p,1.0));
    return abs(clip.x) < clip.w &&
           abs(clip.y) < clip.w &&
           clip.z > 0.0;
}

void emitStar(vec3 center, vec3 dir) {

    // random direction
    

    vec3 worldPos = dir * 1000.0;

    vec4 viewPos = gbufferModelView * vec4(worldPos, 1.0);

    float size = 1;

    vec2 offsets[3] = vec2[](
        vec2(-1,-1),
        vec2( 3,-1),
        vec2(-1, 3)
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

    vec3 base = (gl_in[0].gl_Position.xyz +
                 gl_in[1].gl_Position.xyz +
                 gl_in[2].gl_Position.xyz) / 3.0;

    // triangle center
    vec3 p0 = gl_in[0].gl_Position.xyz;
    vec3 p1 = gl_in[1].gl_Position.xyz;
    vec3 p2 = gl_in[2].gl_Position.xyz;

    vec3 center = (p0 + p1 + p2) / 3.0;

    int emitted = 0;

    // ===== 10× stress test =====
    for (int i = 0; i < 85; i++) {
        float seed = float(i);

        vec3 dir = normalize(hash3(center + seed) * 2.0 - 1.0);

        vec3 pos = base +  dir * 1000.0;

        //if (!inView(pos)) {
        //    continue;
        //}

        emitStar(center + seed, dir);

        //emitted++;

        //if (emitted >= 85) {
        //    break;
        //}
    }
}
#endif