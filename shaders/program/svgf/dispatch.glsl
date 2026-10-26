#if TAA_UPSCALING_FACTOR == 100
const vec2 workGroupsRender=vec2(1.0,1.0);
#elif TAA_UPSCALING_FACTOR == 83
const vec2 workGroupsRender=vec2(0.83,0.83);
#elif TAA_UPSCALING_FACTOR == 75
const vec2 workGroupsRender=vec2(0.75,0.75);
#elif TAA_UPSCALING_FACTOR == 66
const vec2 workGroupsRender=vec2(0.66,0.66);
#elif TAA_UPSCALING_FACTOR == 50
const vec2 workGroupsRender=vec2(0.5,0.5);
#elif TAA_UPSCALING_FACTOR == 33
const vec2 workGroupsRender=vec2(0.33,0.33);
#else
const vec2 workGroupsRender=vec2(0.25,0.25);
#endif
