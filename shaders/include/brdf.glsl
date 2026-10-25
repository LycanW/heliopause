#ifndef INCLUDE_BRDF
    #define INCLUDE_BRDF

    vec3 schlickFresnel (vec3 F0, float theta)
    {  
        return F0 + (1.0 - F0) * pow(1.0 - theta, 5.0);
    }

    void evalCookBRDFTerms (
        vec3 w0, 
        vec3 w1, 
        float roughness, 
        vec3 normal, 
        vec3 albedo, 
        vec3 reflectance,
        out vec3 diffuse,
        out vec3 specular,
        out vec3 fresnelReflectance
    ) {
        w1 = -w1;

        float alpha = sqr(roughness);
        float alpha2 = sqr(alpha);

        vec3 H = normalize(w0 + w1);

        // dot products
        float NdotV = clamp(dot(normal, w1), 0.001, 1.0);
        float NdotL = clamp(dot(normal, w0), 0.001, 1.0);
        float NdotH = clamp(dot(normal, H), 0.001, 1.0);
        float VdotH = clamp(dot(w1, H), 0.001, 1.0);

        // Fresnel
        fresnelReflectance = schlickFresnel(reflectance, VdotH); //Schlick's Approximation

        // phong diffuse
        diffuse = NdotL * albedo;

        // Geometric attenuation
        float k = 0.5 * alpha;
        float geometry = (NdotL * NdotV) / (mix(k, 1.0, NdotL) * mix(k, 1.0, NdotV));

        // Distribution of Microfacets
        float lowerTerm = NdotH * NdotH * (alpha2 - 1.0) + 1.0;
        float normalDistributionFunctionGGX = alpha2 / (PI * lowerTerm * lowerTerm);

        specular = vec3(normalDistributionFunctionGGX * geometry) / (4.0 * NdotV);
    

    }
    
    vec3 evalCookBRDF(vec3 w0,vec3 w1,float roughness,vec3 normal,vec3 albedo,vec3 reflectance){
        vec3 diffuse,specular,fresnel;
        evalCookBRDFTerms(w0,w1,roughness,normal,albedo,reflectance,diffuse,specular,fresnel);
        return mix(diffuse,specular,fresnel);
    }
    void evalCookBRDFLobes(vec3 w0,vec3 w1,float roughness,vec3 normal,vec3 albedo,vec3 reflectance,out vec3 diffuse,out vec3 specular){
        vec3 d,s,f;
        evalCookBRDFTerms(w0,w1,roughness,normal,albedo,reflectance,d,s,f);
        diffuse=d*(1.0-f);specular=s*f;
    }

    vec3 sampleVNDFShared (vec3 rayDir, vec3 normal, float alpha, vec2 rand, bool foldHemisphere)
    {
        rayDir = -rayDir;

        mat3 T = tbnNormal(normal);
        vec3 rayDirT = rayDir * T;

        vec3 Vh = normalize(vec3(rayDirT.xy * alpha, rayDirT.z));

        float lensq = lengthSquared(Vh.xy);
        vec3 T1 = lensq > 0.00001 ? vec3(-Vh.y, Vh.x, 0.0) * inversesqrt(lensq) : vec3(1.0, 0.0, 0.0);
        vec3 T2 = cross(Vh, T1);

        float r = sqrt(rand.x);
        float phi = 2.0 * PI * rand.y;
        float t1 = r * cos(phi);
        float t2 = r * sin(phi);
        float s = Vh.z * 0.5 + 0.5;
        t2 = (1.0 - s) * sqrt(1.0 - t1 * t1) + s * t2;

        vec3 result = t1 * T1 + t2 * T2 + sqrt(max(0.0, 1.0 - t1 * t1 - t2 * t2)) * Vh;
        vec3 reflectedDir = -reflect(rayDirT, normalize(vec3(result.xy * alpha, max(0.0, result.z))));

        return T * (foldHemisphere?vec3(reflectedDir.xy,abs(reflectedDir.z)):reflectedDir);
    }

    vec3 sampleVNDF(vec3 rayDir,vec3 normal,float alpha,vec2 rand){return sampleVNDFShared(rayDir,normal,alpha,rand,true);}
    vec3 sampleVNDFUnfolded(vec3 rayDir,vec3 normal,float alpha,vec2 rand){return sampleVNDFShared(rayDir,normal,alpha,rand,false);}

#endif
