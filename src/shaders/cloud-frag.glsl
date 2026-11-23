#version 300 es
precision highp float;

in vec2 fs_UV;
out vec4 out_Col;

uniform mat4 u_InvViewProj;
uniform vec3 u_CameraPos;

uniform sampler2D u_Noise;
uniform float u_Time;

#define MAX_STEPS 100 // maxime
const float MARCH_SIZE = 0.08; //maxime

//from maxime heckel
float noise(vec3 x) {
  vec3 p = floor(x);
  vec3 f = fract(x);
  vec3 u = f * f * (3. - 2. * f);

  vec2 uv = (p.xy + vec2(37.0, 239.0) * p.z) + u.xy;
  vec2 tex = textureLod(u_Noise,(uv + 0.5) / 256.0, 0.0).yx;

  return mix( tex.x, tex.y, u.z ) * 2.0 - 1.0;
}

//also from maxime heckel
float fbm(vec3 p){
    vec3 q = p + u_Time * 0.5 * vec3(1.0, -0.2, -1.0);

    float f = 0.0; //running sum
    float amplitude = 0.5; //amplitude
    float factor = 2.02; //frequency multiplier

    for(int i = 0; i < 6; i++){
        f += amplitude *noise(q);
        q *= factor; //next octave higher frequency
        factor += 0.21;
        amplitude *= 0.5; //next octave is half the strength
    }
    return f;
}

float sdfSphere(vec3 p, float radius){
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
    float distance = sdfSphere(p - vec3(0.0, 0.0, -4.0), 1.0); //move the sphere to (0,0,-4)
    float f = fbm(p);
    
    return -distance + f; //negated SDF + fbm
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