// Sample canonical diffuse illumination at this frame's jittered receiver.
// The current pixel is always inside this four-tap footprint, so a supported
// receiver has positive geometric support without a replacement value.
vec3 svgfReconstructDiffuse(ivec2 pixel,SvgfGuide cg){
    vec2 p=vec2(pixel)-0.5*taaOffset*internalScreenSize;
    ivec2 base=ivec2(floor(p));vec2 f=fract(p);
    vec3 position=svgfPosition(pixel,cg.viewZ),sum=vec3(0.0);float total=0.0;
    for(int j=0;j<4;++j){
        ivec2 q=base+ivec2(j&1,j>>1);if(!svgfInside(q))continue;
        float w=((j&1)==0?1.0-f.x:f.x)*((j>>1)==0?1.0-f.y:f.y);
        SvgfGuide pg=svgfReadGuide(q,0);
        w*=svgfPlaneWeight(q,cg,pg,position);
        // Reconstruct illumination from the same shading surface as the current
        // material sample, rather than blending different normal-map responses.
        w*=pow(max(dot(cg.shadeNormal,pg.shadeNormal),0.0),128.0);
        if(w<=0.0)continue;
        sum+=w*svgfReadScratch(q,2).rgb;total+=w;
    }
    return sum/total;
}
