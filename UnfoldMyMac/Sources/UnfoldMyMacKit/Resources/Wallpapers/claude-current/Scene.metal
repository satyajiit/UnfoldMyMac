float claudeShape(float3 p,float time,float energy) {
    p.xz=rotate2(p.xz,.5+time*.12);
    p.xy=rotate2(p.xy,-.18+sin(time*.2)*.08);
    float3 q=abs(p)-float3(.57,.69,.57);
    float box=length(max(q,0.0))+min(max(q.x,max(q.y,q.z)),0.0)-.16;
    // Rounded ceramic block with a recessed equatorial groove.
    float groove=torus(p,float2(.75,.055+.018*energy));
    return max(box,-groove);
}
fragment float4 claudeFragment(WallpaperVertex in [[stage_in]],constant WallpaperUniforms &u [[buffer(0)]]) {
    float2 uv=in.uv,p=(uv-.5)*u.size/min(u.size.y,u.size.x/1.6)*4;
    p.x-=.92; p.y+=sin(u.time*.5)*.045;
    float3 ro=float3(p.x,-p.y,4.8),rd=float3(0,0,-1);float t=0;
    for(int i=0;i<56;i++){float d=claudeShape(ro+rd*t,u.time,u.energy);if(d<.002||t>7)break;t+=d;}
    float3 color=atmosphere(uv,u);
    if(t<7){
        float3 h=ro+rd*t;float2 e=float2(.002,0);
        float3 n=normalize(float3(claudeShape(h+e.xyy,u.time,u.energy)-claudeShape(h-e.xyy,u.time,u.energy),claudeShape(h+e.yxy,u.time,u.energy)-claudeShape(h-e.yxy,u.time,u.energy),claudeShape(h+e.yyx,u.time,u.energy)-claudeShape(h-e.yyx,u.time,u.energy)));
        color=studioLight(n,-rd,u.accent.rgb,22);
        color*=.96+.04*sin(h.y*100);
    }
    for(int i=0;i<9;i++){
        float a=float(i)*.698+u.time*(.12+u.energy*.4);
        float2 point=rotate2(float2(cos(a)*1.38,sin(a)*.6),.25);
        float2 d=abs(p-point)-.033;
        float shape=length(max(d,0.0))+min(max(d.x,d.y),0.0);
        color=mix(color,mix(u.accent.rgb,float3(1,.93,.76),.5),1-smoothstep(0.,.008,shape));
        color+=u.accent.rgb*exp(-dot(p-point,p-point)*180)*.15;
    }
    return float4(color,1);
}
