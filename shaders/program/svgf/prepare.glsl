#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/spaceConversion.glsl"
#include "/program/svgf/guides.glsl"

void main() {
    ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
    if (!svgfInside(pixel)) return;
    float depth = texelFetch(depthtex1, pixel, 0).r;
    if (depth == 1.0) {
        svgfStoreGuide(pixel, 0, vec3(0.0, 1.0, 0.0), vec3(0.0, 1.0, 0.0), 0.0, 0.0, 0u);
        return;
    }
    DeferredMaterial mat = unpackMaterialData(pixel);
    vec3 position = screenToPlayerPos(vec3((vec2(pixel) + 0.5) * internalTexelSize, depth)).xyz;
    float viewZ = -(gbufferModelView * vec4(position, 1.0)).z;
    svgfStoreGuide(pixel, 0, mat.geoNormal, mat.textureNormal, mat.roughness,
                  viewZ, svgfOwnsVirtualDiffuse(mat.roughness,mat.albedo.rgb,mat.geoNormal,mat.textureNormal,mat.isHand)
                  ? 4u : (luminance(mat.albedo) < 0.001 ? 0u : (mat.isHand ? 3u : 1u)));
}
