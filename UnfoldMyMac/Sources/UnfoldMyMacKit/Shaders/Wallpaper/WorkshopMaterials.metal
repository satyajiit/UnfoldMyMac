float3 wsBase(float material,float3 p) {
    if(material<1.5) {
        float grain=sin(p.x*61.0+sin(p.z*3.0+p.y*5.0)*3.0);
        return float3(.73,.49,.285)*(.985+grain*.018);
    }
    if(material<2.5) return float3(.30,.40,.32);
    if(material<3.5) return float3(.89,.865,.75);
    if(material<4.5) return float3(.72,.51,.25);
    if(material<5.5) return float3(.67,.265,.15);
    if(material<6.5) return mix(float3(.67,.48,.29),float3(.76,.60,.41),fract(material)*3.0);
    if(material<7.5) return float3(.18,.20,.18);
    if(material<9.5) return float3(.91,.87,.72);
    if(material<11) {
        float2 grid=abs(fract(p.xy*18.0)-.5);
        float line=1-smoothstep(.015,.055,min(grid.x,grid.y));
        return mix(float3(.81,.85,.75),float3(.37,.52,.47),line*.36);
    }
    if(material<12) return float3(.83,.66,.43);
    return float3(1,.73,.34);
}

float3 wsShade(WorkshopHit hit,float3 rd,WorkshopState s) {
    float3 normal=hit.normal,p=hit.point;
    float3 base=pow(wsBase(hit.material,p),float3(2.2));
    float3 key=normalize(float3(-3.5,7,5)),fill=normalize(float3(5,3,-1));
    float diffuse=max(dot(normal,key),0.0),soft=max(dot(normal,fill),0.0);
    float sky=.5+.5*normal.y;
    float daylight=mix(.26,1.0,s.daylight);
    float3 color=base*(float3(.25,.28,.32)*(.6+sky*.5)*(.5+.5*s.daylight)+float3(1.08,.96,.80)*diffuse*.85*daylight
                      +float3(.79,.87,1)*soft*.19)*hit.ao;
    float3 halfway=normalize(key-rd);
    float gloss=hit.material>3.5 && hit.material<4.5?85.0:34.0;
    float specular=pow(max(dot(normal,halfway),0.0),gloss);
    float3 shine=hit.material>3.5 && hit.material<4.5?float3(.85,.62,.29):float3(1);
    color+=shine*specular*(hit.material>3.5 && hit.material<4.5?.40:.055)*hit.ao;
    // Warm pools from the three banks of task lamps, using the same count that lights their bulbs.
    const float3 benches[3]={float3(-1.67,.20,-.54),float3(-.12,.20,-.54),float3(1.48,.20,.60)};
    for(int i=0;i<3;i++) {
        float lamps=clamp((s.apps-float(i*4))/4.0,0.0,1.0);
        float3 delta=benches[i]+float3(0,1.16,-.20)-p;
        float distance=dot(delta,delta);
        float facing=max(dot(normal,normalize(delta)),0.0);
        color+=base*float3(1.0,.60,.25)*(facing*1.25+.075)*lamps/(1+distance*4.0)*(1.25-s.daylight*.55);
    }
    if(hit.material>=20) color+=float3(1.0,.58,.18)*(hit.material-20)*1.05;
    return pow(max(color,0.0),float3(1.0/2.2));
}

float3 wsFloor(float3 p,WorkshopState s) {
    float3 color=mix(float3(.78,.755,.70),float3(.935,.917,.865),s.daylight*.70+.30);
    float2 q=(p.xz-float2(.3,-.25))/float2(3.65,2.25);
    float contact=exp(-dot(q,q)*1.9);
    float2 shadow=(p.xz-float2(.65,-.90))/float2(3.8,2.45);
    float cast=exp(-dot(shadow,shadow)*1.55);
    color*=1-contact*.18-cast*.14;
    return color;
}

float3 wsPowerGlow(float3 ro,float3 rd,WorkshopState s,float nearest) {
    float age=s.charging;
    float pulse=age>=0?smoothstep(0.0,.18,age)*(1-smoothstep(3.3,4.6,age)):0;
    float3 glow=0;
    for(int i=0;i<16;i++) {
        float phase=float(i)/16;
        float3 p=float3(-2.75+phase*5.5,.24,1.64);
        float along=exp(-pow((phase-clamp(age/3.3,0.0,1.0))*9.0,2.0))*pulse;
        float t=dot(p-ro,rd),d=length(ro+rd*t-p);
        if(t<nearest+.035) glow+=float3(1,.48,.16)*exp(-d*d*420.0)*(.035*s.connected+.23*along);
    }
    return glow;
}
