// A floating miniature city: profile metrics change its skyline and packet traffic.
float ghBox(float3 p, float3 b, float rounding) {
    float3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x,max(q.y,q.z)),0.0) - rounding;
}
float2 ghMap(float3 p, float time, float energy) {
    p.y -= sin(time * .45) * .025;
    float2 result = float2(ghBox(p-float3(0,-.15,0),float3(1.36,.1,.99),.10), 1);
    float2 cell = floor(p.xz/.30+.5);
    // Neighbouring towers may be taller than the nearest cell. Include them so
    // marching and normals see a continuous distance field at cell boundaries.
    for (int x=-1; x<=1; x++) for (int z=-1; z<=1; z++) {
        float2 tower = cell + float2(x,z);
        if (abs(tower.x)>4 || abs(tower.y)>3) continue;
        float seed = hash21(tower+13);
        float height = .12 + seed*seed*(.6+energy*.6);
        float3 q = p-float3(tower.x*.30,height*.5,tower.y*.30);
        float building = ghBox(q,float3(.09,height*.5,.09),.018);
        if (building < result.x) result = float2(building,2+seed);
    }
    float mast = ghBox(p-float3(0,.66,0),float3(.16,.66,.16),.035);
    if (mast < result.x) result = float2(mast, 4);
    float3 orbit = p-float3(0,.66,0);
    orbit.xy = rotate2(orbit.xy,.23); orbit.yz = rotate2(orbit.yz,.22);
    float halo = torus(orbit,float2(1.74,.015));
    if (halo < result.x) result = float2(halo,5);
    return result;
}
fragment float4 githubCityFragment(WallpaperVertex in [[stage_in]], constant WallpaperUniforms &u [[buffer(0)]]) {
    float2 canvas=(in.uv-.5)*u.size/min(u.size.y,u.size.x/1.6);
    float2 p=(canvas-float2(.34,.015))*2.55;
    float3 ro=float3(3.65,3.0,4.5), target=float3(0,.3,0), forward=normalize(target-ro);
    float3 right=normalize(cross(forward,float3(0,1,0))), up=cross(right,forward);
    float3 rd=normalize(forward*2.7+right*p.x-up*p.y);
    float3 color=float3(.007,.019,.024)+float3(.014,.16,.07)*exp(-dot(p,p)*.65);
    float distance=0; float2 hit=0; bool found=false;
    for(int i=0;i<76;i++) {
        hit=ghMap(ro+rd*distance,u.time,u.energy);
        if(distance>12) break;
        if(hit.x < .0015) { found=true; break; }
        distance+=hit.x*.85;
    }
    if(found) {
        float3 q=ro+rd*distance; float e=.002;
        float3 n=normalize(float3(ghMap(q+float3(e,0,0),u.time,u.energy).x-ghMap(q-float3(e,0,0),u.time,u.energy).x,
            ghMap(q+float3(0,e,0),u.time,u.energy).x-ghMap(q-float3(0,e,0),u.time,u.energy).x,
            ghMap(q+float3(0,0,e),u.time,u.energy).x-ghMap(q-float3(0,0,e),u.time,u.energy).x));
        float3 base=hit.y<1.5?float3(.023,.063,.066):mix(float3(.04,.19,.16),float3(.35,.88,.43),fract(hit.y));
        color=studioLight(n,-rd,base,55);
        float window=.5+.5*sin(q.y*48+floor(q.x*20)*3+floor(q.z*20)*7);
        float occupancy=smoothstep(.62,.9,window)*(.4+u.energy*.6);
        if(hit.y>1.5 && hit.y<3.1) color+=float3(.15,1,.46)*occupancy*(1-abs(n.y))*.8;
        if(hit.y>3.5 && hit.y<4.5) {
            float scan=exp(-pow((fract(q.y*.8-u.time*.20)-.5)*14,2.0));
            color+=float3(.5,1,.65)*scan*1.8;
        }
        if(hit.y>4.5) color=float3(.26,1,.55)*2.2;
        float ao=clamp(ghMap(q+n*.12,u.time,u.energy).x/.12,.2,1.0);
        color*=.65+.35*ao;
    }
    // Perspective particles stream around the city instead of following a flat overlay.
    for(int i=0;i<24;i++) {
        float fi=float(i), angle=fi*2.399+u.time*(.15+u.energy*.3);
        float3 pos=float3(cos(angle)*1.75,.65+sin(angle*2+fi)*.38,sin(angle)*1.28);
        float along=dot(pos-ro,rd), d=length(ro+rd*along-pos);
        if(along<distance) color+=mix(float3(.2,1,.47),float3(1,.78,.3),step(.82,fract(fi*.618))) * exp(-d*d*1300)*1.5;
    }
    color+=float3(.01,.08,.03)*exp(-abs(p.y-.65)*8)*exp(-p.x*p.x*.3);
    color*=mix(.46,1.0,smoothstep(-.29,.02,canvas.x));
    return float4(1-exp(-color*1.3),1);
}
