uniform mat4 u_InvViewProj;

vec3 rayDirection(vec2 uv){
    vec2 ndc = uv * 2.0 - 1.0;

    //near plane = -1.0 , far plane = 1.0
    vec4 nearP = u_InvViewProj * vec4(ndc, -1.0, 1.0);
    vec4 farP = u_InvViewProj * vec4(ndc, 1.0, 1.0);

    //undo perspective divide
    return normalize(farP.xyz/farP.w - nearP.xyz / nearP.w);
}