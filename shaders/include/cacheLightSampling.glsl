// Balance-heuristic MIS for the direct-specular part of cached irradiance.
// Hemisphere samples retain all paths. Three additional proposals target the
// principal-axis surface classes; actual intersections decide which class exists.
// The proposal alpha is the effective GGX alpha of the cache's roughness floor.
const float cacheLightProposalAlpha=0.2*0.2;
const float cacheHemispherePdf=1.0/(2.0*PI);

int cacheLightSurfaceAxis(vec3 normal){
    if(abs(normal.x)>0.99999)return 0;
    if(abs(normal.y)>0.99999)return 1;
    if(abs(normal.z)>0.99999)return 2;
    return -1;
}
vec3 cacheLightAxisNormal(int axis){
    vec3 n=vec3(0.0);
    n[axis]=shadowDir[axis]<0.0?-1.0:1.0;
    return n;
}
float cacheLightProposalPdf(vec3 outgoing,vec3 normal){
    float NoL=dot(normal,shadowDir),NoV=dot(normal,outgoing);
    if(NoL<=0.0||NoV<=0.0)return 0.0;
    vec3 h=normalize(shadowDir+outgoing);
    float NoH=max(dot(normal,h),0.0);
    float a2=cacheLightProposalAlpha*cacheLightProposalAlpha;
    float lower=NoH*NoH*(a2-1.0)+1.0;
    float distribution=a2/(PI*lower*lower);
    // Visible-normal reflection PDF (Heitz 2018, equations 3 and 17).
    float smithRoot=sqrt(a2+(1.0-a2)*NoL*NoL);
    return distribution/(2.0*(NoL+smithRoot));
}
float cacheLightUniformWeight(vec3 direction,vec3 surfaceNormal){
    int axis=cacheLightSurfaceAxis(surfaceNormal);
    if(axis<0)return 1.0;
    float proposal=cacheLightProposalPdf(-direction,cacheLightAxisNormal(axis));
    float uniformWeight=float(IRCACHE_SAMPLES)*cacheHemispherePdf;
    return uniformWeight/(uniformWeight+proposal);
}
