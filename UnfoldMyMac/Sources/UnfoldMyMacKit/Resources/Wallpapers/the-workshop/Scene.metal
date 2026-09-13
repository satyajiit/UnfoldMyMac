float3 workshopTrace(float3 ro,float3 rd,WorkshopState s) {
    float floorDistance=(-.21-ro.y)/rd.y;
    WorkshopHit hit={floorDistance,0,1,float3(0,1,0),ro+rd*floorDistance};
    wsTracePart(ro,rd,float3(0),float3(-3.1,-.2,-2.7),float3(3.1,3.8,1.85),1,s,0,0,hit);
    float fold=max(.015,smoothstep(.10,.83,s.open));
    if(s.open>.025) {
        const float3 benches[3]={float3(-1.67,.20,-.54),float3(-.12,.20,-.54),float3(1.48,.20,.60)};
        for(int i=0;i<3;i++) {
            wsTracePart(ro,rd,benches[i],float3(-.87,-.04,-.47),float3(.72,1.3,.63),fold,s,1,i,hit);
        }
        wsTracePart(ro,rd,float3(1.78,.20,-1.05),float3(-.88,-.02,-.27),float3(.88,1.53,.27),fold,s,2,0,hit);
        wsTracePart(ro,rd,float3(-.63,.20,.52),float3(-.43,-.02,-.56),float3(.58,1.4,.38),fold,s,3,0,hit);
        wsTracePart(ro,rd,float3(-1.94,.20,.94),float3(-.57,-.02,-.25),float3(.34,.48,.34),fold,s,4,0,hit);
    }
    float3 color=hit.material>.5?wsShade(hit,rd,s):wsFloor(hit.point,s);
    return color+wsPowerGlow(ro,rd,s,hit.t);
}

fragment float4 workshopFragment(WallpaperVertex in [[stage_in]],constant WallpaperUniforms &u [[buffer(0)]]) {
    bool still=u.environment.z>.5;
    float open=still?1.0:clamp(u.interaction.x,0.0,1.0);
    // Both signals represent open apps. Energy also supports the engine's generic scene previews.
    float apps=clamp(max(u.channels.x,u.energy),0.0,1.0)*12;
    WorkshopState state={still?18.0:u.time,open,apps,
        mix(6.0,clamp(u.channels.y,0.0,1.0)*24,clamp(u.channels.z,0.0,1.0)),
        clamp(u.environment.w,0.0,1.0),clamp(u.environment.y,0.0,1.0),still?-1.0:u.interaction.w};
    float aspect=u.size.x/u.size.y;
    float span=max(8.1,8.9/aspect);
    float2 uv=in.uv;
    if(u.motion.w>.5) uv.x=1-uv.x;
    float2 screen=float2((uv.x-.48)*aspect,.50-uv.y)*span;
    float2 look=still?float2(0):clamp(u.motion.xy,float2(-1.5),float2(1.5));
    float yaw=.37+look.x*.055;
    float3 camera=float3(sin(yaw)*12.0,6.4+look.y*.30,cos(yaw)*12.0);
    float3 direction=normalize(-camera),right=normalize(cross(direction,float3(0,1,0))),up=cross(right,direction);
    float3 origin=camera+float3(0,1.55,0)+screen.x*right+screen.y*up;
    float3 color=workshopTrace(origin,direction,state);
    // Four rotated samples only at geometry and highlight edges; broad backdrop stays single sampled.
    if(length(fwidth(color))>.028) {
        float pixel=span/u.size.y;
        float3 a=(right*.375+up*.125)*pixel,b=(-right*.125+up*.375)*pixel;
        color=(workshopTrace(origin-a,direction,state)+workshopTrace(origin+a,direction,state)
              +workshopTrace(origin-b,direction,state)+workshopTrace(origin+b,direction,state))*.25;
    }
    color+=(hash21(in.uv*u.size)-.5)*.45/255.0;
    return float4(clamp(color,0.0,1.0),1);
}
