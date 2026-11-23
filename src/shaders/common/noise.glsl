uniform sampler2D u_Noise;

//maxime heckel
float noise(vec3 x){
    vec3 p = floor(x); //integer grid idx
    vec3 f = fract(x); //position inside grid cell
    f = f * f * (3.0 -2.0 *f);

    vec2 uv = (p.xy + vec2(37.0 + 17.0) * p.z) + f.xy; //slice offset + position, adds variation to noise
    vec2 rg = textureLod(u_Noise, (uv+0.5) / 256.0, 0.0).yx; //hardware bilinear handles
    return mix(rg.x, rg.y, f.z); //mix two noise values from the texture lookup based on the z value to generate a smooth pattern

}