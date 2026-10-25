#ifndef ZEPHYR_RELAX_RESOURCES
#define ZEPHYR_RELAX_RESOURCES

// Logical NRD textures share atlas storage; each pass reads and writes distinct
// logical regions. Iris issues the image/texture barriers between dispatches.
uniform sampler2D nrPool0;
uniform sampler2D nrPool1;
uniform sampler2D nrDepth;
layout(rgba16f) uniform writeonly image2D nrPool0Image;
layout(rgba16f) uniform writeonly image2D nrPool1Image;
layout(r32f) uniform writeonly image2D nrDepthImage;

#ifdef NR_OUTPUT_COLOR2
layout(rgba16f) uniform writeonly image2D colorimg2;
#endif

ivec2 nrTile(int layer) {
    return layer < 16 ? ivec2(layer & 3, layer >> 2) : ivec2((layer - 16) & 1, (layer - 16) >> 1);
}
ivec2 nrPixel(int layer, ivec2 pixel) {
    return nrTile(layer) * ivec2(internalScreenSize) + pixel;
}
// Preserve the SDK's discrete UNORM metadata while using FP16 atlas storage.
bool nrUnorm8(int layer){return layer==6||layer==7||layer==10||layer==14||layer==15||layer==18;}
vec4 nrStorageValue(int layer,vec4 value){
    if(nrUnorm8(layer))value=round(clamp(value,0.0,1.0)*255.0)/255.0;
    if(layer==1)value.w=round(clamp(value.w,0.0,1.0)*3.0)/3.0;
    return value;
}
vec4 nrLoadInside(int layer, ivec2 pixel) {
    if (layer < 0) return vec4(0.0);
    if (layer >= 100) return texelFetch(nrDepth, ivec2(pixel.x, pixel.y + (layer - 100) * int(internalScreenSize.y)), 0);
    if (layer < 16) return nrStorageValue(layer,texelFetch(nrPool0, nrPixel(layer, pixel), 0));
    return nrStorageValue(layer,texelFetch(nrPool1, nrPixel(layer, pixel), 0));
}
vec4 nrFetch(int layer, int filterMode, ivec2 pixel, int lod) {
    // HLSL Texture2D.Load returns zero outside the resource extent.
    if (any(lessThan(pixel, ivec2(0))) || any(greaterThanEqual(pixel, ivec2(internalScreenSize)))) return vec4(0.0);
    return nrLoadInside(layer, pixel);
}
vec4 nrSample(int layer, int filterMode, vec2 uv, float lod) {
    if (layer < 0) return vec4(0.0);
    vec2 p = clamp(uv * internalScreenSize, vec2(0.5), internalScreenSize - 0.5);
    if (filterMode == 0) return nrLoadInside(layer, ivec2(p));
    if (layer >= 100) return textureLod(nrDepth, (p + vec2(0.0, float(layer - 100) * internalScreenSize.y)) / vec2(textureSize(nrDepth, 0)), 0.0);
    p += vec2(nrTile(layer)) * internalScreenSize;
    if (layer < 16) return textureLod(nrPool0, p / vec2(textureSize(nrPool0, 0)), 0.0);
    return textureLod(nrPool1, p / vec2(textureSize(nrPool1, 0)), 0.0);
}
vec4 nrGather(int layer, int filterMode, vec2 uv) {
    ivec2 p = ivec2(floor(uv * internalScreenSize - 0.5));
    ivec2 hi = ivec2(internalScreenSize) - 1;
    return vec4(nrLoadInside(layer, clamp(p + ivec2(0, 1), ivec2(0), hi)).r,
                nrLoadInside(layer, clamp(p + ivec2(1, 1), ivec2(0), hi)).r,
                nrLoadInside(layer, clamp(p + ivec2(1, 0), ivec2(0), hi)).r,
                nrLoadInside(layer, clamp(p, ivec2(0), hi)).r);
}
void nrStore(int layer, ivec2 pixel, vec4 value) {
    // Iris can over-dispatch one group at fractional render scales. NRD's
    // reversed CTA order then produces negative coordinates; HLSL discards
    // these out-of-range stores instead of touching the adjacent atlas tile.
    if (any(lessThan(pixel, ivec2(0))) || any(greaterThanEqual(pixel, ivec2(internalScreenSize)))) return;
    #ifdef NR_OUTPUT_COLOR2
    if (layer == -10) {
        // NRD has top-left pixel coordinates; Minecraft targets have bottom-left.
        imageStore(colorimg2, ivec2(pixel.x, int(internalScreenSize.y) - 1 - pixel.y), value);
        return;
    }
    #endif
    if (layer >= 100) imageStore(nrDepthImage, ivec2(pixel.x, pixel.y + (layer - 100) * int(internalScreenSize.y)), value);
    else if (layer < 16) imageStore(nrPool0Image, nrPixel(layer, pixel), nrStorageValue(layer,value));
    else imageStore(nrPool1Image, nrPixel(layer, pixel), nrStorageValue(layer,value));
}
#endif
