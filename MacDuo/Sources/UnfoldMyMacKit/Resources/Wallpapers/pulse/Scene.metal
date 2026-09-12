float pulseShape(float3 p,float time,float energy) {
    p.xz=rotate2(p.xz,time*.13);
    p.xy=rotate2(p.xy,.38+sin(time*.17)*.12);
    float wave=sin(p.y*13+time)*sin(p.x*12-time*.7)*.012*(.3+energy);
    float sphere=length(p)-.65-wave;
    float3 q=p; q.yz=rotate2(q.yz,.56);
    float ring=torus(q,float2(1.02,.115));
    return min(sphere,ring);
}
fragment float4 pulseFragment(WallpaperVertex in [[stage_in]],constant WallpaperUniforms &u [[buffer(0)]]) {
    float2 uv=in.uv, p=(uv-.5)*u.size/min(u.size.y,u.size.x/1.6)*4;
    p.x-=.88;
    float3 ro=float3(p.x,-p.y,4.8),rd=float3(0,0,-1);
    float t=0;
    for(int i=0;i<60;i++){float d=pulseShape(ro+rd*t,u.time,u.energy);if(d<.002||t>7)break;t+=d;}
    float3 color=atmosphere(uv,u);
    float shadow=exp(-pow(length(float2(p.x,(p.y-1.13)*3)),2)*1.5);
    color*=1-shadow*.45;
    if(t<7){
        float3 hit=ro+rd*t; float2 e=float2(.002,0);
        float3 n=normalize(float3(pulseShape(hit+e.xyy,u.time,u.energy)-pulseShape(hit-e.xyy,u.time,u.energy),pulseShape(hit+e.yxy,u.time,u.energy)-pulseShape(hit-e.yxy,u.time,u.energy),pulseShape(hit+e.yyx,u.time,u.energy)-pulseShape(hit-e.yyx,u.time,u.energy)));
        float3 base=mix(float3(.28,.43,.48),u.accent.rgb,.55+.25*sin(hit.y*5+u.time*.25));
        base=mix(base,float3(.56,.70,.91),u.channels.x*.22);
        color=studioLight(n,-rd,base,42);
        float bands=pow(.5+.5*sin(hit.y*28+u.time*(.5+u.energy)),22.0);
        color+=u.accent.rgb*bands*.13;
    }
    // Sparse orbital points travel at a speed driven by real CPU load.
    for(int i=0;i<12;i++){
        float a=float(i)*.5236+u.time*(.06+u.energy*.13);
        float2 point=float2(cos(a)*1.32,sin(a)*.43);
        point=rotate2(point,-.32);
        float d=length(p-point);
        color+=u.accent.rgb*exp(-d*d*550)*(.3+.7*smoothstep(-1.,1.,sin(a)));
    }
    return float4(color,1);
}
