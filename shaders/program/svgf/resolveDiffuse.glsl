#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/spaceConversion.glsl"
#include "/program/svgf/common.glsl"
#include "/program/svgf/reconstructDiffuse.glsl"
layout(rgba16f) uniform writeonly image2D colorimg2;
layout(r11f_g11f_b10f) uniform writeonly image2D colorimg12;
void main(){
    ivec2 pixel=ivec2(gl_GlobalInvocationID.xy);if(!svgfInside(pixel))return;
    SvgfGuide cg=svgfReadGuide(pixel,0);
    vec4 result=vec4(0.0);
    if(!svgfSkip(cg)&&svgfActive(cg))result=svgfRoundHalf(vec4(svgfReconstructDiffuse(pixel,cg),0.0));
    imageStore(colorimg2,pixel,result);
    // This is the exact half-float diffuse output consumed by screen-space
    // reflection lighting. Publish it here instead of copying it after composition.
    imageStore(colorimg12,pixel,result);
}
