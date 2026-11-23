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
float scene(vec3 p){
    float distance = sdSphere(p - vec3(0.0, 0.0, -4.0), 1.0); //move the sphere to (0,0,-4)
    return -distance;
}


void main(){
    float a = fs_UV.y < 0.5 ? 0.5: 0.0;
    out_Col = vec4(vec3(1.0)*a, a); //premultiply rgb * a
}