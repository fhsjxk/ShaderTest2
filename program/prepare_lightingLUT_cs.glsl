// SHADER_COMP
#ifdef SHADER_COMP
layout(rgba16f) uniform writeonly image2D colorimg6;
layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(1, 1, 1);

void main()
{
    // Intentionally empty: this pass only keeps pipeline structure for now.
}
#endif
