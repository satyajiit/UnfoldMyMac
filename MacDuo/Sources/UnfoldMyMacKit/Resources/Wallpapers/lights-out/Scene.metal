// Composition and bounded ray traversal. Car geometry/materials live in separate modules.
fragment float4 lightsOutFragment(WallpaperVertex in [[stage_in]],constant WallpaperUniforms &u [[buffer(0)]]) {
    float2 canvas=(in.uv-.5)*u.size/min(u.size.y,u.size.x/1.6);
    float2 p=rotate2((canvas-float2(.35,.035))*2.95,-.025);
    float orbit=sin(u.time*.16)*(.06+.08*u.energy);
    float3 ro=float3(4.0+orbit,2.48,5.25-orbit), target=float3(0,.30,.1), fw=normalize(target-ro);
    float3 right=normalize(cross(fw,float3(0,1,0))), up=cross(right,fw);
    float3 rd=normalize(fw*2.65+right*p.x-up*p.y);
    float3 backdrop=float3(.015,.009,.019)+float3(.095,.012,.025)*exp(-dot(p,p)*.5);
    float groundT=(-.013-ro.y)/rd.y;
    float3 color=groundT>0?raceTrack(ro+rd*groundT,groundT,u.time,backdrop):backdrop;
    // Intersect the complete chassis bounds before evaluating detailed geometry.
    float3 boundsMin=float3(-1.09,-.035,-2.40), boundsMax=float3(1.09,1.17,2.43);
    float3 ta=(boundsMin-ro)/rd, tb=(boundsMax-ro)/rd;
    float3 nearAxis=min(ta,tb), farAxis=max(ta,tb);
    float nearT=max(max(nearAxis.x,nearAxis.y),nearAxis.z);
    float farT=min(min(farAxis.x,farAxis.y),farAxis.z);
    float distance=max(0.0,nearT); float2 hit=0; bool found=false;
    if(nearT<farT && farT>0) {
        for(int i=0;i<130;i++) {
            hit=raceMap(ro+rd*distance,u.time);
            if(distance>farT || (groundT>0 && distance>groundT)) break;
            if(hit.x<.00085) { found=true; break; }
            distance+=max(hit.x*.76,.0004);
        }
    }
    if(found) {
        float3 q=ro+rd*distance; float e=.0012;
        float3 n=normalize(float3(raceMap(q+float3(e,0,0),u.time).x-raceMap(q-float3(e,0,0),u.time).x,
            raceMap(q+float3(0,e,0),u.time).x-raceMap(q-float3(0,e,0),u.time).x,
            raceMap(q+float3(0,0,e),u.time).x-raceMap(q-float3(0,0,e),u.time).x));
        color=raceMaterial(q,n,-rd,hit.y,u.time);
        float ao=clamp(raceMap(q+n*.065,u.time).x/.065,.15,1.0);
        color*=.53+.47*ao;
    }
    // Small grid lights sit above the chassis, separate from the car silhouette.
    float phase=fmod(u.time,18.0);
    float2 lights=(canvas-float2(.37,-.30))*float2(1,1.0);
    float panel=raceBox(float3(lights.x,lights.y,0),float3(.13,.031,.005),.009);
    color=mix(color,float3(.020,.023,.029),1-smoothstep(0.0,.0015,panel));
    for(int i=0;i<5;i++) {
        float d=length(lights-float2((float(i)-2)*.046,0));
        float on=step(float(i)+1,phase)*(1-step(6.0,phase));
        float lamp=1-smoothstep(.010,.012,d);
        color+=float3(1.8,.004,.017)*lamp*(.06+on)+float3(.32,.003,.01)*exp(-d*d*3500)*on;
    }
    color=mix(float3(.015,.009,.019),color,smoothstep(-.34,.06,canvas.x));
    return float4(1-exp(-color*1.35),1);
}
