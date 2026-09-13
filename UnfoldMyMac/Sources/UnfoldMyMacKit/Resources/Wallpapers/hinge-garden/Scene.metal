// Hinge Garden — an original miniature, evaluated in world space at native drawable resolution.
constant float3 gardenIslands[4]={float3(.05,-.10,.25),float3(-2.5,-.14,-.65),float3(2.65,-.13,-.65),float3(-1.2,-.16,1.7)};
constant float3 gardenRadii[4]={float3(1.72,.39,.87),float3(1.20,.40,.85),float3(1.14,.42,.80),float3(.64,.24,.45)};
constant float3 gardenPlants[7]={float3(-2.93,.18,-.70),float3(-1.89,.16,-1.02),float3(-3.10,.15,.02),
    float3(2.09,.20,-.85),float3(3.22,.13,-.90),float3(2.83,.20,.02),float3(-1.27,.05,1.7)};
constant float gardenPlantScales[7]={1.0,.86,.55,.86,1.0,.62,.42};

void gardenMoss(float3 ro,float3 rd,GardenState s,thread float3 &color,thread float &nearest) {
    for(int i=0;i<4;i++) {
        float3 c=gardenIslands[i],r=gardenRadii[i];
        float2 b=gardenBound(ro,rd,c,r);
        // Analytic ellipsoid intersection avoids marching the broad moss masses.
        if(b.x>0.0 && b.x<nearest && b.y>b.x) {
            float3 p=ro+rd*b.x,n=normalize((p-c)/(r*r));
            GardenHit hit={b.x,1,n,p};
            color=gardenMaterial(hit,rd,s); nearest=b.x;
        }
    }
}
void gardenGlassSnail(float3 ro,float3 rd,GardenState s,thread float3 &color,thread float &nearest) {
    float3 origin=gardenSnailOrigin(s);
    float2 bounds=gardenBoxBound(ro-origin,rd,float3(-1.0,.18,-.60),float3(1.45,2.12,.60));
    bounds.y=min(bounds.y,nearest);
    if(bounds.y>bounds.x) {
        GardenHit h=gardenMarch(ro-origin,rd,bounds,s,0,0);
        if(h.t<nearest) {
            float3 glass=gardenMaterial(h,rd,s);
            if(h.material==4.0) {
                GardenHit inside=gardenMarch(ro-origin,rd,float2(h.t+.006,bounds.y),s,0,0,false);
                float3 interior=inside.t<nearest?gardenMaterial(inside,rd,s):color;
                float fresnel=pow(1.0-abs(dot(h.normal,rd)),3.0);
                glass=mix(interior*float3(.88,.95,.89)+float3(.048,.023,.004),glass,.12+fresnel*.62);
            }
            if(h.material==2.0 || h.material==3.0) {
                float edge=pow(1.0-abs(dot(h.normal,rd)),2.0);
                glass=mix(color*float3(.63,.86,.81),glass,.72+edge*.28);
            }
            color=glass; nearest=h.t;
        }
    }
}
void gardenFlowers(float3 ro,float3 rd,GardenState s,thread float3 &color,thread float &nearest) {
    for(int i=0;i<7;i++) {
        float3 base=gardenPlants[i]; float seed=float(i)*.7;
        float scale=gardenPlantScales[i];
        float3 o=(ro-base)/scale;
        float2 b=gardenBound(o,rd,float3(0,.70,0),float3(.76,1.18,.65));
        b.y=min(b.y,nearest/scale);
        if(b.y>b.x) {
            GardenHit h=gardenMarch(o,rd,b,s,1,seed);
            if(h.t*scale<nearest) { color=gardenMaterial(h,rd,s);nearest=h.t*scale; }
        }
    }
}
void gardenObjects(float3 ro,float3 rd,GardenState s,thread float3 &color,thread float &nearest) {
    gardenMoss(ro,rd,s,color,nearest);
    gardenGlassSnail(ro,rd,s,color,nearest);
    gardenFlowers(ro,rd,s,color,nearest);
}
float3 gardenPollen(float3 ro,float3 rd,GardenState s,float nearest) {
    float3 color=0;
    // Sparse pollen lives in the same camera space, with depth rejection against the miniature.
    for(int j=0;j<16;j++) {
        if(j>10 && s.pollen<0.0)continue;
        float fj=float(j),seed=hash21(float2(fj,8));
        float3 p=float3((seed-.5)*6.7,.5+hash21(float2(fj,4))*1.65,sin(fj*4.7)*1.0);
        p+=float3(.28*sin(s.time*.38+fj),.16*sin(s.time*.51+fj*1.7),.14*cos(s.time*.31+fj));
        if(j>10 && s.pollen>=0.0) p=float3(-2.4,.9,-.5)+float3(sin(fj*4.0),.6,cos(fj*2.0))*(.1+s.pollen*.3);
        float t=dot(p-ro,rd),d=length(ro+rd*t-p);
        float glow=exp(-d*d*1300.0)*.20+exp(-d*d*12000.0)*.34;
        float life=j>10?smoothstep(0.0,.12,s.pollen)*(1.0-smoothstep(1.8,3.0,s.pollen)):1.0;
        if(t<nearest)color+=float3(.72,.75,.49)*glow*(.35+.4*s.battery)*life;
    }
    return color;
}
float3 gardenSoftLight(float3 ro,float3 rd,GardenState s,float nearest) {
    float charge=gardenCharge(s);
    float3 center=gardenSnailOrigin(s)+float3(-.12,1.72,.10);
    float t=dot(center-ro,rd),d=length(ro+rd*t-center);
    float visible=1.0-smoothstep(.08,.65,t-nearest);
    float glow=exp(-d*d*7.0)*(.018+.12*charge)+exp(-d*d*45.0)*(.025+.09*charge);
    float3 color=float3(1.0,.68,.32)*glow*visible;
    for(int i=0;i<7;i++) {
        float seed=float(i)*.7,scale=gardenPlantScales[i];
        float height=.82+seed*.065;
        center=gardenPlants[i]+float3(gardenPlantSway(height,s,seed),height+.04,0)*scale;
        t=dot(center-ro,rd); d=length(ro+rd*t-center)/scale;
        visible=1.0-smoothstep(.02,.25*scale,t-nearest);
        color+=float3(.92,.69,.37)*exp(-d*d*75.0)*(.018+.055*charge)*visible;
    }
    return color;
}
float3 gardenTrace(float3 ro,float3 rd,GardenState s) {
    float ground=(-.08-ro.y)/rd.y;
    float3 floorPoint=ro+rd*ground;
    float3 color=gardenWater(floorPoint,rd,s);
    float nearest=ground;
    gardenObjects(ro,rd,s,color,nearest);
    if(nearest==ground) {
        float pool=1.0-smoothstep(.80,1.0,length(floorPoint.xz/float2(4.7,2.8)));
        if(pool>.01 && abs(floorPoint.x)<4.1 && floorPoint.z>-.8 && floorPoint.z<3.0) {
            float3 normal=normalize(float3(.006*sin(floorPoint.z*18.0+s.time*.65),1,.008*sin(floorPoint.x*16.0+s.time*.57)));
            float3 reflected=reflect(rd,normal), reflection=gardenSky(reflected,s);
            float distance=1e4;
            gardenObjects(floorPoint+float3(0,.003,0),reflected,s,reflection,distance);
            if(distance<100.0)color=mix(color,reflection,.32*pool*exp(-distance*.18));
        }
        for(int i=0;i<4;i++) {
            float2 q=(floorPoint.xz-gardenIslands[i].xz)/(gardenRadii[i].xz*1.15);
            color*=1.0-.38*exp(-dot(q,q)*2.0);
        }
    }
    return color+gardenPollen(ro,rd,s,nearest)+gardenSoftLight(ro,rd,s,nearest);
}
fragment float4 hingeGardenFragment(WallpaperVertex in [[stage_in]], constant WallpaperUniforms &u [[buffer(0)]]) {
    bool still=u.environment.z>.5;
    GardenState s={still?18.0:u.time,clamp(u.interaction.x,0.0,1.0),still?0.0:min(1.0,u.interaction.y+u.motion.z*.55),
        u.environment.x,u.environment.y,still?-1.0:u.interaction.z,still?-1.0:u.interaction.w,u.energy,clamp(u.environment.w,0.0,1.0)};
    float aspect=u.size.x/u.size.y;
    float span=max(7.8,8.3/aspect);
    float2 p=float2((in.uv.x-.5)*aspect,.73-in.uv.y)*span;
    float2 look=still?float2(0):clamp(u.motion.xy,float2(-1.5),float2(1.5));
    float yaw=look.x*.085+(still?0.0:.014*sin(s.time*.18));
    float3 camera=float3(sin(yaw)*9.0,5.0+look.y*.45+(still?0.0:.035*sin(s.time*.23)),cos(yaw)*9.0);
    float3 rd=normalize(-camera),right=normalize(cross(rd,float3(0,1,0))),up=cross(right,rd);
    float3 ro=camera+right*p.x+up*p.y;
    float3 color;
    if(p.y>3.0 || p.y< -3.3 || abs(p.x)>5.2) {
        color=float3(.009,.025,.032);
    } else {
        color=gardenTrace(ro,rd,s);
        // Shade subpixel silhouette/highlight edges, keeping flat sky and water single-sampled.
        float edge=length(fwidth(color));
        if(edge>.022) {
            float pixel=span/u.size.y;
            float3 a=(right*.375+up*.125)*pixel;
            float3 b=(-right*.125+up*.375)*pixel;
            color=(gardenTrace(ro-a,rd,s)+gardenTrace(ro+a,rd,s)
                +gardenTrace(ro-b,rd,s)+gardenTrace(ro+b,rd,s))*.25;
        }
    }
    float haze=exp(-pow((in.uv.y-.62)*5.0,2.0));
    color+=float3(.005,.016,.018)*haze;
    float vignette=1.0-.22*pow(length((in.uv-.5)*float2(1.05,.8)),2.0);
    color*=vignette;
    color=pow(max(color,0.0),float3(.82));
    color+=(hash21(in.uv*u.size)-.5)*.55/255.0;
    return float4(clamp(color,0.0,1.0),1);
}
