#ifndef HELIOPAUSE_RELAX_GUIDES
#define HELIOPAUSE_RELAX_GUIDES
// Copyright (c) 2022, NVIDIA CORPORATION. All rights reserved.
// NRD.hlsli: _NRD_EncodeNormalRoughness101010, encoded into FP16 atlas storage.
// This software contains source code provided by NVIDIA Corporation.
vec3 nrEncodeNormalRoughness(vec3 n, float roughness) {
    n /= abs(n.x)+abs(n.y)+abs(n.z);
    float y=n.y*0.5+0.5;
    float r=max(roughness,1.5/512.0);
    return vec3(n.x*0.5+y,y-n.x*0.5,(n.z<0.0?-r:r)*0.5+0.5);
}

#endif
