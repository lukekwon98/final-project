#version 300 es

in vec4 vs_Pos;
out vec2 fs_UV;

void main(){
    fs_UV = vs_Pos.xy * 0.5 + 0.5; //-1 1 -> 0 1 for texture lookups
    gl_Position = vec4(vs_Pos.xy, 0.0, 1.0);
}