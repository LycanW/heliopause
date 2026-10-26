#version 430 compatibility
#define SVGF_VIRTUAL_DIFFUSE
#define SVGF_ATROUS_INDEX 1
#define SVGF_LAST_PASS 1
#include "/program/svgf/atrous.glsl"
#include "/program/svgf/dispatch.glsl"
layout(local_size_x=8,local_size_y=8)in;
