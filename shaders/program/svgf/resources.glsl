#ifndef HELIOPAUSE_SVGF_RESOURCES
#define HELIOPAUSE_SVGF_RESOURCES
// Point-accessed atlases use logical internal dimensions, including fractional scales.
uniform sampler2D svgfHistory;
uniform sampler2D svgfStats;
uniform usampler2D svgfGeometry;
uniform sampler2D svgfDepth;
uniform sampler2D svgfScratch;
uniform sampler2D svgfMirror;
layout(rgba16f) uniform image2D svgfHistoryImage;
layout(rg32f) uniform image2D svgfStatsImage;
layout(rgba16ui) uniform uimage2D svgfGeometryImage;
layout(r32f) uniform image2D svgfDepthImage;
layout(rgba16f) uniform image2D svgfScratchImage;

ivec2 svgfCoord(ivec2 pixel, int layer) {
    return pixel + ivec2(layer * int(internalScreenSize.x), 0);
}
bool svgfInside(ivec2 pixel) {
    return all(greaterThanEqual(pixel, ivec2(0))) &&
           all(lessThan(pixel, ivec2(internalScreenSize)));
}
vec4 svgfReadHistory(ivec2 pixel, int layer) {
    return texelFetch(svgfHistory, svgfCoord(pixel, layer), 0);
}
vec2 svgfReadStats(ivec2 pixel, int layer) {
    return texelFetch(svgfStats, svgfCoord(pixel, layer), 0).rg;
}
vec4 svgfReadScratch(ivec2 pixel, int layer) {
    return texelFetch(svgfScratch, svgfCoord(pixel, layer), 0);
}
// Explicit round-to-nearest-even before half image stores. Some GL drivers
// truncate these stores, causing a persistent negative bias in temporal feedback.
// pack/unpackHalf can be optimized to an identity and does not enforce rounding.
vec4 svgfRoundHalf(vec4 value) {
    uvec4 bits=floatBitsToUint(value);
    vec4 rounded=uintBitsToFloat((bits+uvec4(0x00000fffu)+((bits>>13u)&uvec4(1u)))&uvec4(0xffffe000u));
    rounded=mix(rounded,roundEven(value*16777216.0)*0.000000059604644775390625,
                lessThan(abs(value),vec4(0.00006103515625)));
    return mix(rounded,value,greaterThanEqual(bits&uvec4(0x7fffffffu),uvec4(0x7f800000u)));
}
vec3 svgfRoundR11(vec3 value){
    uvec3 bits=floatBitsToUint(value),shift=uvec3(17u,17u,18u);
    vec3 rounded=uintBitsToFloat((bits+uvec3(0x0000ffffu,0x0000ffffu,0x0001ffffu)+((bits>>shift)&uvec3(1u)))&uvec3(0xfffe0000u,0xfffe0000u,0xfffc0000u));
    vec3 scale=vec3(1048576.0,1048576.0,524288.0);
    rounded=mix(rounded,roundEven(value*scale)/scale,lessThan(abs(value),vec3(0.00006103515625)));
    return mix(rounded,value,greaterThanEqual(bits&uvec3(0x7fffffffu),uvec3(0x7f800000u)));
}
void svgfWriteHistory(ivec2 pixel,int layer,vec4 value) {
    imageStore(svgfHistoryImage,svgfCoord(pixel,layer),svgfRoundHalf(value));
}
void svgfWriteScratch(ivec2 pixel, int layer, vec4 value) {
    imageStore(svgfScratchImage, svgfCoord(pixel, layer), svgfRoundHalf(value));
}
void svgfWriteStats(ivec2 pixel, int layer, vec2 value) {
    imageStore(svgfStatsImage, svgfCoord(pixel, layer), vec4(value, 0.0, 0.0));
}
#endif
