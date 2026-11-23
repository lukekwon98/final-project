import {gl} from '../globals';

//Build 256x256 RGBA noise texture read by noise.glsl
//R - ranbdom value, G - R shifted by 37, 17: one lookup returns two neighbouring z slices
export function createNoiseTexture(): WebGLTexture{
    const N = 256;

    //Random red channel
    const red = new Uint8Array(N*N);
    for(let i = 0; i < N*N; i++){
        red[i] = Math.floor(Math.random()*256);
    }

    //Pack RGBA: G(x,y) = R(x-37,x-17) with wrap around
    const data = new Uint8Array(N*N*4);

    for(let y = 0; y < N; y++){
        for(let x = 0; x < N; x++){
            const i = y * N + x;
            const shifted = ((y - 239 +N) % N) * N + ((x-37 + N) % N);

            data[i*4+0] = red[i];
            data[i*4+1] = red[shifted];
            data[i*4+2] = 0; //unused
            data[i*4+3] = 255;
        }
    }

    const tex = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, N, N, 0, gl.RGBA, gl.UNSIGNED_BYTE, data);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR); //lienar, since GPU side bilinear filter does x y interpolation
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT); //slice offsets push uv far outside 0 - 1, so it must tile
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);

    return tex;
}

export function loadBlueNoise(url: string): WebGLTexture{
    const tex = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, tex);

    //Image load asynchronously -> 1x1 grey placeholder so the texture is valid
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.R8, 1, 1, 0, gl.RED, gl.UNSIGNED_BYTE, new Uint8Array([128]));

    //nearest - read exact texels, no blending. repeat = tile across the screen
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);

    //when the image arrives, replace the palceholder(only keeps the red channel)
    const img = new Image();
    img.onload = () =>{
        gl.bindTexture(gl.TEXTURE_2D, tex);
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.R8, gl.RED, gl.UNSIGNED_BYTE, img);
    };

    img.src = url; //Vite serves files in /public from the root
    return tex;
}