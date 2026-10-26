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
// Falcor SVGFAtrous kernel and squared-weight variance propagation.
// First iteration publishes independent slow/fast histories and previous guides
// AFTER temporal history reads have completed. Later iterations never read them.
#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/spaceConversion.glsl"
#include "/program/svgf/common.glsl"
#if SVGF_LAST_PASS
#ifdef SVGF_SPECULAR
layout(rgba16f) uniform writeonly image2D colorimg2;
#endif
#endif
void main() {
    ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
    if (!svgfInside(pixel)) return;
    const int src = SVGF_ATROUS_INDEX == 0 ? 2 : ((SVGF_ATROUS_INDEX & 1) == 0 ? 1 : 0);
    const int dst = (SVGF_ATROUS_INDEX & 1) == 0 ? 0 : 1;
    const int stride = 1 << SVGF_ATROUS_INDEX;
    SvgfGuide cg=svgfReconstructionGuide(pixel);
    if(svgfSkip(cg)||!svgfActive(cg))return;
    vec4 center=svgfReadScratch(pixel,src);
    vec3 centerPosition = svgfActive(cg) ? svgfPosition(pixel, cg.viewZ) : vec3(0.0);
    float variance = 0.0,varianceWeight=0.0;
    for (int y = -1; y <= 1; ++y) for (int x = -1; x <= 1; ++x) {
        ivec2 q = clamp(pixel + ivec2(x, y), ivec2(0), ivec2(internalScreenSize) - 1);
        float w = (x == 0 ? 0.5 : 0.25) * (y == 0 ? 0.5 : 0.25);
        if((texelFetch(svgfGeometry,svgfReconstructionCoord(q),0).w&7u)==cg.kind){
            variance += w * svgfSquare(svgfReadScratch(q, src).a);varianceWeight+=w;
        }
    }
    float phiLuminance = 4.0 * sqrt(max(variance / varianceWeight, 1e-10));
    const float kernel[3] = float[3](1.0, 2.0 / 3.0, 1.0 / 6.0);
    float sumW = 1.0;
    vec3 sumColor = center.rgb;
    float sumVariance = svgfSquare(center.a);
    if (svgfActive(cg)) {
        for (int y = -2; y <= 2; ++y) for (int x = -2; x <= 2; ++x) {
            if (x == 0 && y == 0) continue;
            ivec2 q = pixel + ivec2(x, y) * stride;
            if (!svgfInside(q)) continue;
            SvgfGuide pg = svgfReconstructionGuide(q);
            vec4 value = svgfReadScratch(q, src);
            float w = kernel[abs(x)] * kernel[abs(y)] *
                      svgfSpatialWeight(pixel, q, cg, pg, svgfLuma(center.rgb),
                                        svgfLuma(value.rgb), phiLuminance, centerPosition);
            if(w<=0.0)continue;
            sumW += w;
            sumColor += w * value.rgb;
            sumVariance += w * w * svgfSquare(value.a);
        }
    }
    vec4 filtered = vec4(sumColor / sumW, sqrt(max(sumVariance, 0.0)) / sumW);
    #if SVGF_LAST_PASS
        #ifdef SVGF_SPECULAR
        imageStore(colorimg2,pixel,vec4(filtered.rgb,0.0));
        #else
        svgfWriteScratch(pixel,2,filtered);
        #endif
    #else
        svgfWriteScratch(pixel, dst, filtered);
    #endif
}
