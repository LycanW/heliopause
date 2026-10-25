#define IRCACHE_SNAPSHOT_WRITE
#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"

layout (local_size_x = 64) in;

#if IRCACHE_VOXEL_ARRAY_SIZE == 16384
    const ivec3 workGroups = ivec3(256, 1, 1);
#elif IRCACHE_VOXEL_ARRAY_SIZE == 32768
    const ivec3 workGroups = ivec3(512, 1, 1);
#elif IRCACHE_VOXEL_ARRAY_SIZE == 49152
    const ivec3 workGroups = ivec3(768, 1, 1);
#elif IRCACHE_VOXEL_ARRAY_SIZE == 65536
    const ivec3 workGroups = ivec3(1024, 1, 1);
#elif IRCACHE_VOXEL_ARRAY_SIZE == 98304
    const ivec3 workGroups = ivec3(1536, 1, 1);
#elif IRCACHE_VOXEL_ARRAY_SIZE == 131072
    const ivec3 workGroups = ivec3(2048, 1, 1);
#elif IRCACHE_VOXEL_ARRAY_SIZE == 262144
    const ivec3 workGroups = ivec3(4096, 1, 1);
#endif

void main ()
{
    uint index = gl_GlobalInvocationID.x;
    IrcacheVoxel voxel = ircache.entries[index];

    // Complete retirement before any update invocation can insert requests.
    // The key, origin, direct light and radiance then describe one cache epoch.
    if (voxel.packedPos == 0u || voxel.traceOrigin == 0u || frameCounter - voxel.lastFrame > 10u || voxel.lastFrame > frameCounter) {
        voxel.traceOrigin = 0u;
        voxel.rank = 128u;
        voxel.lastFrame = 0u;
        voxel.packedPos = 0u;
        voxel.direct = 0u;
        voxel.radiance = IRCACHE_INV_MARKER;
        ircache.entries[index] = voxel;
    }

    ircacheHistory.entries[index] = voxel;
}
