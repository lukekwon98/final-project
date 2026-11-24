#version 300 es
precision highp float;

in vec2 fs_UV;
out vec4 out_Col;

uniform mat4 u_InvViewProj;
uniform vec3 u_CameraPos;

uniform sampler2D u_Noise;
uniform sampler2D u_BlueNoise; //64^2 tileable blue noise
uniform float u_Time;
uniform vec3 u_LightDir;
uniform vec3 u_LightColor;
uniform vec3 u_AmbientColor;    
uniform float u_Aniso;
uniform int u_Frame;
uniform float u_AmbientStrength;
uniform float u_CloudLight;
uniform float u_NoiseScale;

#define MAX_STEPS 100 // maxime
#define MAX_STEPS_LIGHTS 6 // samples toward the sun

uniform float u_Absorption; //maxime
const float MARCH_SIZE = 0.16; //maxime

const float LIGHT_MARCH_SIZE = 0.03; //base step for samples toward the sun

//horizontal cloud slab below the camera, starts at y = 0;
const float CLOUD_BOTTOM = -2.5;
const float CLOUD_TOP = -1.5;
const float FBM_MARGIN = 1.0; //fbm can add up to 0.98 density, so puffs can rise this far past the slab

//cloud chunk placement
const vec3 CLOUD_CENTER = vec3(0.0, 1.5, -20.0);
const float BOUND_RADIUS = 9.0; //sphere enclosing every blob + fbm margin, so we only march inside it

#define PI 3.14159265359

#define CLOUD_SLAB 0
#define ACTUAL_CLOUD 1

//iq's polynomial smooth min
float smoothmin(float a, float b, float k){
    float h = clamp(0.5 + 0.5 * (b-a) / k, 0.0, 1.0);
    return mix(b,a,h) - k *h * (1.0 - h);
}

//ray vs bounding sphere (tEnter, tExit), tEnter > tExit means miss
vec2 intersectBoundingSphere(vec3 ro, vec3 rd){
    vec3 centerToOrigin = ro - CLOUD_CENTER; //offset of ray origin from center
    float tClosest = -dot(centerToOrigin, rd); //projection of center offset on the ray

    float centerDistSq = dot(centerToOrigin, centerToOrigin) - tClosest * tClosest;
    float halfChordSq = BOUND_RADIUS * BOUND_RADIUS - centerDistSq; //part of the line that exists within the sphere

    if(halfChordSq < 0.0){
        return vec2(1.0,0.0); //miss
    }

    float halfChord = sqrt(halfChordSq);
    float tEnter = max(tClosest - halfChord, 0.0);
    float tExit = tClosest + halfChord;

    return vec2(tEnter, tExit);
}

//from maxime heckel
float noise(vec3 x) {
    vec3 p = floor(x); //3d grid
    vec3 f = fract(x); //offset within 3d grid
    vec3 u = f * f * (3. - 2. * f); //smoothstepping offset within 3d grid

    //offset the 2D noise texture by different xy values to create different "slice", depending on the z value
    //p.xy = integer corner, u.xy: how far into the cell, + 0.5, exactly on texel centers
    vec2 uv = (p.xy + vec2(37.0, 239.0) * p.z) + u.xy;
    vec2 tex = textureLod(u_Noise,(uv + 0.5) / 256.0, 0.0).yx; //y(G) is this slice, x(R) is neighboring slice, texel i covers the span from i to i+1, LINEAR filtering returns exactly texel i's value only at its center

    return mix( tex.x, tex.y, u.z ) * 2.0 - 1.0;
}

//SDF of infinite horizontal slab
float sdfSlab(vec3 p){
    float center = 0.5 * (CLOUD_TOP + CLOUD_BOTTOM); //middle height
    float halfH = 0.5 * (CLOUD_TOP - CLOUD_BOTTOM); //half its thickness
    return abs(p.y - center) -halfH; //distance to nearest plane
}

vec2 slabRange(vec3 ro, vec3 rd){
    float lo = CLOUD_BOTTOM - FBM_MARGIN;
    float hi = CLOUD_TOP + FBM_MARGIN;

    //ray almost horizontal. if inside the layer, march from the camera / if not, never hits
    if(abs(rd.y) < 1e-4){
        if (ro.y > lo && ro.y < hi){
            return vec2(0.0, 1e9);
        }
        else{
            return vec2(1.0, 0.0);
        }
    }

    float t0 = (lo - ro.y) / rd.y; //ray-plane intersection with the bottom plane
    float t1 = (hi - ro.y) / rd.y; //and with the top plane
    float tEnter = max(min(t0, t1), 0.0); //nearer plane, never behind the camera
    float tExit = max(t0, t1); //farther plane
    return vec2(tEnter, tExit);
}

//also from maxime heckel
float fbm(vec3 p){
    vec3 q = p + u_Time * 0.05 * vec3(1.0, -0.2, -1.0);

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

//one cloud chunk
float sdfCloudShape(vec3 p){
    vec3 q = p - CLOUD_CENTER;
    float d = sdfSphere(q, 3.0);
    d = smoothmin(d, sdfSphere(q-vec3(-4.0,-1.0,0.5), 2.2), 1.5);//left lobe, a little lower
    d = smoothmin(d, sdfSphere(q-vec3(4.5,-1.2,-0.5), 2.5), 1.5);//left lobe, a little lower
    d = smoothmin(d, sdfSphere(q-vec3(1.5,2.2,0.0), 2.0), 1.5);//left lobe, a little lower
    return d;
}

vec3 rayDirection(vec2 uv){
    vec2 ndc = uv * 2.0 - 1.0;
    vec4 nearP = u_InvViewProj * vec4(ndc, -1.0, 1.0);
    vec4 farP  = u_InvViewProj * vec4(ndc,  1.0, 1.0);
    return normalize(farP.xyz / farP.w - nearP.xyz / nearP.w);
}

//Density at point p. negated SDF: positive inside the sphere, max at its center, max is also radius
float sceneDensity(vec3 p){
#if CLOUD_SLAB
    float distance = sdfSlab(p);
#endif
#if ACTUAL_CLOUD
    float distance = sdfCloudShape(p);
#endif

    float f = fbm(p * u_NoiseScale);
    return -distance + f; //negated SDF + fbm
}

//Beer-Lambert law, fraction of light that survives travelling 'dist' through the medium
float BeersLaw(float dist, float absorption){
    return exp(-dist * absorption);
}

float lightmarch(vec3 position){
    vec3 lightDirection = normalize(u_LightDir); //get direction from slider value
    float totalDensity = 0.0; //cloud density accumulated between position and the sun
    
    for(int step = 0; step < MAX_STEPS_LIGHTS; step++){
        position += lightDirection * LIGHT_MARCH_SIZE * float(step); //growing steps toward the sun
        float lightSample = sceneDensity(position);
        totalDensity += max(lightSample, 0.0); //ignore negative density outside the cloud, seethrough rather than black background
    }

    return BeersLaw(totalDensity, u_Absorption); //fraction of sunlight surviving to "position"
}

//How much light scatters toward the camera, given mu = cos(view ray - sun angle)
float HenyeyGreenstein(float g, float mu){
    float gg = g * g;
    return (1.0 / (4.0 * PI)) * ((1.0 - gg) / pow(1.0 + gg - 2.0 * g * mu, 1.5));
}

vec4 raymarch(vec3 rayOrigin, vec3 rayDirection, float offset){
#if CLOUD_SLAB
    vec2 range = slabRange(rayOrigin, rayDirection); // between the slab's planes
#endif
#if ACTUAL_CLOUD
    vec2 range = intersectBoundingSphere(rayOrigin, rayDirection); // inside the chunk's bounding sphere
#endif

    if(range.x > range.y){
        return vec4(0.0); //ray never touches the layer -> fully transparent
    }

    float t = range.x + MARCH_SIZE * offset;
    vec3 p = rayOrigin + t * rayDirection;

    float totalTransmittance = 1.0; // beer's law, how much background still shows through, multiplied by BeersLaw(density x MARCH_SIZE)
    vec3 lightEnergy = vec3(0.0); //light the cloud sends toward the camera so far

    vec3 sunDirection = normalize(u_LightDir);
    float phase = HenyeyGreenstein(u_Aniso, dot(rayDirection, sunDirection));

    for(int i = 0; i < MAX_STEPS; i++){
        if(t > range.y){ //t leaves range
            break;
        }
        float density = sceneDensity(p);

        //only draw density if it's greater than 0 (inside the sdf)
        if(density > 0.0){
            float lightTransmittance = lightmarch(p); //sunlight reaching this sample
            float transmittance = BeersLaw(density * MARCH_SIZE, u_Absorption); //view absorption
            vec3 luminance = (u_AmbientColor * u_AmbientStrength) + u_LightColor * u_CloudLight* density * lightTransmittance * phase; // ambient + sunlight x phase

            totalTransmittance *= transmittance; //oapcity along the view ray
            lightEnergy += totalTransmittance * luminance; //this step's light, dimmed by the cloud in front of it
        }

        t += MARCH_SIZE;
        p = rayOrigin + t * rayDirection;
    }

    return vec4(lightEnergy, 1.0-totalTransmittance);
}

void main(){

    vec3 rayOrig = u_CameraPos;
    vec3 rayDir = rayDirection(fs_UV);

    ivec2 size = textureSize(u_BlueNoise, 0); //64 x 64
    float blueNoise = texelFetch(u_BlueNoise, ivec2(gl_FragCoord.xy) % size, 0).r; //one texel per pixel
    float offset = fract(blueNoise);

    out_Col = raymarch(rayOrig, rayDir, offset);

    //debug
    //float a = fs_UV.y < 0.5 ? 0.5: 0.0;
    //out_Col = vec4(vec3(1.0)*a, a); //premultiply rgb * a
}