uniform sampler2D u_Noise;

//maxime heckel - 3D value noise using one lookup into a '2D' texture
//each integer z is a 2D slice placed at offset (37, 17) *z in the texture
//due to the shift, G holds slice z and R holds slice z+1 at the same spot - one lookup gives both slices and we blend them
float noise(vec3 x){
    vec3 p = floor(x); //integer grid idx
    vec3 f = fract(x); //position inside grid cell
    f = f * f * (3.0 -2.0 *f);

    vec2 uv = (p.xy + vec2(37.0 + 239.0) * p.z) + f.xy; //slice offset + position, adds variation to noise (image 3D noise as a stack of 2D images, each image is a slice: noise z = 4.3, we need slice 4 and slice 5)
    vec2 rg = textureLod(u_Noise, (uv+0.5) / 256.0, 0.0).yx; //hardware bilinear handles
    return mix(rg.x, rg.y, f.z) * 2.0 - 1.0; //mix two noise values from the texture lookup based on the z value to generate a smooth pattern

}