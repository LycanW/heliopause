#define IRCACHE_UPDATE_READ_HISTORY
#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/octree.glsl"
#include "/include/wave.glsl"
#include "/include/raytracing.glsl"
#include "/include/textureData.glsl"
#include "/include/ircache.glsl"
#include "/include/brdf.glsl"
#include "/include/atmosphere.glsl"
#include "/include/sampling.glsl"
#include "/include/cacheLightSampling.glsl"

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

    IrcacheVoxel voxel = ircacheHistory.entries[index];
    uint state = gl_GlobalInvocationID.x + (frameCounter & 2047u) * IRCACHE_VOXEL_ARRAY_SIZE;

    // Expiry was completed before the snapshot. Never clear a slot here: a
    // different invocation may have requested that empty slot during this pass.
    if (voxel.packedPos == 0u) return;

    ivec4 voxelPos = unpackCachePos(voxel.packedPos);

    vec3 normal = octDecode(saturate(vec2(uvec2(voxel.traceOrigin >> 4u, voxel.traceOrigin) & 15u) * rcp(14.0)));
    vec3 playerPos = ((voxelPos.xyz << voxelPos.w) - (cameraPositionInt << 2)) / 4.0 - cameraPositionFract + exp2(voxelPos.w - 2.0) * ((uvec3(voxel.traceOrigin >> 24u, voxel.traceOrigin >> 16u, voxel.traceOrigin >> 8u) & 255u) * rcp(256.0) + rcp(512.0) - normal * 0.47);

    Ray ray;
    
    ray.origin = playerPos;

    vec4 currRadiance = vec4(0.0);

    for (int i = 0; i < IRCACHE_SAMPLES; i++) {
        ray.direction = randomHemisphereDir(normal, state);

        RayHitInfo rt = TraceGenericRay(ray, IRCACHE_MAX_RT_DISTANCE, true, true);
        float mu = dot(normal, ray.direction);

        if (rt.hit) {
            vec3 hitPos=ray.origin+ray.direction*rt.dist;
            #ifdef IRCACHE_LIGHT_GUIDING
                IrradianceSum query=IrradianceSum(vec3(0.0),vec3(0.0));
                // A zero diffuse lobe does not consume an irradiance-cache entry.
                if(any(greaterThan(rt.albedo.rgb,vec3(0.0))))query=irradianceCache(ray.origin+ray.direction*(rt.dist-0.002),rt.normal,voxel.rank);
                vec3 diffuseSun,specularSun;
                evalCookBRDFLobes(shadowDir,ray.direction,max(0.2,rt.roughness),rt.normal,rt.albedo.rgb,rt.F0,diffuseSun,specularSun);
                vec3 specularVisibility=vec3(0.0);
                if(dot(rt.normal,shadowDir)>0.0&&shadowLightBrightness>0.0){
                    specularVisibility=TraceShadowRay(Ray(hitPos+rt.normal*0.003,sampleSunDir(shadowDir,vec2(randomValue(state),randomValue(state)))),SHADOW_MAX_RT_DISTANCE,true).rgb;
                }
                float hemisphereWeight=cacheLightUniformWeight(ray.direction,rt.normal);
                currRadiance.rgb+=mu*(rt.albedo.rgb*(rt.emission+query.diffuseIrradiance)+lightTransmittance(shadowDir)*shadowLightBrightness*(query.directIrradiance*diffuseSun+specularVisibility*specularSun*hemisphereWeight));
            #else
                IrradianceSum query=irradianceCache(ray.origin+ray.direction*(rt.dist-0.002),rt.normal,voxel.rank);
                currRadiance.rgb+=mu*(rt.albedo.rgb*(rt.emission+query.diffuseIrradiance)+lightTransmittance(shadowDir)*shadowLightBrightness*query.directIrradiance*evalCookBRDF(shadowDir,ray.direction,max(0.2,rt.roughness),rt.normal,rt.albedo.rgb,rt.F0));
            #endif
        } 
        #ifdef DIMENSION_OVERWORLD
            else {
                currRadiance.rgb += mu * rt.albedo.rgb * sampleSkyView(ray.direction);
            }
        #endif
    }
    
    currRadiance.rgb *= rcp(IRCACHE_SAMPLES);

    #ifdef IRCACHE_LIGHT_GUIDING
        // Each proposal estimates only the direct-specular contribution of its
        // actual axis-surface class. Other paths retain hemisphere sampling.
        for(int axis=0;axis<3;axis++){
            vec3 proposalNormal=cacheLightAxisNormal(axis);
            if(dot(proposalNormal,shadowDir)<=0.0||shadowLightBrightness<=0.0)continue;
            vec3 outgoing=sampleVNDFUnfolded(-shadowDir,proposalNormal,cacheLightProposalAlpha,vec2(randomValue(state),randomValue(state)));
            vec3 direction=-outgoing;
            float mu=dot(normal,direction);
            if(mu<=0.0||dot(proposalNormal,outgoing)<=0.0)continue;
            Ray guidedRay=Ray(playerPos,direction);
            RayHitInfo rt=TraceGenericRay(guidedRay,IRCACHE_MAX_RT_DISTANCE,true,true);
            if(!rt.hit||cacheLightSurfaceAxis(rt.normal)!=axis||dot(rt.normal,shadowDir)<=0.0)continue;
            vec3 diffuseSun,specularSun;
            evalCookBRDFLobes(shadowDir,direction,max(0.2,rt.roughness),rt.normal,rt.albedo.rgb,rt.F0,diffuseSun,specularSun);
            vec3 hitPos=playerPos+direction*rt.dist;
            vec3 visibility=TraceShadowRay(Ray(hitPos+rt.normal*0.003,sampleSunDir(shadowDir,vec2(randomValue(state),randomValue(state)))),SHADOW_MAX_RT_DISTANCE,true).rgb;
            float proposalPdf=cacheLightProposalPdf(outgoing,proposalNormal);
            float balance=cacheHemispherePdf/(float(IRCACHE_SAMPLES)*cacheHemispherePdf+proposalPdf);
            currRadiance.rgb+=mu*lightTransmittance(shadowDir)*shadowLightBrightness*visibility*specularSun*balance;
        }
    #endif

    vec4 prevRadiance = unpackHalf4x16(voxel.radiance);
    vec3 prevShadow   = unpack3x10(voxel.direct);

    if (any(isnan(currRadiance))) currRadiance = vec4(0.0);
    if (any(isnan(prevRadiance))) prevRadiance = vec4(0.0, 0.0, 0.0, 1.0);

    vec3 currShadow = vec3(0.0);

    if (dot(normal, shadowDir) > 0.0) currShadow = TraceShadowRay(Ray(ray.origin, sampleSunDir(shadowDir, vec2(randomValue(state), randomValue(state)))), 1024.0, true).rgb;
    else currShadow = vec3(0.0);

    if (prevRadiance.w == 1.0) {
        for (int i = voxelPos.w - 1; i <= voxelPos.w + 2; i += 2) {
            if (i >= 0) {
                IrradianceSum prevData = irradianceCacheSilent(playerPos, normal, i);

                if (prevData.diffuseIrradiance != vec3(0.0)) {
                    prevRadiance.rgb = max(vec3(0.0), prevData.diffuseIrradiance);
                    prevRadiance.w = rcp(IRCACHE_BLEND_WEIGHT);

                    prevShadow = currShadow;

                    break;
                }
            }
        }
    }

    prevRadiance.w = clamp(prevRadiance.w, 1.0, rcp(IRCACHE_BLEND_WEIGHT));

    ircache.entries[index].direct   = pack3x10(mix(prevShadow, currShadow, rcp(min(prevRadiance.w, 16.0))));
    ircache.entries[index].radiance = packHalf4x16(vec4(mix(prevRadiance.rgb, currRadiance.rgb, rcp(prevRadiance.w)), prevRadiance.w + 1.0));
}
