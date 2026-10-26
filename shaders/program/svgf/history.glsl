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
// Falcor SVGFFilterMoments bootstrap and the equivalent of FeedbackTap = -1:
// publish temporal illumination, before repeated nonlinear spatial filtering.
#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/spaceConversion.glsl"
#include "/program/svgf/common.glsl"
void main() {
    ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
    if (!svgfInside(pixel)) return;
    SvgfGuide cg=svgfReadGuide(pixel,0);
    if(svgfSkip(cg))return;
    if(!svgfActive(cg)){
        // The published inactive guide invalidates all old history estimates.
        // Reconstruction reads a defined zero, while old RGB/moments need no
        // clearing: correspondence checks the guide before reading them.
        svgfCopyGuide(pixel,svgfPreviousGuide);
        svgfWriteScratch(pixel,2,vec4(0.0));
        return;
    }
    vec4 center=svgfReadScratch(pixel,1);
    float age=svgfReadStats(pixel,3).x;
    // Temporal reprojection has completed globally. Read neighborhoods below
    // only from current scratch/guides; previous-history tiles are disjoint.
    svgfWriteHistory(pixel,svgfSlowLayer,vec4(center.rgb,age));
    svgfWriteStats(pixel, svgfMomentLayer, svgfReadStats(pixel, 2));
    #ifdef SVGF_SPECULAR
    if(cg.kind==1u){
        vec4 meanGuide=imageLoad(svgfMirrorImage,pixel);
        float normalLength=length(meanGuide.rgb);
        vec3 direction=normalLength>0.0?meanGuide.rgb/normalLength:cg.geoNormal;
        svgfStoreGuideMean(pixel,svgfPreviousGuide,cg.geoNormal,direction,sqrt(meanGuide.a),normalLength,cg.viewZ,cg.kind);
    }else svgfCopyGuide(pixel,svgfPreviousGuide);
    #else
    svgfCopyGuide(pixel,svgfPreviousGuide);
    #endif
    if (age >= 4.0) {
        svgfWriteScratch(pixel, 2, center);
        return;
    }
    vec3 centerPosition = svgfPosition(pixel, cg.viewZ);
    vec3 sumColor = center.rgb;
    vec2 sumMoments = svgfReadStats(pixel, 2);
    float sumW = 1.0;
    for (int y = -3; y <= 3; ++y) for (int x = -3; x <= 3; ++x) {
        if (x == 0 && y == 0) continue;
        ivec2 q = pixel + ivec2(x, y);
        if (!svgfInside(q)) continue;
        SvgfGuide pg = svgfReadGuide(q, 0);
        vec4 value = svgfReadScratch(q, 1);
        float w = svgfSpatialWeight(pixel, q, cg, pg, svgfLuma(center.rgb),
                                    svgfLuma(value.rgb), 4.0, centerPosition);
        if(w<=0.0)continue;
        sumColor += w * value.rgb;
        sumMoments += w * svgfReadStats(q, 2);
        sumW += w;
    }
    vec2 moments = sumMoments / sumW;
    float variance = max(0.0, moments.y - moments.x * moments.x) * 4.0 / max(age, 1.0);
    svgfWriteScratch(pixel, 2, vec4(sumColor / sumW, sqrt(variance)));
}
