#ifndef INCLUDE_LIGHTING
#define INCLUDE_LIGHTING
IrradianceSum sampleReflectionLighting(vec3 playerPos,vec3 normal,vec2 rand,float gradient){
    vec3 sampleUv=playerToScreenPos(playerPos);
    float weight=0.0;
    IrradianceSum screen=IrradianceSum(vec3(0.0),vec3(0.0));
    IrradianceSum cache=IrradianceSum(vec3(0.0),vec3(0.0));
    if(all(greaterThanEqual(sampleUv,vec3(0.0)))&&all(lessThan(sampleUv,vec3(1.0)))){
        ivec2 sampleTexel=ivec2(sampleUv.xy*internalScreenSize);
        float sourceDepth=texelFetch(depthtex1,sampleTexel,0).r;
        if(sourceDepth<1.0){
            DeferredMaterial source=unpackMaterialData(sampleTexel);
            vec3 sourcePosition=screenToPlayerPos(vec3((vec2(sampleTexel)+0.5)*internalTexelSize,sourceDepth)).xyz;
            float planeDistance=abs(dot(playerPos-sourcePosition,source.geoNormal));
            float geometryAgreement=dot(normal,source.geoNormal);
            float shadingAgreement=dot(normal,source.textureNormal);
            // Allow triangle/depth quantization, while excluding a nearby different plane.
            float tolerance=0.002+0.00002*length(playerPos);
            weight=(1.0-smoothstep(tolerance,2.0*tolerance,planeDistance))
                *smoothstep(0.95,0.995,geometryAgreement)
                *smoothstep(0.5,0.95,shadingAgreement)
                *exp(-16.0*lengthSquared(playerPos-sourcePosition))
                *(1.0-smoothstep(gradient,0.5,abs(sampleUv.x-0.5)))
                *(1.0-smoothstep(gradient,0.5,abs(sampleUv.y-0.5)));
            if(weight>0.0)screen=IrradianceSum(texelFetch(colortex12,sampleTexel,0).rgb,texelFetch(colortex5,sampleTexel,0).rgb);
        }
    }
    if(weight<1.0){
        cache=irradianceCacheSmooth(playerPos,normal,0u,rand);
        #ifdef REFLECTION_PER_PIXEL_SHADOWS
            if(dot(normal,shadowDir)>-0.0001)cache.directIrradiance=TraceShadowRay(Ray(playerPos,sampleSunDir(shadowDir,rand)),SHADOW_MAX_RT_DISTANCE,true).rgb;
        #endif
    }
    return IrradianceSum(mix(cache.diffuseIrradiance/SECONDARY_GI_BRIGHTNESS,screen.diffuseIrradiance,weight),mix(cache.directIrradiance,screen.directIrradiance,weight));
}
#endif
