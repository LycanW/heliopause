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
// Falcor geometric bilinear reprojection and moment integration; extensions:
// short history, view-dependent specular history, and correction of REUSED
// history before integrating the current sample. There is no current-sample clamp.
#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/spaceConversion.glsl"
#include "/program/svgf/common.glsl"

#if defined SVGF_VIRTUAL_DIFFUSE || defined SVGF_SPECULAR
layout(r11f_g11f_b10f) uniform writeonly image2D colorimg12;
#endif
#ifdef SVGF_SPECULAR
layout(rgba16f) uniform writeonly image2D colorimg10;
#include "/program/svgf/reconstructDiffuse.glsl"
#endif
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

vec3 svgfPreviousPosition(ivec2 pixel, float viewZ) {
    vec2 ndc = (vec2(pixel) + 0.5) * internalTexelSize * 2.0 - 1.0 - taaOffsetPrev;
    float clipW = -gbufferPreviousProjection[2][3] * viewZ + gbufferPreviousProjection[3][3];
    vec2 xy = (ndc * clipW + gbufferPreviousProjection[2].xy * viewZ - gbufferPreviousProjection[3].xy) /
              vec2(gbufferPreviousProjection[0][0], gbufferPreviousProjection[1][1]);
    vec3 view = vec3(xy, -viewZ);
    return transpose(mat3(gbufferPreviousModelView)) * (view - gbufferPreviousModelView[3].xyz);
}
bool svgfHistoryCorresponds(ivec2 tap, SvgfGuide cg, vec3 position) {
    if (!svgfInside(tap)) return false;
    SvgfGuide pg = svgfReadGuide(tap, svgfPreviousGuide);
    if (pg.kind != cg.kind || !svgfActive(pg)) return false;
    vec3 delta = svgfPreviousPosition(tap, pg.viewZ) - cameraVelocity - position;
    float footprint = max(0.005, 1.5 * svgfPixelWorldSize(cg.viewZ));
    if (max(abs(dot(delta, cg.geoNormal)), abs(dot(delta, pg.geoNormal))) > footprint) return false;
    if (dot(cg.geoNormal, pg.geoNormal) < 0.95) return false;
    #ifdef SVGF_SPECULAR
        if(cg.kind!=1u){
        vec3 origin=gbufferModelViewInverse[3].xyz;
        vec3 previousOrigin=-transpose(mat3(gbufferPreviousModelView))*gbufferPreviousModelView[3].xyz;
        vec3 previousPosition=svgfPreviousPosition(tap,pg.viewZ);
        vec3 r=reflect(normalize(position-origin),cg.shadeNormal);
        vec3 pr=reflect(normalize(previousPosition-previousOrigin),pg.shadeNormal);
        if(distance(r,pr)>2.0*max(0.04,min(cg.roughness,pg.roughness)))return false;
        }
    #else
        float shadeTolerance = mix(0.06, 0.35, sqrt(cg.roughness));
        if (distance(cg.shadeNormal, pg.shadeNormal) > shadeTolerance) return false;
    #endif
    #ifdef SVGF_SPECULAR
        if (cg.kind!=1u && abs(cg.roughness - pg.roughness) > max(0.01, 0.2 * max(cg.roughness, pg.roughness))) return false;
    #endif
    return true;
}
void main() {
    ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
    if (!svgfInside(pixel)) return;
    SvgfGuide cg = svgfReadGuide(pixel, 0);
    #ifdef SVGF_SPECULAR
    // Virtual diffuse has completed all spatial passes. Its scratch tile stays
    // immutable throughout this dispatch; specular detector output uses the now
    // dead factor buffer instead. No neighboring read aliases a concurrent write.
    if(cg.kind==2u){
        vec4 prefix=imageLoad(svgfMirrorImage,pixel);
        prefix.rgb+=svgfReconstructDiffuse(pixel,cg)*texelFetch(colortex10,pixel,0).rgb;
        imageStore(svgfMirrorImage,pixel,prefix);
    }
    if(cg.kind==2u||cg.kind==6u||cg.kind==7u)imageStore(colorimg12,pixel,vec4(0.0));
    #endif
    if (svgfSkip(cg)||!svgfActive(cg)) return;
    #ifdef SVGF_VIRTUAL_DIFFUSE
        vec4 noisy = svgfReadScratch(pixel,2);
    #else
        vec4 noisy = texelFetch(colortex2, pixel, 0);
    #endif
    vec3 oldSlow = vec3(0.0), oldDetection = vec3(0.0);
    vec2 oldMoments = vec2(0.0);
    float oldAge = 0.0, support = 0.0, oldResponseFrames = 0.0;
    vec3 oldMeanNormal=vec3(0.0);float oldMeanAlpha2=0.0;
    vec3 position = svgfActive(cg) ? svgfPosition(pixel, cg.viewZ) : vec3(0.0);
    if (frameCounter > 1 && svgfActive(cg) && cg.kind != 3u) {
        vec3 historyPosition=position;
        vec2 historyJitter=taaOffsetPrev;
        bool canProject=true;
        bool canonicalHistory=true;
        #ifdef SVGF_SPECULAR
        canonicalHistory=cg.kind==1u;
        #endif
        if(canonicalHistory){
        vec3 origin=gbufferModelViewInverse[3].xyz;
        float clipW=-gbufferProjection[2][3]*cg.viewZ+gbufferProjection[3][3];
        vec3 actualRay=position-origin;
        vec3 canonicalRay=actualRay+mat3(gbufferModelViewInverse)*vec3(taaOffset*clipW/vec2(gbufferProjection[0][0],gbufferProjection[1][1]),0.0);
        float na=dot(cg.geoNormal,actualRay),nc=dot(cg.geoNormal,canonicalRay);
        canProject=na*nc>0.0 && abs(nc)>1e-6*length(canonicalRay);
        if(canProject)historyPosition=origin+canonicalRay*(na/nc);
        historyJitter=vec2(0.0);
        }
        vec4 prevClip = gbufferPreviousModelViewProjection * vec4(historyPosition + cameraVelocity, 1.0);
        if (canProject && prevClip.w > 0.0) {
            vec2 prevPixel = ((prevClip.xy / prevClip.w + historyJitter) * 0.5 + 0.5) *
                             internalScreenSize - 0.5;
            ivec2 base = ivec2(floor(prevPixel));
            vec2 f = fract(prevPixel);
            for (int j = 0; j < 4; ++j) {
                ivec2 tap = base + ivec2(j & 1, j >> 1);
                float w = ((j & 1) == 0 ? 1.0 - f.x : f.x) *
                          ((j >> 1) == 0 ? 1.0 - f.y : f.y);
                if (w > 0.0 && svgfHistoryCorresponds(tap, cg, position)) {
                    vec4 hs = svgfReadHistory(tap, svgfSlowLayer);
                    oldSlow += w * hs.rgb;
                    vec4 responsive = svgfReadHistory(tap, svgfFastLayer);
                    oldDetection += w * responsive.rgb;
                    oldResponseFrames += w * responsive.a;
                    oldMoments += w * svgfReadStats(tap, svgfMomentLayer);
                    oldAge += w * hs.a;
                    #ifdef SVGF_SPECULAR
                    if(cg.kind==1u){
                        SvgfGuide pg=svgfReadGuide(tap,svgfPreviousGuide);
                        oldMeanNormal+=w*pg.shadeNormal*pg.normalLength;
                        oldMeanAlpha2+=w*pg.roughness*pg.roughness;
                    }
                    #endif
                    support += w;
                }
            }
        }
    }
    if (support > 0.0) {
        oldSlow /= support;
        oldDetection /= support;
        oldResponseFrames /= support;
        oldMoments /= support;
        // Normalize the age of the same valid estimate used for RGB and moments.
        oldAge /= support;
        oldMeanNormal/=support;oldMeanAlpha2/=support;
    }
    #ifdef SVGF_SPECULAR
        if (oldAge > 0.0) {
            vec3 oldOrigin = -transpose(mat3(gbufferPreviousModelView)) * gbufferPreviousModelView[3].xyz;
            vec3 v = normalize(position - gbufferModelViewInverse[3].xyz);
            vec3 pv = normalize(position + cameraVelocity - oldOrigin);
            // Preserve accuracy for stationary and nearly parallel directions.
            float angle=atan(length(cross(v,pv)),clamp(dot(v,pv),-1.0,1.0));
            oldAge *= exp(-angle / max(0.025, cg.roughness));
        }
    #endif
    float age = svgfActive(cg) ? min(svgfLimit(cg), oldAge + 1.0) : 0.0;
    float alpha = 1.0 / max(age, 1.0);
    float detectionAge=svgfActive(cg)?min(svgfLimit(cg),oldDetection.b+1.0):0.0;
    float fastAlpha=1.0/max(1.0,min(detectionAge,svgfDetectionWindow(cg)));
    float referenceAlpha=1.0/max(1.0,detectionAge);
    // Both histories observe the same geometry-guided estimate. Prefiltering
    // only the responsive track would give the clamp incompatible statistics.
    // Weights contain no noisy radiance or stochastic hit-distance term.
    vec3 currentInput = noisy.rgb;
    #ifdef SVGF_SPECULAR
        const float radius = float(SVGF_SPECULAR_PREPASS);
    #else
        #ifdef SVGF_VIRTUAL_DIFFUSE
        const float radius = float(SVGF_SPECULAR_PREPASS);
        #else
        const float radius = float(SVGF_DIFFUSE_PREPASS);
        #endif
    #endif
    if (svgfActive(cg) && radius > 0.0) {
        // Separated samples avoid giving neighboring responsive histories the
        // same tight-box input, which understates their spatial variance.
        // Geometry and shading normals stop sampling across receiver edges.
        const vec2 disk[8] = vec2[8](
            vec2(0.250000, 0.000000), vec2(-0.319290, 0.292496),
            vec2(0.048873, -0.556876), vec2(0.402444, 0.524918),
            vec2(-0.738535, -0.130636), vec2(0.699605, -0.445032),
            vec2(-0.234046, 0.870660), vec2(-0.446272, -0.859268));
        // Float multiplication loses all fractional phase at large frame counts.
        uint rotationPhase=uint(frameCounter)*0x9e3779b9u;
        float angle=6.28318530718*(float(rotationPhase>>8u)*(1.0/16777216.0));
        mat2 rotation = mat2(cos(angle), sin(angle), -sin(angle), cos(angle));
        vec3 sumColor = noisy.rgb;
        float sumW = 1.0;
        for (int i = 0; i < 8; ++i) {
            ivec2 q = pixel + ivec2(round(radius * rotation * disk[i]));
            if (!svgfInside(q)) continue;
            float w = svgfGeometryWeight(q, cg, svgfReadGuide(q, 0), position);
            if(w<=0.0)continue;
            #ifdef SVGF_VIRTUAL_DIFFUSE
            sumColor += w * svgfReadScratch(q,2).rgb;
            #else
            sumColor += w * texelFetch(colortex2, q, 0).rgb;
            #endif
            sumW += w;
        }
        currentInput = sumColor / sumW;
    }
    float luma = svgfLuma(currentInput);
    vec3 detectionState=vec3(mix(oldDetection.r,luma,fastAlpha),mix(oldDetection.g,luma,referenceAlpha),detectionAge);

    // Responsive-history neighborhoods are read in the following dispatch,
    // after every pixel has completed its own geometric reprojection.
    vec2 moments = mix(oldMoments, vec2(luma, luma * luma), alpha);
    float variance = max(0.0, moments.y - moments.x * moments.x);
    vec3 integrated = mix(oldSlow, currentInput, alpha);
    #ifdef SVGF_SPECULAR
    if(cg.kind==1u){
        vec4 meanGuide=vec4(mix(oldMeanNormal,cg.shadeNormal,alpha),mix(oldMeanAlpha2,cg.roughness*cg.roughness,alpha));
        imageStore(svgfMirrorImage,pixel,svgfRoundHalf(meanGuide));
    }
    #endif
    svgfWriteScratch(pixel,0,vec4(integrated,max(oldResponseFrames-1.0,0.0)));
    // The next dispatch reads only its own prefiltered sample before replacing
    // this tile with reconstruction output; neighborhood reads use tiles 0/2.
    #ifdef SVGF_VIRTUAL_DIFFUSE
    svgfWriteScratch(pixel,1,vec4(currentInput,detectionAge));
    imageStore(colorimg12,pixel,vec4(svgfRoundR11(vec3(detectionState.rg,0.0)),0.0));
    #else
    svgfWriteScratch(pixel,1,vec4(currentInput,detectionAge));
    #ifdef SVGF_SPECULAR
    imageStore(colorimg10,pixel,svgfRoundHalf(vec4(detectionState,0.0)));
    #else
    svgfWriteScratch(pixel,2,vec4(detectionState,max(oldResponseFrames-1.0,0.0)));
    #endif
    #endif
    svgfWriteStats(pixel, 2, moments);
    svgfWriteStats(pixel, 3, vec2(age,0.0));
}
