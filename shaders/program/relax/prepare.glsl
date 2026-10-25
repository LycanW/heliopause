#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/spaceConversion.glsl"
#include "/program/relax/resources.glsl"

layout(local_size_x=8, local_size_y=8) in;

#include "/program/relax/guides.glsl"

void main() {
    ivec2 pixel=ivec2(gl_GlobalInvocationID.xy);
    if (any(greaterThanEqual(pixel,ivec2(internalScreenSize)))) return;
    ivec2 nrPixelCoord=ivec2(pixel.x,int(internalScreenSize.y)-1-pixel.y);
    float depth=texelFetch(depthtex1,pixel,0).r;
    if (depth==1.0) {
        nrStore(100,nrPixelCoord,vec4(1000000.0,0.0,0.0,0.0));
        nrStore(0,nrPixelCoord,vec4(0.0));
        nrStore(1,nrPixelCoord,vec4(0.5,0.5,1.0,0.0));
        return;
    }
    DeferredMaterial mat=unpackMaterialData(pixel);
    vec3 position=screenToPlayerPos(vec3((vec2(pixel)+0.5)*internalTexelSize,depth)).xyz;
    float viewZ=-(gbufferModelView*vec4(position,1.0)).z;
    nrStore(100,nrPixelCoord,vec4(viewZ,0.0,0.0,0.0));
    // The VNDF sampler receives mat.roughness as GGX alpha. NRD expects sqrt(alpha).
    nrStore(1,nrPixelCoord,vec4(nrEncodeNormalRoughness(mat.textureNormal,sqrt(mat.roughness)),0.0));
    nrStore(0,nrPixelCoord,texelFetch(colortex2,pixel,0));
}
