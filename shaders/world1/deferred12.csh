#version 430 compatibility
#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
layout(r11f_g11f_b10f)uniform writeonly image2D colorimg12;
layout(local_size_x=8,local_size_y=8)in;
void main(){ivec2 p=ivec2(gl_GlobalInvocationID.xy);if(any(greaterThanEqual(p,ivec2(internalScreenSize))))return;imageStore(colorimg12,p,texelFetch(colortex2,p,0));}
#include "/program/svgf/dispatch.glsl"
