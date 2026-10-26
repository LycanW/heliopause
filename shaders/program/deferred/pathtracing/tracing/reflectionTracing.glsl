#include "/include/uniforms.glsl"
#include "/include/checker.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/sampling.glsl"
#include "/include/octree.glsl"
#include "/include/wave.glsl"
#include "/include/raytracing.glsl"
#include "/include/textureData.glsl"
#include "/include/brdf.glsl"
#include "/include/ircache.glsl"
#include "/include/atmosphere.glsl"
#include "/include/spaceConversion.glsl"
#include "/include/lighting.glsl"
#include "/program/svgf/guides.glsl"

layout(rgba16f) uniform image2D colorimg2;
layout(r32f) uniform image2D colorimg13;
layout(rgba16f) uniform writeonly image2D svgfMirrorImage;
#ifndef DISABLE_DENOISING
layout(rgba16f) uniform writeonly image2D colorimg10;
#endif
layout(local_size_x=8,local_size_y=8) in;

void main() {
    ivec2 pixel=ivec2(gl_GlobalInvocationID.xy);
    if(any(greaterThanEqual(pixel,ivec2(internalScreenSize))))return;
    ivec2 factorPixel=pixel+ivec2(int(internalScreenSize.x),0);
    imageStore(svgfMirrorImage,pixel,vec4(0.0));
    imageStore(svgfMirrorImage,factorPixel,vec4(1.0,1.0,1.0,0.0));
    uint state=gl_GlobalInvocationID.x+gl_GlobalInvocationID.y*uint(internalScreenSize.x)+uint(internalScreenSize.x)*uint(internalScreenSize.y)*(frameCounter&1023u);
    float depth=texelFetch(depthtex1,pixel,0).r;
    imageStore(colorimg13,pixel,vec4(depth,0.0,0.0,1.0));
    if(depth==1.0) {
        #ifndef DISABLE_DENOISING
        svgfStoreGuide(pixel,0,vec3(0.0,1.0,0.0),vec3(0.0,1.0,0.0),0.0,0.0,0u);
        #endif
        imageStore(colorimg2,pixel,vec4(0.0));
        return;
    }
    DeferredMaterial mat=unpackMaterialData(pixel);
    vec2 uv=(vec2(pixel)+0.5)*internalTexelSize;
    vec3 primaryPosition=screenToPlayerPos(vec3(uv,depth)).xyz;
    float primaryViewZ=-(gbufferModelView*vec4(primaryPosition,1.0)).z;
    #ifndef DISABLE_DENOISING
    svgfStoreGuide(pixel,0,mat.geoNormal,mat.textureNormal,mat.roughness,primaryViewZ,
        mat.roughness>REFLECTION_ROUGHNESS_THRESHOLD?0u:(mat.isHand?3u:1u));
    #endif
    if(mat.roughness>REFLECTION_ROUGHNESS_THRESHOLD) {
        imageStore(colorimg2,pixel,vec4(0.0));
        return;
    }
    // Delta events on a planar surface have a deterministic prefix. Filtering sees
    // the first non-delta surface after this prefix (primary surface replacement).
    bool primaryDelta=mat.roughness==0.0&&!mat.isHand&&dot(mat.geoNormal,mat.textureNormal)>0.99999;
    bool splitMirror=false;
    #ifndef DISABLE_DENOISING
    splitMirror=svgfOwnsVirtualDiffuse(mat.roughness,mat.albedo.rgb,mat.geoNormal,mat.textureNormal,mat.isHand);
    if(splitMirror)imageStore(colorimg10,pixel,vec4(0.0));
    #endif
    vec3 virtualDiffuse=vec3(0.0),diffuseFactor=vec3(0.0);
    vec3 rayOrigin=primaryPosition;
    vec3 rayDir=normalize(primaryPosition-screenToPlayerPos(vec3(uv,0.0)).xyz);
    vec3 reflectedDir=reflect(rayDir,mat.textureNormal);
    if(mat.isHand)rayOrigin+=0.5*playerLookVector;
    vec3 radiance=vec3(0.0),baseRadiance=vec3(0.0),specularFactor=vec3(1.0);
    float reflectionDepth=REFLECTION_MAX_RT_DISTANCE;
    vec3 psrPosition=primaryPosition,psrNormal=mat.textureNormal;
    float psrRoughness=mat.roughness;
    bool hasPsr=false;
    for(int i=0;i<REFLECTION_SAMPLES;i++) {
        vec3 throughput=vec3(1.0);
        float roughnessAccum=mat.roughness,rayDist=0.0;
        bool prefix=primaryDelta;
        vec3 sampleFactor=primaryDelta?vec3(0.0):vec3(1.0);
        mat3 virtualRotation=mat3(1.0)-2.0*outerProduct(mat.textureNormal,mat.textureNormal);
        vec3 virtualTranslation=primaryPosition-virtualRotation*primaryPosition;
        Ray ray;
        ray.origin=rayOrigin+mat.geoNormal*0.005;
        ray.direction=sampleVNDF(rayDir,mat.textureNormal,mat.roughness,
            #if NOISE_METHOD == 1
                vec2(heitzSample(pixel,REFLECTION_SAMPLES*frameCounter+i,0),heitzSample(pixel,REFLECTION_SAMPLES*frameCounter+i,1))
            #else
                vec2(randomValue(state),randomValue(state))
            #endif
        );
        float pdf=exp(8.0*(dot(ray.direction,reflectedDir)-1.0));
        if(dot(ray.direction,mat.geoNormal)<0.0) {
            ray.direction=reflect(ray.direction,mat.geoNormal);
            throughput*=mat.F0;
        }
        for(int j=0;j<REFLECTION_BOUNCES;j++) {
            RayHitInfo rt=TraceGenericRay(ray,REFLECTION_MAX_RT_DISTANCE,true,true);
            if(luminance(throughput)>0.5&&roughnessAccum<0.2)rayDist+=rt.dist;
            if(rt.hit) {
                throughput*=pdf;
                vec3 hitPos=ray.origin+rt.dist*ray.direction;
                #ifdef REFLECTION_SS_REUSE
                    IrradianceSum lighting=sampleReflectionLighting(hitPos,rt.normal,vec2(randomValue(state),randomValue(state)),0.3);
                #else
                    vec2 rand=vec2(randomValue(state),randomValue(state));
                    IrradianceSum lighting=irradianceCacheSmooth(hitPos,rt.normal,0u,rand);
                    #ifdef REFLECTION_PER_PIXEL_SHADOWS
                        if(dot(rt.normal,shadowDir)>-0.0001)lighting.directIrradiance=TraceShadowRay(Ray(hitPos,sampleSunDir(shadowDir,rand)),SHADOW_MAX_RT_DISTANCE,true).rgb;
                    #endif
                #endif
                vec3 emitted=rt.albedo.rgb*rt.emission;
                vec3 receiverDiffuse=lighting.diffuseIrradiance,receiverSpecular=vec3(0.0);
                if(dot(rt.normal,shadowDir)>-0.0001) {
                    vec3 d,s;
                    evalCookBRDFLobes(normalize(shadowDir+rt.normal*0.03125),ray.direction,max(0.2,rt.roughness),rt.normal,vec3(1.0),rt.F0,d,s);
                    vec3 sunlight=lightTransmittance(shadowDir)*shadowLightBrightness*lighting.directIrradiance;
                    receiverDiffuse+=sunlight*d;receiverSpecular=sunlight*s;
                }
                vec3 hitLighting=rt.albedo.rgb*receiverDiffuse+receiverSpecular;
                bool replaceSurface=prefix&&(rt.roughness>0.0||any(greaterThan(rt.albedo.rgb,vec3(0.0))));
                vec3 fresnel=schlickFresnel(rt.F0,-dot(ray.direction,rt.normal));
                if(replaceSurface){
                    // The receiver is deterministic, but its cache/shadow
                    // lighting estimate is stochastic. Only emission bypasses
                    // reconstruction. Demodulate the complete receiver lighting
                    // and continuation by its actual material response; the
                    // positive offset stabilizes dark-channel normalization and
                    // cancels exactly during unfiltered recomposition.
                    baseRadiance+=throughput*emitted;
                    if(splitMirror){
                        virtualDiffuse+=receiverDiffuse;
                        diffuseFactor=throughput*rt.albedo.rgb;
                        radiance+=throughput*receiverSpecular;
                        sampleFactor=throughput*max(fresnel,vec3(0.01));
                    }else{
                        radiance+=throughput*hitLighting;
                        sampleFactor=throughput*max(max(rt.albedo.rgb,fresnel),vec3(0.01));
                    }
                }else if(prefix)baseRadiance+=throughput*(emitted+hitLighting);
                else radiance+=throughput*(emitted+hitLighting);
                if(replaceSurface) {
                    psrPosition=virtualRotation*hitPos+virtualTranslation;
                    psrNormal=virtualRotation*rt.normal;
                    psrRoughness=rt.roughness;
                    hasPsr=true;
                    prefix=false;
                }
                roughnessAccum=mix(roughnessAccum,1.0,rt.roughness);
                if(roughnessAccum>REFLECTION_ROUGHNESS_THRESHOLD||luminance(throughput)<0.2)break;
                throughput*=fresnel;
                if(prefix) {
                    mat3 reflection=mat3(1.0)-2.0*outerProduct(rt.normal,rt.normal);
                    virtualTranslation+=virtualRotation*(hitPos-reflection*hitPos);
                    virtualRotation=virtualRotation*reflection;
                }
                ray.origin=hitPos+rt.normal*0.003;
                ray.direction=sampleVNDF(ray.direction,rt.normal,rt.roughness,vec2(randomValue(state),randomValue(state)));
            }else {
                #ifdef DIMENSION_OVERWORLD
                    vec3 sky=throughput*rt.albedo.rgb*sampleSkyView(ray.direction);
                    if(prefix)baseRadiance+=sky;
                    else radiance+=sky;
                #endif
                break;
            }
        }
        reflectionDepth=min(reflectionDepth,rayDist);
        specularFactor=sampleFactor;
    }
    vec3 virtualPosition=primaryPosition+rayDir*reflectionDepth;
    float virtualDepth=playerToScreenPos(mix(virtualPosition,primaryPosition,smoothstep(0.002,0.007,mat.roughness))).z;
    radiance*=rcp(REFLECTION_SAMPLES);
    if(primaryDelta) {
        baseRadiance*=rcp(REFLECTION_SAMPLES);
        // The lobe factor belongs to the deterministic replacement surface,
        // outside the denoiser. A zero factor means this channel has no energy.
        radiance=vec3(specularFactor.x>0.0?radiance.x/specularFactor.x:0.0,specularFactor.y>0.0?radiance.y/specularFactor.y:0.0,specularFactor.z>0.0?radiance.z/specularFactor.z:0.0);
        imageStore(svgfMirrorImage,pixel,vec4(baseRadiance,0.0));
        imageStore(svgfMirrorImage,factorPixel,vec4(specularFactor,0.0));
        float viewZ=hasPsr?-(gbufferModelView*vec4(psrPosition,1.0)).z:0.0;
        #ifndef DISABLE_DENOISING
        uint receiverKind=hasPsr?(splitMirror?(any(greaterThan(diffuseFactor,vec3(0.0)))?2u:7u):5u):(splitMirror?6u:0u);
        svgfStoreGuide(pixel,0,psrNormal,psrNormal,psrRoughness,viewZ,receiverKind);
        if(splitMirror){
            imageStore(colorimg10,pixel,vec4(diffuseFactor,0.0));
            svgfWriteScratch(pixel,2,vec4(receiverKind==2u?virtualDiffuse*rcp(REFLECTION_SAMPLES):vec3(0.0),0.0));
        }
        #endif
        if(hasPsr)virtualDepth=playerToScreenPos(psrPosition).z;
    }
    imageStore(colorimg13,pixel,vec4(virtualDepth,0.0,0.0,1.0));
    // A primary pixel's subpixel material response is part of the canonical
    // pixel integral. Integrate the complete contribution before accumulating.
    if(!primaryDelta)radiance*=schlickFresnel(mat.F0,dot(mat.textureNormal,normalize(screenToPlayerPos(vec3(uv,0.0)).xyz-primaryPosition)));
    imageStore(colorimg2,pixel,vec4(radiance,0.0));
}

#include "/program/svgf/dispatch.glsl"
