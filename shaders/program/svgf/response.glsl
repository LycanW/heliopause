#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/spaceConversion.glsl"
#include "/program/svgf/common.glsl"
// Adjust the temporal sample weight, not the sample's radiance. A local large
// change keeps a short response for one nominal history window, so agreeing
// fast/slow tracks do not immediately return to a long, lagging history.
// All neighbor reads use temporal scratch 0/2. Scratch 1, moments and age are
// updated only at this invocation's pixel; publication follows a dispatch barrier.
void main() {
    ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
    if (!svgfInside(pixel)) return;
    SvgfGuide cg=svgfReadGuide(pixel,0);
    if(svgfSkip(cg)||!svgfActive(cg))return;
    vec4 integrated=svgfReadScratch(pixel,0);
    vec2 historyState=svgfReadStats(pixel,3);
    vec2 moments=svgfReadStats(pixel,2);
    vec4 responsive=vec4(svgfDetectionMeans(pixel),svgfReadScratch(pixel,1).a,svgfReadScratch(pixel,0).a);
    float responseFrames=svgfReadScratch(pixel,0).a;
    integrated.a=sqrt(max(moments.y-moments.x*moments.x,0.0));
    if (historyState.x > float(SVGF_FAST_HISTORY) && svgfActive(cg)) {
        vec3 position = svgfPosition(pixel, cg.viewZ);
        float changes[9], weights[9];
        int count = 0;
        float sumW = 0.0;
        float belowWeight=0.0,aboveWeight=0.0;
        float freshAgreement=0.0;
        for (int y = -1; y <= 1; ++y) for (int x = -1; x <= 1; ++x) {
            ivec2 q = pixel + 4 * ivec2(x, y);
            if (!svgfInside(q)) continue;
            float w = svgfPlaneWeight(q, cg, svgfReadGuide(q, 0), position);
            if (w <= 0.0) continue;
            // A full countdown was confirmed in the preceding frame. Copied
            // countdowns start one frame lower and cannot propagate again.
            float previousHold=svgfReadScratch(q,0).a;
            if(previousHold>=svgfLimit(svgfReadGuide(q,0))-1.25)freshAgreement+=w;
            vec2 detectionMeans=svgfDetectionMeans(q);
            float slowLuma=detectionMeans.y,fastLuma=detectionMeans.x;
            float change = (fastLuma - slowLuma) / max(max(fastLuma, slowLuma), 1e-6);
            changes[count]=change;
            weights[count]=w;
            if(change < -float(SVGF_RESPONSE_THRESHOLD))belowWeight+=w;
            if(change > float(SVGF_RESPONSE_THRESHOLD))aboveWeight+=w;
            ++count;
            sumW += w;
        }
        // Weighted local agreement rejects isolated MC outliers. Spatial detail
        // is normalized per tap; no radiance sample is clamped.
        float accumulatedWeight = 0.0, contrast = 0.0;
        // The transfer function is zero on [-threshold,+threshold]. Determine
        // whether its weighted median can leave that interval before sorting.
        // Equality is included on the lower side, matching the first >= half tap.
        if(belowWeight>=0.5*sumW||aboveWeight>0.5*sumW){
        for(int i=1;i<count;++i){
            float change=changes[i],w=weights[i];int j=i;
            while(j>0&&changes[j-1]>change){changes[j]=changes[j-1];weights[j]=weights[j-1];--j;}
            changes[j]=change;weights[j]=w;
        }
        for (int i = 0; i < count; ++i) {
            accumulatedWeight += weights[i];
            if (accumulatedWeight >= 0.5 * sumW) {
                contrast = abs(changes[i]);
                break;
            }
        }
        }
        float response = smoothstep(float(SVGF_RESPONSE_THRESHOLD), 2.0 * float(SVGF_RESPONSE_THRESHOLD), contrast);
        float ownSlow=responsive.g,ownFast=responsive.r;
        float ownContrast=abs(ownFast-ownSlow)/max(max(ownFast,ownSlow),1e-6);
        // Require two newly confirmed neighbors and the recipient's own
        // contrast. The one-frame countdown offset bounds this expansion to
        // this stencil; borrowed holds never form a propagating wave.
        if(freshAgreement>=2.0&&ownContrast>float(SVGF_RESPONSE_THRESHOLD))
            responseFrames=max(responseFrames,svgfLimit(cg)-1.0);
        #ifdef SVGF_SPECULAR
        // Canonical primary colour resolves a full material/jitter cycle in the
        // detector. A larger point contrast can identify a localized highlight
        // change that should not require a majority of unrelated directions.
        if(cg.kind==1u)response=max(response,smoothstep(2.0*float(SVGF_RESPONSE_THRESHOLD),3.0*float(SVGF_RESPONSE_THRESHOLD),ownContrast));
        #endif
        if(response>=0.5){
            responseFrames=svgfLimit(cg);
            // Rebase this pixel's detector only after a confirmed change. Its
            // reference is never moved by partial RGB response corrections.
            responsive.g=responsive.r;
            responsive.b=min(responsive.b,svgfDetectionWindow(cg));
        }
        float alpha = 1.0 / historyState.x;
        float alphaFloor = responseFrames > 0.0 ? max(alpha, 1.0 / float(SVGF_FAST_HISTORY)) : alpha;
        float newAlpha = mix(alphaFloor, 1.0, response);
        if (newAlpha > alpha) {
            vec3 current = svgfReadScratch(pixel, 1).rgb;
            float luma = svgfLuma(current);
            vec2 currentMoments = vec2(luma, luma * luma);
            // Equivalent integration weight correction, expressed as a convex mix.
            // It needs no recovered-history RGB clamp or radiance replacement.
            float correction=(newAlpha-alpha)/(1.0-alpha);
            integrated.rgb=mix(integrated.rgb,current,correction);
            moments=mix(moments,currentMoments,correction);
            integrated.a = sqrt(max(moments.y - moments.x * moments.x, 0.0));
            #ifdef SVGF_SPECULAR
            if(cg.kind==1u){
                vec4 sampleGuide=vec4(cg.shadeNormal,cg.roughness*cg.roughness);
                vec4 meanGuide=imageLoad(svgfMirrorImage,pixel);
                imageStore(svgfMirrorImage,pixel,svgfRoundHalf(mix(meanGuide,sampleGuide,correction)));
            }
            #endif
            historyState.x = 1.0 / newAlpha;
        }
    }
    svgfWriteHistory(pixel,svgfFastLayer,vec4(responsive.rgb,responseFrames));
    svgfWriteScratch(pixel, 1, integrated);
    svgfWriteStats(pixel, 2, moments);
    svgfWriteStats(pixel, 3, historyState);
}
