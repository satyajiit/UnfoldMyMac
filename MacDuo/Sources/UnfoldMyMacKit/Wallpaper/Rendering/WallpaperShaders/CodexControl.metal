// A polished desktop robot whose expression and machine state follow lifecycle events.
float controlBox(float3 p,float3 b,float r) {
    float3 q=abs(p)-b; return length(max(q,0.0))+min(max(q.x,max(q.y,q.z)),0.0)-r;
}
float2 controlMap(float3 p,float time,float energy) {
    p.y-=sin(time*.8)*.07;
    float3 head=p-float3(0,.57,0);
    head.xz=rotate2(head.xz,sin(time*.5)*(.06+energy*.08));
    float2 result=float2(controlBox(head,float3(.56,.36,.32),.20),1);
    float face=controlBox(head-float3(0,0,.53),float3(.46,.245,.015),.10);
    if(face<result.x) result=float2(face,2);
    float body=controlBox(p-float3(0,-.18,-.02),float3(.36,.27,.25),.16);
    if(body<result.x) result=float2(body,3);
    float3 arm=p-float3(sign(p.x)*.7,-.16+sin(time*2.4+p.x*2)*energy*.12,.04);
    arm.xy=rotate2(arm.xy,sign(p.x)*.2+sin(time*2)*energy*.12);
    float limb=controlBox(arm,float3(.10,.23,.105),.085);
    if(limb<result.x) result=float2(limb,1);
    float feet=controlBox(float3(abs(p.x)-.25,p.y+.68,p.z-.11),float3(.12,.05,.25),.065);
    if(feet<result.x) result=float2(feet,3);
    float antenna=min(length(p-float3(0,1.25,0))-.075,
        controlBox(p-float3(0,1.12,0),float3(.018,.10,.018),.015));
    if(antenna<result.x) result=float2(antenna,4);
    float pedestal=controlBox(p-float3(0,-.92,0),float3(.98,.06,.64),.13);
    if(pedestal<result.x) result=float2(pedestal,5);
    return result;
}
fragment float4 codexControlFragment(WallpaperVertex in [[stage_in]],constant WallpaperUniforms &u [[buffer(0)]]) {
    float2 canvas=(in.uv-.5)*u.size/min(u.size.y,u.size.x/1.6);
    float2 p=(canvas-float2(.35,.02))*2.8;
    float3 ro=float3(2.55,1.35,5.0), target=float3(0,.1,0), fw=normalize(target-ro);
    float3 right=normalize(cross(fw,float3(0,1,0))), up=cross(right,fw), rd=normalize(fw*2.5+right*p.x-up*p.y);
    float state=u.channels.x;
    float waiting=smoothstep(.37,.44,state)*(1-smoothstep(.60,.69,state));
    float done=smoothstep(.66,.73,state)*(1-smoothstep(.88,.95,state));
    float3 signal=mix(float3(.28,.65,1),float3(1,.52,.10),waiting);
    signal=mix(signal,float3(.35,1,.65),done);
    signal=mix(signal,float3(.8,.35,.55),smoothstep(.92,.99,state));
    float3 color=float3(.009,.011,.04)+float3(.025,.08,.27)*exp(-dot(p,p)*.6);
    float distance=0; float2 hit=0; bool found=false;
    for(int i=0;i<72;i++) {
        hit=controlMap(ro+rd*distance,u.time,u.energy);
        if(distance>10) break;
        if(hit.x<.0015) { found=true; break; }
        distance+=hit.x*.88;
    }
    if(found) {
        float3 q=ro+rd*distance; float e=.002;
        float3 n=normalize(float3(controlMap(q+float3(e,0,0),u.time,u.energy).x-controlMap(q-float3(e,0,0),u.time,u.energy).x,
            controlMap(q+float3(0,e,0),u.time,u.energy).x-controlMap(q-float3(0,e,0),u.time,u.energy).x,
            controlMap(q+float3(0,0,e),u.time,u.energy).x-controlMap(q-float3(0,0,e),u.time,u.energy).x));
        float3 base=float3(.065,.21,.72);
        if(hit.y==3) base=float3(.25,.30,.42);
        if(hit.y==5) base=float3(.04,.07,.15);
        color=studioLight(n,-rd,base,70);
        if(hit.y==2) {
            float3 face=q-float3(0,.57+sin(u.time*.8)*.07,0);
            face.xz=rotate2(face.xz,sin(u.time*.5)*(.06+u.energy*.08));
            float blink=1-smoothstep(.95,.99,sin(u.time*.7));
            float2 eye=float2(abs(face.x)-.20,face.y-.015);
            float eyeShape=length(eye/float2(.065,.08*blink+.012));
            float glow=exp(-eyeShape*eyeShape*2.2);
            float mouth=exp(-pow((face.y+.12+done*.07*cos(face.x*8))*100,2.0))*exp(-pow(face.x*6,6.0));
            color=float3(.003,.011,.027)+signal*(glow*2.5+mouth*.9);
        }
        if(hit.y==4) color=signal*(1.5+.5*sin(u.time*(2+u.energy*6)));
        if(hit.y==3) color+=signal*exp(-pow((q.y+.25)*30,2.0))*.5;
        if(hit.y==5) color+=signal*exp(-abs(q.y+.84)*80)*.6;
    }
    // Orbiting glass-like status cards; their motion speeds up while the agent works.
    for(int i=0;i<5;i++) {
        float a=float(i)*1.256+u.time*(.12+u.energy*.22);
        float3 point=float3(cos(a)*1.36,.20+sin(a*2)*.55,sin(a)*.72);
        float along=dot(point-ro,rd); float3 d=ro+rd*along-point;
        float frame=max(abs(dot(d,right))/.16,abs(dot(d,up))/.105);
        if(along<distance) color+=signal*(exp(-pow((frame-1)*30,2.0))*.7+exp(-dot(d,d)*180)*.08);
    }
    color*=mix(.45,1.0,smoothstep(-.3,.03,canvas.x));
    return float4(1-exp(-color*1.4),1);
}
