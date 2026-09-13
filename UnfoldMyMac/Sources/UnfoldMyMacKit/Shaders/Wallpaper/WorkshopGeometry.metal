// Original procedural toy workshop. Each object is marched only inside its own ray bounds.
struct WorkshopState { float time, open, apps, stock, connected, daylight, charging; };
struct WorkshopHit { float t, material, ao; float3 normal, point; };

float wsBox(float3 p,float3 b,float radius) {
    float3 q=abs(p)-b+radius;
    return length(max(q,0.0))+min(max(q.x,max(q.y,q.z)),0.0)-radius;
}
float wsCylinder(float3 p,float radius,float height) {
    float2 q=float2(length(p.xz)-radius,abs(p.y)-height);
    return min(max(q.x,q.y),0.0)+length(max(q,0.0));
}
float wsCapsule(float3 p,float3 a,float3 b,float radius) {
    float3 q=p-a,v=b-a;
    return length(q-v*clamp(dot(q,v)/max(dot(v,v),.0001),0.0,1.0))-radius;
}
float wsEllipsoid(float3 p,float3 r) {
    float k0=length(p/r),k1=length(p/(r*r));
    return k0*(k0-1.0)/max(k1,.00001);
}
float2 wsUnion(float2 a,float d,float material) { return d<a.x?float2(d,material):a; }
float2 wsBound(float3 ro,float3 rd,float3 low,float3 high) {
    float3 safe=select(float3(.00001),rd,abs(rd)>.00001);
    float3 a=(low-ro)/safe,b=(high-ro)/safe;
    float3 near=min(a,b),far=max(a,b);
    return float2(max(.001,max(near.x,max(near.y,near.z))),min(far.x,min(far.y,far.z)));
}

float2 wsLidDetails(float3 q,WorkshopState s,float2 d) {
    float3 clock=q-float3(-1.88,-.15,2.34);
    d=wsUnion(d,wsCylinder(clock,.35,.043),4);
    d=wsUnion(d,wsCylinder(clock-float3(0,-.046,0),.298,.012),9);
    float2 hand=rotate2(clock.xz,.55);
    d=wsUnion(d,wsBox(float3(hand.x,clock.y+.063,hand.y-.10),float3(.014,.012,.115),.006),7);
    hand=rotate2(clock.xz,-.78);
    d=wsUnion(d,wsBox(float3(hand.x,clock.y+.065,hand.y-.065),float3(.016,.013,.08),.007),7);
    d=wsUnion(d,length(clock-float3(0,-.085,0))-.025,4);
    float3 paper=q-float3(-.68,-.13,2.30); paper.xz=rotate2(paper.xz,-.065);
    d=wsUnion(d,wsBox(paper,float3(.48,.014,.34),.008),10);
    d=wsUnion(d,length(q-float3(-.68,-.17,2.59))-.035,5);
    // Three tools hang on the felt backing: brass rule, screwdriver, wooden mallet.
    float3 tool=q-float3(.55,-.18,2.40);
    d=wsUnion(d,wsBox(tool,float3(.085,.035,.42),.018),4);
    tool=q-float3(1.05,-.21,2.40);
    d=wsUnion(d,wsCapsule(tool,float3(0,0,-.30),float3(0,0,.24),.023),4);
    d=wsUnion(d,wsBox(tool-float3(0,0,.22),float3(.065,.065,.16),.045),5);
    tool=q-float3(1.72,-.22,2.40);
    d=wsUnion(d,wsCapsule(tool,float3(0,0,-.31),float3(0,0,.19),.038),1);
    d=wsUnion(d,wsBox(tool-float3(0,0,.24),float3(.21,.085,.10),.04),3);
    return d;
}

float2 wsCase(float3 p,WorkshopState s) {
    float2 d=float2(wsBox(p,float3(2.96,.17,1.62),.095),1);
    d=wsUnion(d,wsBox(p-float3(0,.18,0),float3(2.76,.025,1.43),.018),2);
    d=wsUnion(d,wsBox(p-float3(0,.26,1.54),float3(2.94,.24,.085),.055),1);
    d=wsUnion(d,wsBox(float3(abs(p.x)-2.87,p.y-.26,p.z),float3(.085,.24,1.54),.05),1);
    d=wsUnion(d,wsBox(p-float3(0,.26,-1.53),float3(2.9,.24,.075),.04),1);
    // Brass corner caps and two front latches retain a recognisable case silhouette when closed.
    float3 corner=float3(abs(p.x)-2.84,p.y-.14,abs(p.z)-1.49);
    d=wsUnion(d,wsBox(corner,float3(.105,.16,.105),.04),4);
    d=wsUnion(d,wsBox(float3(abs(p.x)-1.53,p.y-.30,p.z-1.641),float3(.115,.14,.025),.023),4);
    d=wsUnion(d,wsBox(p-float3(0,.12,1.71),float3(.42,.055,.05),.04),7);
    // The lid rotates around the same hinge throughout its travel; there are no trigger animations.
    float3 q=p-float3(0,.49,-1.53);
    q.yz=rotate2(q.yz,s.open*1.83);
    d=wsUnion(d,wsBox(q-float3(0,0,1.55),float3(2.97,.09,1.64),.085),1);
    d=wsUnion(d,wsBox(q-float3(0,-.097,1.55),float3(2.72,.019,1.39),.018),2);
    return wsLidDetails(q,s,d);
}

float2 wsMachine(float3 q,int bench,float live,float phase) {
    float stroke=.028*(.35+.65*live)*(.5+.5*sin(phase));
    float2 d=float2(wsBox(q-float3(0,.735,0),float3(.109,.06,.15),.028),3);
    if(bench==0) {
        d=wsUnion(d,wsBox(q-float3(-.067,.86,-.03),float3(.037,.13,.08),.016),3);
        d=wsUnion(d,wsBox(q-float3(0,.965,0),float3(.109,.03,.115),.015),3);
        d=wsUnion(d,wsCylinder(q-float3(.022,.875-stroke,.015),.023,.07),4);
        d=wsUnion(d,wsBox(q-float3(.018,.812-stroke,.015),float3(.069,.012,.082),.007),4);
        d=wsUnion(d,wsBox(q-float3(.015,.785,.018),float3(.066,.013,.080),.002),9);
    } else if(bench==1) {
        d=wsUnion(d,wsCylinder((q-float3(0,.825,-.035)).yxz,.066,.090),4);
        d=wsUnion(d,wsCylinder((q-float3(0,.825,.078)).yxz,.061,.090),3);
        d=wsUnion(d,wsBox(q-float3(0,.790,.145),float3(.071,.004,.072),.002),9);
    } else {
        d=wsUnion(d,wsCapsule(q,float3(.067,.77,-.08),float3(.067,1.01,-.08),.029),4);
        d=wsUnion(d,wsBox(q-float3(.012,1.0,-.035),float3(.095,.045,.092),.026),3);
        d=wsUnion(d,wsCapsule(q,float3(-.04,.97-stroke,.027),float3(-.04,.86-stroke,.027),.013),4);
        d=wsUnion(d,wsBox(q-float3(-.024,.801,.025),float3(.047,.013,.056),.008),1);
    }
    d=wsUnion(d,wsCylinder((q-float3(.062,.733,.153)).xzy,.018,.004),live>.001?20+live:7);
    return d;
}

float2 wsStation(float3 p,WorkshopState s,int bench) {
    int slot=int(clamp(floor((p.x+.60)/.30),0.0,3.0));
    float3 q=p-float3(-.45+float(slot)*.30,0,-.055);
    float live=smoothstep(float(bench*4+slot),float(bench*4+slot)+.8,s.apps);
    float2 d=wsMachine(q,bench,live,s.time*1.1+float(slot)*.65);
    float tilt=(1-smoothstep(.25,.85,s.open))*.85;
    float3 tip=float3(0,1.16-.22*tilt,-.17+.24*tilt);
    d=wsUnion(d,wsCapsule(q,float3(0,.70,-.20),float3(0,.99,-.20),.014),4);
    d=wsUnion(d,wsCapsule(q,float3(0,.99,-.20),tip,.016),4);
    d=wsUnion(d,length(q-float3(0,.99,-.20))-.029,4);
    float3 shade=q-tip; shade.yz=rotate2(shade.yz,.65);
    d=wsUnion(d,wsEllipsoid(shade,float3(.108,.067,.085)),2);
    d=wsUnion(d,wsCylinder(shade+float3(0,.049,0),.067,.008),live>.001?20+live:3);
    return d;
}

float2 wsBench(float3 p,WorkshopState s,int index) {
    float2 d=float2(wsBox(p-float3(0,.60,0),float3(.65,.09,.43),.035),1);
    d=wsUnion(d,wsBox(p-float3(0,.697,0),float3(.60,.013,.37),.012),2);
    float3 legs=float3(abs(p.x)-.52,p.y-.28,abs(p.z)-.31);
    d=wsUnion(d,wsBox(legs,float3(.045,.29,.045),.018),3);
    d=wsUnion(d,wsBox(p-float3(0,.46,.0),float3(.55,.065,.34),.016),1);
    d=wsUnion(d,wsBox(p-float3(.25,.47,.359),float3(.11,.014,.027),.012),4);
    float2 station=wsStation(p,s,index); d=wsUnion(d,station.x,station.y);
    float3 wheel=p-float3(-.685,.46,.06);
    d=wsUnion(d,torus(wheel.yxz,float2(.15,.022)),4);
    float angle=s.time*.55;
    for(int i=0;i<3;i++) {
        float2 end=rotate2(float2(0,.14),angle+float(i)*2.0944);
        d=wsUnion(d,wsCapsule(wheel,float3(0),float3(0,end.x,end.y),.014),4);
    }
    if(index==1) {
        float2 handle=rotate2(float2(.10,0),angle);
        d=wsUnion(d,wsCapsule(p,float3(-.1,.50,.39),float3(-.1+handle.x,.50+handle.y,.47),.019),4);
        d=wsUnion(d,wsCapsule(p,float3(-.1+handle.x,.50+handle.y,.47),float3(-.1+handle.x,.50+handle.y,.57),.035),1);
    }
    return d;
}

float2 wsShelf(float3 p,WorkshopState s) {
    float2 d=float2(wsBox(float3(abs(p.x)-.81,p.y-.75,p.z),float3(.04,.76,.235),.02),3);
    d=wsUnion(d,wsBox(p-float3(0,.73,-.215),float3(.81,.75,.025),.018),1);
    int row=int(clamp(floor((p.y-.02)/.35),0.0,3.0));
    float shelfY=.035+float(row)*.35;
    d=wsUnion(d,wsBox(p-float3(0,shelfY,0),float3(.83,.035,.245),.014),1);
    d=wsUnion(d,wsBox(p-float3(0,1.47,0),float3(.86,.04,.26),.02),1);
    int col=int(clamp(floor((p.x+.78)/.26),0.0,5.0));
    int slot=row*6+col;
    float growth=smoothstep(float(slot),float(slot)+.85,s.stock);
    if(growth>.005) {
        float height=(.17+.035*hash21(float2(slot,9)))*growth;
        float3 q=p-float3(-.65+float(col)*.26,shelfY+.035+height*.5,.02);
        q.xz=rotate2(q.xz,(hash21(float2(slot,4))-.5)*.15);
        d=wsUnion(d,wsBox(q,float3(.111*growth,height*.5,.17*growth),.012*growth),6+float(slot%3)*.1);
        d=wsUnion(d,wsBox(q-float3(0,0,.171*growth),float3(.018*growth,height*.48,.004),.002),9);
    }
    return d;
}

float2 wsMaker(float3 p,WorkshopState s) {
    float rise=smoothstep(.40,.95,s.open);
    float bob=.020*sin(s.time*1.25)*rise;
    float shift=.026*sin(s.time*.7)*rise;
    float2 d=float2(wsCylinder(p-float3(0,.22,-.18),.215,.055),1);
    float3 leg=float3(abs(p.x)-.13,p.y-.085,p.z+.18);
    d=wsUnion(d,wsCapsule(leg,float3(0,-.08,0),float3(0,.10,0),.028),3);
    float3 body=p-float3(shift,.54+rise*.08+bob,0);
    d=wsUnion(d,wsEllipsoid(body,float3(.20,.25,.155)),11);
    d=wsUnion(d,wsBox(body-float3(0,-.025,.136),float3(.149,.17,.027),.024),5);
    for(int sign=-1;sign<=1;sign+=2) {
        d=wsUnion(d,wsCapsule(p,float3(sign*.105+shift,.40+rise*.06,.04),float3(sign*.145,.115,.18),.046),4);
        d=wsUnion(d,wsEllipsoid(p-float3(sign*.145,.082,.235),float3(.077,.052,.125)),7);
        d=wsUnion(d,length(body-float3(sign*.105,.09,.164))-.018,4);
    }
    float3 head=p-float3(shift,.96+rise*.10+bob,0);
    head.xz=rotate2(head.xz,.10*sin(s.time*.45)*rise);
    head.yz=rotate2(head.yz,.035*sin(s.time*.8)*rise);
    d=wsUnion(d,wsEllipsoid(head,float3(.238,.216,.199)),11);
    d=wsUnion(d,wsEllipsoid(head-float3(0,.185,-.015),float3(.258,.075,.218)),2);
    d=wsUnion(d,wsEllipsoid(head-float3(0,.163,.17),float3(.245,.022,.095)),2);
    float blink=1.0-.84*pow(max(0.0,cos(s.time*.91)),48.0);
    d=wsUnion(d,wsEllipsoid(float3(abs(head.x)-.083,head.y-.010,head.z-.183),float3(.022,.030*blink,.017)),7);
    d=wsUnion(d,wsEllipsoid(head-float3(0,-.044,.204),float3(.036,.029,.036)),4);
    float turn=s.time*.55;
    // The right hand shares the central bench crank's exact phase and endpoint.
    float2 crank=rotate2(float2(.10,0),turn);
    float3 hand=float3(.41+crank.x,.50+crank.y,-.49);
    d=wsUnion(d,wsCapsule(p,float3(.18+shift,.68+rise*.05+bob,0),float3(.32,.47,-.13),.035),4);
    d=wsUnion(d,wsCapsule(p,float3(.32,.47,-.13),hand,.030),4);
    d=wsUnion(d,length(p-hand)-.053,1);
    float3 restingHand=float3(-.30+shift+.025*sin(s.time*.8)*rise,.42+.018*cos(s.time*.8)*rise,.09);
    d=wsUnion(d,wsCapsule(p,float3(-.18+shift,.68+rise*.05+bob,0),restingHand+float3(0,.02,0),.037),4);
    d=wsUnion(d,length(p-restingHand)-.057,1);
    // A winding key at the maker's back gives it a toy silhouette from oblique views.
    float3 key=p-float3(shift,.65+bob,-.19);
    d=wsUnion(d,wsCapsule(key,float3(0),float3(0,0,-.10),.021),4);
    d=wsUnion(d,torus(float3(abs(key.x)-.055,key.z+.12,key.y),float2(.055,.014)),4);
    return d;
}

float2 wsMug(float3 p,WorkshopState s) {
    float body=wsCylinder(p-float3(0,.22,0),.175,.20)-.018;
    float hollow=wsCylinder(p-float3(0,.285,0),.139,.20);
    float2 d=float2(max(body,-hollow),3);
    d=wsUnion(d,wsCylinder(p-float3(0,.395,0),.133,.006),7);
    d=wsUnion(d,torus((p-float3(.19,.24,0)).yxz,float2(.103,.027)),3);
    d=wsUnion(d,wsBox(p-float3(-.36,.029,.08),float3(.18,.025,.24),.014),10);
    return d;
}

float2 wsMap(float3 p,WorkshopState s,int kind,int index) {
    switch(kind) {
        case 0: return wsCase(p,s);
        case 1: return wsBench(p,s,index);
        case 2: return wsShelf(p,s);
        case 3: return wsMaker(p,s);
        default: return wsMug(p,s);
    }
}

void wsTracePart(float3 ro,float3 rd,float3 origin,float3 low,float3 high,float squash,
                 WorkshopState s,int kind,int index,thread WorkshopHit &hit) {
    float3 scale=float3(1,squash,1);
    float3 localOrigin=(ro-origin)/scale,localDirection=rd/scale;
    float rate=length(localDirection); localDirection/=rate;
    float2 bound=wsBound(localOrigin,localDirection,low,high);
    bound.y=min(bound.y,hit.t*rate);
    if(bound.y<=bound.x) return;
    float t=bound.x;
    for(int step=0;step<112;step++) {
        float3 p=localOrigin+localDirection*t;
        float2 distance=wsMap(p,s,kind,index);
        float epsilon=.0011;
        if(distance.x<epsilon) {
            float2 e=float2(.0008,-.0008);
            float3 normal=normalize(e.xyy*wsMap(p+e.xyy,s,kind,index).x+e.yyx*wsMap(p+e.yyx,s,kind,index).x
                +e.yxy*wsMap(p+e.yxy,s,kind,index).x+e.xxx*wsMap(p+e.xxx,s,kind,index).x);
            float ao=0;
            for(int i=1;i<=3;i++) {
                float reach=float(i)*.045;
                ao+=(reach-wsMap(p+normal*reach,s,kind,index).x)/reach*pow(.55,float(i-1));
            }
            hit={t/rate,distance.y,clamp(1.0-ao*.37,.28,1.0),normalize(normal/scale),ro+rd*(t/rate)};
            return;
        }
        t+=max(distance.x*.88,.0005);
        if(t>bound.y) return;
    }
}
