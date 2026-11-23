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

    vec3 hdr = texture(u_Scene, fs_UV).rgb * u_Exposure;
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