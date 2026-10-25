#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/program/relax/resources.glsl"
layout(local_size_x=8,local_size_y=8) in;
void main(){
    ivec2 pixel=ivec2(gl_GlobalInvocationID.xy);
    if(any(greaterThanEqual(pixel,ivec2(internalScreenSize))))return;
    vec4 signal=texelFetch(colortex2,pixel,0);
    nrStore(0,ivec2(pixel.x,int(internalScreenSize.y)-1-pixel.y),signal);
}
