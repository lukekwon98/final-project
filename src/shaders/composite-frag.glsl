#version 300 es
precision highp float; //32 bit float

in vec2 fs_UV; //screen coordinate in 0,1
out vec4 out_Col;

uniform sampler2D u_Scene; //HDR result of pass 1
uniform sampler2D u_BlueNoise; //blue noise
uniform float u_Exposure; //brightness multiplier before tone map
uniform int u_Tonemap; //0 none, 2 ACES, 3 Reinhard
uniform int u_DebugView; //0 final 2 noise texture
uniform float u_Time;
uniform vec2 u_Resolution;

uniform mat4 u_InvViewProj;
uniform sampler2D u_Noise;
uniform sampler2D u_Clouds; //premultiplied clouds, rgba
uniform sampler2D u_CloudShadow; //R = sunlight transmittance through the cloud, G = entry depth

//god rays
uniform vec3 u_CameraPos;
uniform vec3 u_LightDir;
uniform vec3 u_LightColor;
uniform mat4 u_LightViewProj; //world to light camera clip space
const float SHADOW_BIAS = 0.005; //to prevent self shadow artifacts

#define GOD_RAY_STEPS 50
const float GOD_MAX_DIST = 40.0;
const float GOD_RAY_STEP = GOD_MAX_DIST / float(GOD_RAY_STEPS);
const float FOG_DENSITY = 0.03;
const float GOD_ANISO = 0.3; //HG g for the air, >0 means forward scattering, maxime
const float GOD_INTENSITY = 12.6; //maxime's light intesnity
#define FOG_OCTAVES 3
const float FOG_NOISE_AMP = 0.01;
const float FOG_NOISE_MULT = 10.0;
const float SHADOW_CONTRAST = 10.0;

const vec3 CLOUD_CENTER = vec3(0.0, 1.5, -20.0);
const float SHAFT_RADIUS = 12.0; //tube radius: wider than cloud
const float SHAFT_SOFT = 8.0; //soft fade at the tube wall (no visible tube)
const float SHAFT_LENGTH = 50.0; //how far the shaft reaches from the cloud

#define PI 3.14159265359

//maxime heckel - 3D value noise using one lookup into a '2D' texture
//each integer z is a 2D slice placed at offset (37, 17) *z in the texture
//due to the shift, G holds slice z and R holds slice z+1 at the same spot - one lookup gives both slices and we blend them
float noise(vec3 x){
    vec3 p = floor(x); //integer grid idx
    vec3 f = fract(x); //position inside grid cell
    f = f * f * (3.0 -2.0 *f);

    vec2 uv = (p.xy + vec2(37.0, 239.0) * p.z) + f.xy; //slice offset + position, adds variation to noise (image 3D noise as a stack of 2D images, each image is a slice: noise z = 4.3, we need slice 4 and slice 5)
    vec2 rg = textureLod(u_Noise, (uv+0.5) / 256.0, 0.0).yx; //hardware bilinear handles
    return mix(rg.x, rg.y, f.z) * 2.0 - 1.0; //mix two noise values from the texture lookup based on the z value to generate a smooth pattern

}

vec3 rayDirection(vec2 uv){
    vec2 ndc = uv * 2.0 - 1.0;

    //near plane = -1.0 , far plane = 1.0
    vec4 nearP = u_InvViewProj * vec4(ndc, -1.0, 1.0);
    vec4 farP = u_InvViewProj * vec4(ndc, 1.0, 1.0);

    //undo perspective divide
    return normalize(farP.xyz/farP.w - nearP.xyz / nearP.w);
}

//tone mapping - trying out multiple
vec3 reinhard(vec3 x){
    return x / (1.0 + x);
}
//UE4, s shaped curve: near black gets darker, middle is brightened a little, 1 is mapped to ~0.8, bright values get squeezed(bigger than 1), biggest value reaches 1.0
//sun that fades smoothly into pure white - high-constrast clouds filmic curve
vec3 acesFilm(vec3 x) {
    return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

//calculateShadow by maxime - how much sunlight reaches world point p: 1 = fully lit
float cloudShadow(vec3 p){
    vec4 lightClip = u_LightViewProj * vec4(p, 1.0); //into the light camera's box
    vec3 ndc = lightClip.xyz / lightClip.w; //ortho: w = 1 anyways
    vec2 uv = ndc.xy * 0.5 + 0.5; //ndc to shadow map texture coords

    //outside the box sideways (no cloud along that sun ray) -> fully lit
    if(any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))){
        return 1.0;
    }

    float depth = ndc.z * 0.5 + 0.5; //0: sun side of the box , 1: far side, >1: past the box but still behind the cloud
    vec2 sm = texture(u_CloudShadow, uv).rg; //r: sunlight through cloud, g: where the cloud starts
    
    if(depth > sm.g + SHADOW_BIAS){
        return sm.r;
    }
    else{
        return 1.0;
    }
}

//maxime's HGPhase (Henyey Greenstein without 1/4pi)
float HGPhase(float mu){
    float g = GOD_ANISO;
    float gg = g * g;
    float denom = max(1.0 + gg - 2.0 * g * mu, 0.0001); //avoid divison by zero when mu, g = 1

    return  (1.0 / (4.0 * PI)) * (1.0 - gg) / pow(denom, 1.5);
}

//fog volume, a tube around the sun ray
//maxime
float shaftVolume(vec3 p){
    vec3 L = normalize(u_LightDir);
    vec3 d = p-CLOUD_CENTER;
    
    float along = dot(d,L); // >0 sun side of the cloud, <0 shadow side
    float radial = length(d-along * L); //distance from the cube's axis

    float side = 1.0 - smoothstep(SHAFT_RADIUS - SHAFT_SOFT, SHAFT_RADIUS, radial); //1 inside, fades at the wall
    float behind = 1.0 - smoothstep(-2.0, 2.0, along); //shadow side only (sun side would paint over the cloud)
    float reach = 1.0 - smoothstep(SHAFT_LENGTH * 0.5, SHAFT_LENGTH, -along); //fade out far from the cloud

    return side * behind * reach;
}

vec3 godRays(vec3 rayOrigin, vec3 rayDir, float offset){
    vec3 accumulatedLight = vec3(0.0);
    float transmittance = 1.0; // how much of the light from this depth still reaches the camera - maxime's is 5.0
    float phase = HGPhase(dot(rayDir, normalize(u_LightDir))); //directional sun


    float t = GOD_RAY_STEP * offset;
    for(int i = 0; i < GOD_RAY_STEPS; i++){
        if(t > GOD_MAX_DIST){
            break;
        }

        vec3 samplePos = rayOrigin + rayDir * t;
        float shapeFactor = shaftVolume(samplePos); // Maxime: -sdfVal + tube mask
        float stepDensity = max(FOG_DENSITY * shapeFactor, 0.0); //fog amount, never negative

        float shadow = pow(cloudShadow(samplePos), SHADOW_CONTRAST); //how much sunlight left after the cloud
        vec3 luminance = u_LightColor * GOD_INTENSITY* shadow* phase; //maxime

        transmittance *= exp(-stepDensity * GOD_RAY_STEP);
        accumulatedLight += luminance * transmittance * stepDensity * GOD_RAY_STEP; //light scattered and dimmed by frog in front

        t += GOD_RAY_STEP;
    }

    return accumulatedLight;
}
//final pass: hdr scene -> tone mapped -> screen, also shows debug views
void main(){
    vec2 aspectUV = fs_UV * vec2(u_Resolution.x/u_Resolution.y, 1.0); //square texels

    //raw noise texture on the red channel
    if(u_DebugView == 2){
        out_Col = vec4(vec3(texture(u_Noise, aspectUV).r), 1.0);
        return;
    }
    //noise(vec3), moving through z over time - smooth blobs that morph
    if(u_DebugView == 3){
        out_Col = vec4(vec3(noise(vec3(aspectUV*8.0, u_Time * 0.01))), 1.0);
        return;
    }
    //blue noise, 1 texel per screen pixel
    if(u_DebugView ==4){
        ivec2 sz = textureSize(u_BlueNoise, 0);
        out_Col = vec4(vec3(texelFetch(u_BlueNoise, ivec2(gl_FragCoord. xy) % sz, 0).r), 1.0);
        return;
    }

    //debug
    // out_Col = vec4(texture(u_CloudShadow, fs_UV).rrr,1.0);
    // return;

    vec3 scene = texture(u_Scene, fs_UV).rgb;
    vec4 cloud = texture(u_Clouds, fs_UV);

    ivec2 bnSize = textureSize(u_BlueNoise, 0); //64 x 64
    float blueNoise = texelFetch(u_BlueNoise, ivec2(gl_FragCoord.xy) % bnSize, 0).r; //one texel per pixel like the cloud
    float offset = fract(blueNoise + float(int(u_Time) % 32) / sqrt(0.5)); //maxime - shift the pattern each frame
    vec3 godRay = godRays(u_CameraPos, rayDirection(fs_UV), offset);

    //out_Col = vec4(godRay * 3.0, 1.0); return; // P3 DEBUG: god rays only
    vec3 hdr = (scene * (1.0 - cloud.a) + cloud.rgb + godRay) * u_Exposure;

    vec3 col;
    if(u_Tonemap == 2){
        col = acesFilm(hdr);
    }
    else if(u_Tonemap == 3){
        col = reinhard(hdr);
    }
    else col = hdr;

    out_Col = vec4(col, 1.0);
}