#version 430 compatibility
#define SVGF_VIRTUAL_DIFFUSE
#include "/program/svgf/history.glsl"
#include "/program/svgf/dispatch.glsl"
layout(local_size_x=8,local_size_y=8)in;
