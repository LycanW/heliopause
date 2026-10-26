/***************************************************************************
 # Copyright (c) 2015-23, NVIDIA CORPORATION. All rights reserved.
 #
 # Redistribution and use in source and binary forms, with or without
 # modification, are permitted provided that the following conditions
 # are met:
 #  * Redistributions of source code must retain the above copyright
 #    notice, this list of conditions and the following disclaimer.
 #  * Redistributions in binary form must reproduce the above copyright
 #    notice, this list of conditions and the following disclaimer in the
 #    documentation and/or other materials provided with the distribution.
 #  * Neither the name of NVIDIA CORPORATION nor the names of its
 #    contributors may be used to endorse or promote products derived
 #    from this software without specific prior written permission.
 #
 # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS "AS IS" AND ANY
 # EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 # IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 # PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 # CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 # EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 # PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 # PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 # OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 # (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 # OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 **************************************************************************/
// Adapted from Falcor SVGFCommon / SVGFAtrous. Heliopause extensions
// distinguish geometric and shading guides and keep variance in standard-deviation
// form in FP16 scratch; moment accumulation itself remains FP32.
#ifndef HELIOPAUSE_SVGF_COMMON
#define HELIOPAUSE_SVGF_COMMON
#include "/program/svgf/guides.glsl"
#ifdef SVGF_SPECULAR
layout(rgba16f) uniform image2D svgfMirrorImage;
#endif
float svgfLobeWidth(SvgfGuide g){return sqrt(g.roughness*g.roughness+2.0*(1.0-g.normalLength));}
// History has published this frame's guide for every specular pixel, including
// inactive classes. Use that one atlas layer throughout reconstruction: primary
// pixels contain their canonical normal mean; all other guides are exact copies.
ivec2 svgfReconstructionCoord(ivec2 p){
    #ifdef SVGF_SPECULAR
    return svgfCoord(p,2);
    #else
    return p;
    #endif
}
SvgfGuide svgfReconstructionGuide(ivec2 p){
    #ifdef SVGF_SPECULAR
    return svgfReadGuide(p,2);
    #else
    return svgfReadGuide(p,0);
    #endif
}
#ifdef SVGF_SPECULAR
const int svgfSlowLayer = 2;
const int svgfFastLayer = 3;
const int svgfPreviousGuide = 2;
const int svgfMomentLayer = 1;
const float svgfHistoryLimit = float(SVGF_SPECULAR_HISTORY);
#else
const int svgfSlowLayer = 0;
const int svgfFastLayer = 1;
const int svgfPreviousGuide = 1;
const int svgfMomentLayer = 0;
const float svgfHistoryLimit = float(SVGF_DIFFUSE_HISTORY);
#endif

bool svgfActive(SvgfGuide g) {
    #ifdef SVGF_VIRTUAL_DIFFUSE
        return g.kind == 2u;
    #else
        return g.kind==1u || g.kind==2u || g.kind==3u || g.kind==5u || g.kind==7u;
    #endif
}
bool svgfSkip(SvgfGuide g) {
    #ifdef SVGF_VIRTUAL_DIFFUSE
        return g.kind!=2u && g.kind!=6u && g.kind!=7u;
    #elif !defined SVGF_SPECULAR
        return g.kind==4u;
    #else
        return false;
    #endif
}
// Detection needs luminance, not a second RGB reconstruction. Fast history
// stores {fast luminance, independent reference luminance, reference age, hold}.
vec2 svgfDetectionMeans(ivec2 p) {
    #ifdef SVGF_VIRTUAL_DIFFUSE
        return texelFetch(colortex12,p,0).rg;
    #elif defined SVGF_SPECULAR
        return texelFetch(colortex10,p,0).rg;
    #else
        return svgfReadScratch(p,2).rg;
    #endif
}
float svgfDetectionWindow(SvgfGuide guide){
    // Detection estimates must cover the complete 16-phase subpixel cycle.
    // Virtual specular continuations are sparse and use two such cycles.
    #ifdef SVGF_SPECULAR
    if(guide.kind==2u||guide.kind==5u||guide.kind==7u)
        return max(float(SVGF_FAST_HISTORY),32.0);
    #endif
    return max(float(SVGF_FAST_HISTORY),16.0);
}
float svgfLuma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
float svgfSquare(float v) { return v * v; }
float svgfLimit(SvgfGuide guide) {
    #ifdef SVGF_VIRTUAL_DIFFUSE
    return float(SVGF_MIRROR_HISTORY);
    #endif
    #ifdef SVGF_SPECULAR
        if (guide.kind == 2u || guide.kind == 5u || guide.kind == 7u) return float(SVGF_MIRROR_HISTORY);
    #endif
    return svgfHistoryLimit;
}

float svgfPlaneWeight(ivec2 other, SvgfGuide cg, SvgfGuide pg, vec3 centerPosition) {
    if (!svgfActive(cg) || pg.kind != cg.kind) return 0.0;
    vec3 displacement = svgfPosition(other, pg.viewZ) - centerPosition;
    float separation = max(abs(dot(displacement, cg.geoNormal)),
                           abs(dot(displacement, pg.geoNormal)));
    float planeScale = max(0.005, svgfPixelWorldSize(cg.viewZ));
    float geoWeight = pow(max(dot(cg.geoNormal, pg.geoNormal), 0.0), 32.0);
    return exp(-separation / planeScale) * geoWeight;
}
float svgfGeometryWeight(ivec2 other, SvgfGuide cg, SvgfGuide pg, vec3 centerPosition) {
    float geometric=svgfPlaneWeight(other,cg,pg,centerPosition);
    if(geometric<=0.0)return 0.0;
    float normalWeight = pow(max(dot(cg.shadeNormal, pg.shadeNormal), 0.0), 128.0);
    #ifdef SVGF_SPECULAR
        // Reflection directions move twice as far as their shading normals.
        // Match their angular support to the sampled GGX alpha, with a floor
        // covering the existing normal encoding's angular quantization.
        vec3 otherPosition=svgfPosition(other,pg.viewZ);
        vec3 origin=gbufferModelViewInverse[3].xyz;
        vec3 reflectedCenter=reflect(normalize(centerPosition-origin),cg.shadeNormal);
        vec3 reflectedOther=reflect(normalize(otherPosition-origin),pg.shadeNormal);
        float width=max(0.04,min(svgfLobeWidth(cg),svgfLobeWidth(pg)));
        normalWeight=exp(-dot(reflectedCenter-reflectedOther,reflectedCenter-reflectedOther)/(width*width));
    #endif
    float roughnessWeight = 1.0;
    #ifdef SVGF_SPECULAR
        roughnessWeight = exp(-abs(cg.roughness - pg.roughness) /
                              max(0.01, 0.2 * max(cg.roughness, pg.roughness)));
    #endif
    return geometric * normalWeight * roughnessWeight;
}
float svgfSpatialWeight(ivec2 center, ivec2 other, SvgfGuide cg, SvgfGuide pg,
                        float lc, float lp, float phiLuminance, vec3 centerPosition) {
    float weight = svgfGeometryWeight(other, cg, pg, centerPosition);
    if(weight<=0.0)return 0.0;
    // A raw MC segment length is not a geometric guide for the spatially and
    // temporally integrated RGB estimate. Conditioning its kernel on that one
    // sample selects light paths and keeps the filter changing in a static view.
    return weight * exp(-abs(lc - lp) / max(phiLuminance, 1e-6));
}
#endif
