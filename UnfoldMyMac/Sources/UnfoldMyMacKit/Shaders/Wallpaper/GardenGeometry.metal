// Original Hinge Garden geometry. Each field has a ray bound; empty sky does no marching.
struct GardenState { float time, open, wind, battery, day, pollen, charge, activity, power; };
struct GardenHit { float t, material; float3 normal, local; };
float gardenEllipsoid(float3 p, float3 r) {
    float k0=length(p/r), k1=length(p/(r*r));
    return k0*(k0-1.0)/max(k1,.00001);
}
float gardenCapsule(float3 p, float3 a, float3 b, float r) {
    float3 q=p-a, v=b-a;
    return length(q-v*clamp(dot(q,v)/dot(v,v),0.0,1.0))-r;
}
float gardenBox(float3 p,float3 b) {
    float3 q=abs(p)-b; return length(max(q,0.0))+min(max(q.x,max(q.y,q.z)),0.0);
}
float gardenSmoothMin(float a,float b,float k) {
    float h=max(k-abs(a-b),0.0)/k; return min(a,b)-h*h*k*.25;
}
float2 gardenUnion(float2 a,float2 b) { return a.x<b.x?a:b; }
float2 gardenBound(float3 ro,float3 rd,float3 c,float3 r) {
    float3 o=(ro-c)/r,d=rd/r;
    float a=dot(d,d),b=dot(o,d),h=b*b-a*(dot(o,o)-1.0);
    if(h<0.0)return float2(1e4,-1);
    h=sqrt(h);return float2((-b-h)/a,(-b+h)/a);
}
float2 gardenBoxBound(float3 ro,float3 rd,float3 lower,float3 upper) {
    float3 direction=select(rd,float3(.000001),abs(rd)<.000001);
    float3 a=(lower-ro)/direction,b=(upper-ro)/direction;
    float3 near=min(a,b),far=max(a,b);
    return float2(max(near.x,max(near.y,near.z)),min(far.x,min(far.y,far.z)));
}
float3 gardenSnailOrigin(GardenState s) { return float3(.15+.13*sin(s.time*.16),.0,.18+.022*sin(s.time*.23)); }
float gardenCharge(GardenState s) {
    // Wait for the current to reach the greenhouse, then retain a soft light for the AC connection.
    // Launch and wake have no pulse, so their connected light can appear immediately.
    float arrival=s.charge<0.0?1.0:smoothstep(4.7,5.8,s.charge);
    float pulse=s.charge<0.0?0.0:1.0-smoothstep(6.8,9.0,s.charge);
    return arrival*max(pulse,.7*s.power);
}

// One continuous route: water and moss share root coordinates; the stem continues up the shell.
float2 gardenRootSignal(float2 p,GardenState s) {
    float end=gardenSnailOrigin(s).x-.22;
    if(p.x< -3.8 || p.x>end+.12 || p.y<.08 || p.y>1.25)return float2(0);
    float along=(p.x+3.8)/(end+3.8);
    float fade=smoothstep(0.0,.06,along)*(1.0-smoothstep(.96,1.03,along));
    float roots=0, pulse=0;
    for(int i=0;i<3;i++) {
        float branch=float(i-1);
        float z=.61+(.22*sin(along*6.0+branch*.6)+branch*.36)*(1.0-along);
        float d=abs(p.y-z);
        float line=exp(-d*d*5000.0)+.24*exp(-d*d*280.0);
        roots+=line*fade;
        float head=s.charge/3.0;
        float front=exp(-pow((along-head)*14.0,2.0));
        float trail=smoothstep(head-.22,head,along)*(1.0-smoothstep(head,head+.025,along))*.35;
        if(s.charge>=0.0 && s.charge<3.5) pulse+=line*fade*(front+trail);
    }
    return float2(roots,pulse);
}
float gardenStemSignal(float3 p,GardenState s) {
    if(s.charge<2.8 || s.charge>5.2)return 0;
    float along=(p.y-.28)/1.2;
    float x=-.22+.07*sin(along*4.0);
    float line=exp(-pow((p.x-x)*52.0,2.0))+.22*exp(-pow((p.x-x)*14.0,2.0));
    float pulse=exp(-pow((along-(s.charge-3.0)/1.7)*8.0,2.0));
    return line*pulse*smoothstep(.04,.22,p.z)*smoothstep(-.03,.05,along)*(1.0-smoothstep(.98,1.08,along));
}

// Materials: 1 moss, 2 nacre shell, 3 living glass, 4 greenhouse glazing, 5 bronze, 6 foliage, 7 lantern.
float2 gardenSnail(float3 p,GardenState s,bool glazing=true) {
    float breath=.010*sin(s.time*1.35);
    float body=smoothstep(.23,1.0,s.open), feelers=smoothstep(.02,.48,s.open);
    float2 hit=float2(gardenEllipsoid(p-float3(-.22,.83+breath,0),float3(.61,.58,.43)),2);
    float3 q=p-float3(.12,.36,0);
    float foot=gardenEllipsoid(q,float3(.62+.48*body,.135+breath,.26));
    float3 head=float3(.25+.79*body,.42+.18*body,.015);
    float neck=gardenEllipsoid(p-head,float3(.22,.22,.185));
    hit=gardenUnion(hit,float2(gardenSmoothMin(foot,neck,.16),3));
    float turn=.095*pow(max(0.0,sin(s.time*.29)),4.0);
    for(int i=0;i<2;i++) {
        float side=i==0?-1.0:1.0;
        float3 base=head+float3(.06,.12,side*.09);
        float3 tip=base+float3((.14+.040*sin(s.time*.71+float(i)*2.0))*feelers,
            (.37+.035*sin(s.time*.91+float(i)*3.0))*feelers,side*.10*feelers+turn);
        hit=gardenUnion(hit,float2(gardenCapsule(p,base,tip,.014),3));
        hit=gardenUnion(hit,float2(length(p-tip)-.024,7));
    }
    // A glazed pitched-roof greenhouse, with visible copper mullions and growing things inside.
    q=p-float3(-.23,1.58+breath,0);
    q.xz=rotate2(q.xz,-.24);
    float3 b=float3(.39,.23,.29);
    float roof=q.y+.64*abs(q.x)-.48;
    float house=max(gardenBox(q-float3(0,.11,0),float3(b.x,.34,b.z)),roof);
    if(glazing) hit=gardenUnion(hit,float2(abs(house)-.003,4));
    float beams=1e3;
    for(int i=0;i<4;i++) {
        float x=(i&1)?b.x:-b.x,z=(i&2)?b.z:-b.z;
        beams=min(beams,gardenCapsule(q,float3(x,-.23,z),float3(x,.23,z),.013));
        beams=min(beams,gardenCapsule(q,float3(x,.23,z),float3(0,.48,z),.014));
    }
    beams=min(beams,gardenBox(float3(abs(q.x)-b.x,q.y,q.z),float3(.014,.014,b.z)));
    beams=min(beams,gardenBox(float3(q.x,q.y,abs(q.z)-b.z),float3(.012,.23,.012)));
    beams=min(beams,gardenBox(q-float3(0,-.23,0),float3(.415,.023,.315)));
    beams=min(beams,gardenCapsule(q,float3(0,.48,-b.z),float3(0,.48,b.z),.016));
    hit=gardenUnion(hit,float2(beams,5));
    for(int j=0;j<3;j++) {
        float x=float(j-1)*.19;
        float3 plant=q-float3(x,-.12,-.06);
        float stem=gardenCapsule(plant,float3(0,-.08,0),float3(.025,.20,0),.012);
        plant.xy=rotate2(plant.xy,(float(j)-1.0)*.4);
        float leaf=gardenEllipsoid(plant-float3(.02,.12,0),float3(.068,.13,.045));
        hit=gardenUnion(hit,float2(min(stem,leaf),6));
    }
    hit=gardenUnion(hit,float2(length(q-float3(.14,.20,.08))-.046,7));
    return hit;
}

float gardenPlantSway(float height,GardenState s,float seed) {
    return (.039*sin(s.time*(.49+seed*.039)+seed*4.0)+.009*sin(s.time*1.13+seed*2.0)
        +s.wind*.085*sin(s.time*.8+seed))*height*height;
}
float gardenPetalWhorl(float3 p,float phase,float opening,bool inner) {
    // Polar repetition gives each whorl overlapping, rounded petals with constant field cost.
    float count=inner?6.0:9.0, sector=6.2831853/count;
    float angle=atan2(p.x,p.z)+phase;
    angle=fract(angle/sector+.5)*sector-sector*.5;
    float radius=length(p.xz);
    float3 q=float3(sin(angle)*radius,p.y,cos(angle)*radius);
    float tilt=(inner?.58:.26)+(1.0-opening)*1.02;
    q.yz=rotate2(q.yz,tilt);
    float reach=inner?.22:.31, center=inner?.145:.23;
    // A shallow cup and gently lifted tip, rather than a flat blade.
    q.y-=.23*q.z*q.z;
    q.z-=center;
    return gardenEllipsoid(q,float3(inner?.105:.145,inner?.040:.043,reach));
}
float2 gardenPlant(float3 p,GardenState s,float seed) {
    p.x-=gardenPlantSway(p.y,s,seed);
    float height=.82+seed*.065;
    float stem=gardenCapsule(p,float3(0,0,0),float3(.0,height,0),.012);
    float2 hit=float2(stem,6);
    float opening=.12+(.85+.03*sin(s.time*.38+seed*2.0))*smoothstep(.15,.95,s.open)+.14*gardenCharge(s);
    float3 bloom=p-float3(0,height,0);
    float petals=min(gardenPetalWhorl(bloom,seed*.9,opening,false),
        gardenPetalWhorl(bloom-float3(0,.025,0),seed*.9+.31,opening,true));
    hit=gardenUnion(hit,float2(petals,8+step(2.5,seed)));
    for(int j=0;j<2;j++) {
        float3 q=p-float3(0,.23+float(j)*.22,0);
        q.xz=rotate2(q.xz,float(j)*2.5+seed);
        q.xy=rotate2(q.xy,-1.0);
        hit=gardenUnion(hit,float2(gardenEllipsoid(q-float3(0,.095,0),float3(.068,.145,.019)),6));
    }
    hit=gardenUnion(hit,float2(gardenEllipsoid(bloom-float3(0,.035,0),float3(.088,.043,.088)),10));
    float angle=atan2(bloom.x,bloom.z),sector=6.2831853/7.0;
    angle=fract(angle/sector+.5)*sector-sector*.5;
    float radius=length(bloom.xz);
    float3 stamen=float3(sin(angle)*radius,bloom.y-.082,cos(angle)*radius-.063);
    hit=gardenUnion(hit,float2(length(stamen)-.012,10));
    return hit;
}
float2 gardenField(float3 p,GardenState s,int kind,float seed,bool glazing=true) {
    return kind==0?gardenSnail(p,s,glazing):gardenPlant(p,s,seed);
}
GardenHit gardenMarch(float3 ro,float3 rd,float2 bounds,GardenState s,int kind,float seed,bool glazing=true) {
    GardenHit hit={1e4,0,float3(0,1,0),float3(0)};
    float t=max(bounds.x,0.0);
    // Grazing rays at overlapping petal rims need time to converge; early exhaustion leaves pinholes.
    for(int i=0;i<112 && t<bounds.y;i++) {
        float3 p=ro+rd*t;
        float2 d=gardenField(p,s,kind,seed,glazing);
        if(d.x<.0012) {
            const float2 e=float2(.0012,0);
            float3 n=float3(gardenField(p+e.xyy,s,kind,seed,glazing).x-gardenField(p-e.xyy,s,kind,seed,glazing).x,
                gardenField(p+e.yxy,s,kind,seed,glazing).x-gardenField(p-e.yxy,s,kind,seed,glazing).x,
                gardenField(p+e.yyx,s,kind,seed,glazing).x-gardenField(p-e.yyx,s,kind,seed,glazing).x);
            hit={t,d.y,normalize(n),p}; break;
        }
        t+=max(.0008,d.x*.82);
    }
    return hit;
}
