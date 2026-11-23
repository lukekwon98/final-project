#version 300 es
precision highp float;

in vec2 fs_UV;
out vec4 out_Col;

uniform mat4 u_InvViewProj;
uniform vec3 u_CameraPos;

#define MAX_STEPS 100 // maxime
const float MARCH_SIZE = 0.08; //maxime

float sdSphere(vec3 p, float radius){
    return length(p) - radius;
}

vec3 rayDirection(vec2 uv){
    vec2 ndc = uv * 2.0 - 1.0;
    vec4 nearP = u_InvViewProj * vec4(ndc, -1.0, 1.0);
    vec4 farP  = u_InvViewProj * vec4(ndc,  1.0, 1.0);
    return normalize(farP.xyz / farP.w - nearP.xyz / nearP.w);
}

//Density at point p. negated SDF: positive inside the sphere, max at its center, max is also radius
float sceneDensity(vec3 p){
    float distance = sdSphere(p - vec3(0.0, 0.0, -4.0), 1.0); //move the sphere to (0,0,-4)
    return -distance;
}

vec4 raymarch(vec3 rayOrigin, vec3 rayDirection){
    float t = 0.0;
    vec3 p = rayOrigin + t * rayDirection;

    vec4 result = vec4(0.0);

    for(int i = 0; i < MAX_STEPS; i++){
        float density = sceneDensity(p);

        //only draw density if it's greater than 0 (inside the sdf)
        if(density > 0.0){
            vec4 color = vec4(mix(vec3(1.,1.,1.), vec3(0.,0.,0.), density), density);
            color.rgb *= color.a; //multiply color with density
            result += color * (1.0 - result.a);
        }

        t += MARCH_SIZE;
        p = rayOrigin + t * rayDirection;
    }

    return result;
}


void main(){

    vec3 rayOrig = u_CameraPos;
    vec3 rayDir = rayDirection(fs_UV);

    out_Col = raymarch(rayOrig, rayDir);

    //debug
    //float a = fs_UV.y < 0.5 ? 0.5: 0.0;
    //out_Col = vec4(vec3(1.0)*a, a); //premultiply rgb * a
}