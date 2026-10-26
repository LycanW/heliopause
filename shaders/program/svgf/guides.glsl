#ifndef HELIOPAUSE_SVGF_GUIDES
#define HELIOPAUSE_SVGF_GUIDES
#include "/include/util.glsl"
#include "/program/svgf/resources.glsl"

// 0: no traced surface; 1: primary; 2: virtual receiver; 3: camera-attached hand.
// Normals have separate consumers: geometric normals define planes, shading
// normals protect lighting detail. One 64-bit guide packs geometric oct8x2,
// shading oct12x2, roughness UNORM9, mean-normal length UNORM12 and kind3.
struct SvgfGuide {
    vec3 geoNormal;
    vec3 shadeNormal;
    float roughness;
    float normalLength;
    float viewZ;
    uint kind;
};
bool svgfOwnsVirtualDiffuse(float roughness, vec3 albedo, vec3 geo, vec3 shade, bool hand) {
    return roughness == 0.0 && all(equal(albedo,vec3(0.0))) && dot(geo,shade)>0.99999 && !hand;
}
uint svgfPackNormal(vec3 n) {
    uvec2 q = uvec2(round(clamp(octEncode(n), 0.0, 1.0) * 255.0));
    return q.x | (q.y << 8u);
}
vec3 svgfUnpackNormal(uint word) {
    return octDecode(vec2(word & 255u, word >> 8u) / 255.0);
}
SvgfGuide svgfReadGuide(ivec2 pixel, int layer) {
    ivec2 address = svgfCoord(pixel, layer);
    uvec4 words = texelFetch(svgfGeometry, address, 0);
    SvgfGuide g;
    g.geoNormal = svgfUnpackNormal(words.x);
    uvec2 shade=uvec2(words.y&4095u,(words.y>>12u)|((words.z&255u)<<4u));
    g.shadeNormal=octDecode(vec2(shade)/4095.0);
    g.roughness=float((words.z>>8u)|((words.w>>15u)<<8u))/511.0;
    g.normalLength=float((words.w>>3u)&4095u)/4095.0;
    g.kind=words.w&7u;
    g.viewZ = texelFetch(svgfDepth, address, 0).r;
    return g;
}
void svgfStoreGuideMean(ivec2 pixel,int layer,vec3 geo,vec3 shade,
                         float roughness,float normalLength,float viewZ,uint kind) {
    ivec2 address = svgfCoord(pixel, layer);
    uvec2 sn=uvec2(round(clamp(octEncode(shade),0.0,1.0)*4095.0));
    uint r=uint(round(clamp(roughness,0.0,1.0)*511.0));
    uint len=uint(round(clamp(normalLength,0.0,1.0)*4095.0));
    imageStore(svgfGeometryImage,address,uvec4(svgfPackNormal(geo),sn.x|((sn.y&15u)<<12u),
        (sn.y>>4u)|((r&255u)<<8u),kind|(len<<3u)|((r>>8u)<<15u)));
    imageStore(svgfDepthImage, address, vec4(viewZ, 0.0, 0.0, 0.0));
}
void svgfStoreGuide(ivec2 pixel,int layer,vec3 geo,vec3 shade,float roughness,float viewZ,uint kind){
    svgfStoreGuideMean(pixel,layer,geo,shade,roughness,1.0,viewZ,kind);
}
void svgfCopyGuide(ivec2 pixel, int destination) {
    imageStore(svgfGeometryImage, svgfCoord(pixel, destination),
               texelFetch(svgfGeometry, pixel, 0));
    imageStore(svgfDepthImage, svgfCoord(pixel, destination),
               vec4(texelFetch(svgfDepth, pixel, 0).r, 0.0, 0.0, 0.0));
}
vec3 svgfPosition(ivec2 pixel, float viewZ) {
    vec2 ndc = (vec2(pixel) + 0.5) * internalTexelSize * 2.0 - 1.0 - taaOffset;
    float clipW = -gbufferProjection[2][3] * viewZ + gbufferProjection[3][3];
    vec2 xy = (ndc * clipW + gbufferProjection[2].xy * viewZ - gbufferProjection[3].xy) /
              vec2(gbufferProjection[0][0], gbufferProjection[1][1]);
    return (gbufferModelViewInverse * vec4(xy, -viewZ, 1.0)).xyz;
}
float svgfPixelWorldSize(float viewZ) {
    float clipW = -gbufferProjection[2][3] * viewZ + gbufferProjection[3][3];
    return 2.0 * abs(clipW) * internalTexelSize.y / abs(gbufferProjection[1][1]);
}
#endif
