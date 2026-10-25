#version 430 compatibility
#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#define NR_ATROUS_INDEX 0
#define NR_LAST_PASS (RELAX_ATROUS_PASSES==1)
#define NR_OUTPUT_COLOR2
#include "/program/relax/official_diffuse_historyclamping.glsl"
#include "/program/relax/dispatch.glsl"
