#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"

layout (local_size_x = 64) in;

// Keep each dispatch dimension below the OpenGL minimum group-count limit.
// 1024 groups * 64 invocations form one contiguous row of 65536 voxels.
#if VOXEL_ARRAY_SIZE == 65536
    const ivec3 workGroups = ivec3(1024, 1, 1);
#elif VOXEL_ARRAY_SIZE == 1048576
    const ivec3 workGroups = ivec3(1024, 16, 1);
#elif VOXEL_ARRAY_SIZE == 2097152
    const ivec3 workGroups = ivec3(1024, 32, 1);
#elif VOXEL_ARRAY_SIZE == 4194304
    const ivec3 workGroups = ivec3(1024, 64, 1);
#elif VOXEL_ARRAY_SIZE == 8388608
    const ivec3 workGroups = ivec3(1024, 128, 1);
#elif VOXEL_ARRAY_SIZE == 16777216
    const ivec3 workGroups = ivec3(1024, 256, 1);
#endif

void main ()
{
    uint rowWidth = gl_NumWorkGroups.x * gl_WorkGroupSize.x;
    uint voxelIndex = gl_GlobalInvocationID.x + gl_GlobalInvocationID.y * rowWidth;
    voxelBuffer.voxels[voxelIndex] = Voxel(0u, END_MARKER);
}
