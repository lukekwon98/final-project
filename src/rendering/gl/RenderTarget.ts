import {gl} from '../../globals';

//pixelf ormat of one color texture
export interface ColorSpec{
    internalFormat: number; //how the GPU stores it
    format: number; //channel layout
    type: number; //component type
    filter: number; //LINEAR or NEAREST
}

//RGBA half float - HDR values
export const hdrColor = (): ColorSpec =>
  ({internalFormat: gl.RGBA16F,
    format: gl.RGBA, 
    type: gl.HALF_FLOAT, 
    filter: gl.LINEAR});

//Empty 2D texture with given filtering clamped at the edges
//Size andformat are allocated later in resize()
function makeTex(filter:number): WebGLTexture{
    const t = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, t);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, filter);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, filter);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    return t;
}

//framebuffer with color texture + optional epth texture - draw into it in one pass, then sample its textures in a later pass
export default class RenderTarget{
    fbo = gl.createFramebuffer(); //ties the textures together as one
    colors: WebGLTexture[]; //one texture per color output
    depth: WebGLTexture | null; //depth stored as a texture
    width = 0;
    height = 0;


    constructor(private specs: ColorSpec[], withDepth: boolean, public scale = 1.0){
        this.colors = specs.map(s => makeTex(s.filter));
        this.depth = withDepth ? makeTex(gl.NEAREST) : null;

    }

    //reallocates texture storage at the new size and attaches it to the framebuffer
    resize(fullW: number, fullH: number){
        const w = Math.max(1, Math.floor(fullW * this.scale));
        const h = Math.max(1, Math.floor(fullH * this.scale));
        if(w === this.width && h === this.height) return;
        this.width = w;
        this.height = h;

        gl.bindFramebuffer(gl.FRAMEBUFFER, this.fbo);

        //allocate each color texture and attach it as COLOR_ATTACHMENT0
        const bufs: number[] = [];
        this.specs.forEach((s,i) => {
            gl.bindTexture(gl.TEXTURE_2D, this.colors[i]);
            gl.texImage2D(gl.TEXTURE_2D, 0, s.internalFormat, w,h, 0, s.format, s.type, null);
            gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0 + i, gl.TEXTURE_2D, this.colors[i], 0);
            bufs.push(gl.COLOR_ATTACHMENT0 + i);
        });

        //Allocate and attach the 24 bit depth texture
        if(this.depth){
            gl.bindTexture(gl.TEXTURE_2D, this.depth);
            gl.texImage2D(gl.TEXTURE_2D, 0, gl.DEPTH_COMPONENT24, w,h, 0, gl.DEPTH_COMPONENT, gl.UNSIGNED_INT, null);
            gl.framebufferTexture2D( gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.TEXTURE_2D, this.depth, 0);
        }

        //route fragment shader aoutputs to the attachments(location 0 -> attachment 0, etc)
        gl.drawBuffers(bufs);

        //Fails if a format isn't renderable
        if(gl.checkFramebufferStatus(gl.FRAMEBUFFER) !== gl.FRAMEBUFFER_COMPLETE){
            throw new Error('RenderTarget incomplete');
        }
        gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    }

    //start drawing into target
    bind(){
        gl.bindFramebuffer(gl.FRAMEBUFFER, this.fbo);
        gl.viewport(0,0, this.width, this.height);
    }

    //draw to canvas again(framebufer null = the screen)
    static bindScreen(w:number, h:number){
        gl.bindFramebuffer(gl.FRAMEBUFFER, null);
        gl.viewport(0,0,w,h);
    }

    //ith color textur to sample in a later pass
    texture(i = 0){
        return this.colors[i];
    }
}


