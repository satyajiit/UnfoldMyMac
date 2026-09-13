// A long-wheelbase single-seater, modelled in metres scaled to a 4.7-unit length.
// Materials: 1 lacquer, 2 carbon, 3 rubber, 4 titanium, 5 white, 11 visor, 12 helmet.
float raceBox(float3 p, float3 b, float r=0) {
    float3 q=abs(p)-b;
    return length(max(q,0.0))+min(max(q.x,max(q.y,q.z)),0.0)-r;
}
float raceEllipsoid(float3 p, float3 r) {
    float k0=length(p/r), k1=length(p/(r*r));
    return k0*(k0-1)/max(k1,.0001);
}
float raceBlend(float a,float b,float k) {
    float h=clamp(.5+.5*(b-a)/k,0.0,1.0);
    return mix(b,a,h)-k*h*(1-h);
}
float raceRod(float3 p,float3 a,float3 b,float r) {
    float3 ab=b-a;
    return length(p-a-ab*clamp(dot(p-a,ab)/dot(ab,ab),0.0,1.0))-r;
}
float raceCylinderX(float3 p,float radius,float halfWidth) {
    float2 d=float2(length(p.yz)-radius,abs(p.x)-halfWidth);
    return min(max(d.x,d.y),0.0)+length(max(d,0.0));
}
float raceAerofoil(float3 p,float span,float chord,float thickness) {
    // Cambered, swept wing sections, not rectangular planks.
    p.z-=.10*p.x*p.x;
    p.y-=.035*p.x*p.x;
    float2 q=p.yz/float2(thickness,chord);
    float elliptical=(length(q)-1)*thickness;
    return max(elliptical,abs(p.x)-span);
}
void raceUnion(thread float2 &result,float distance,float material) {
    if(distance<result.x) result=float2(distance,material);
}
float2 raceBody(float3 p) {
    float tub=raceEllipsoid(p-float3(0,.46,.12),float3(.34,.245,.80));
    float noseProgress=smoothstep(.30,2.13,p.z);
    float center=mix(.40,.245,noseProgress), width=mix(.275,.065,noseProgress);
    float nose=raceBox(float3(p.x,p.y-center,p.z-1.22),float3(width,mix(.16,.045,noseProgress),.91),.028)*.72;
    float shell=raceBlend(tub,nose,.12);
    float engine=raceEllipsoid(p-float3(0,.46,-.92),float3(.265,.33,.85));
    shell=raceBlend(shell,engine,.14);
    float cockpit=raceEllipsoid(p-float3(0,.65,-.14),float3(.225,.23,.38));
    shell=max(shell,-cockpit);
    float3 side=float3(abs(p.x)-.435,p.y-.31,p.z+.58);
    float pod=raceEllipsoid(side,float3(.305,.22,.91));
    float undercut=raceEllipsoid(float3(abs(p.x)-.59,p.y-.11,p.z+.01),float3(.29,.18,.64));
    pod=max(pod,-undercut);
    float inlet=raceEllipsoid(float3(abs(p.x)-.47,p.y-.40,p.z-.15),float3(.185,.08,.16));
    pod=max(pod,-inlet);
    shell=raceBlend(shell,pod,.09);
    float2 result=float2(shell,1);
    // Airbox and tapered engine fin.
    float airbox=raceEllipsoid(p-float3(0,.86,-.57),float3(.145,.235,.20));
    float intake=raceEllipsoid(p-float3(0,.94,-.405),float3(.107,.116,.10));
    raceUnion(result,max(airbox,-intake),1);
    float fin=raceBox(p-float3(0,.70,-1.11),float3(.018,.24,.53),.01);
    raceUnion(result,max(fin,p.y-(1.04+p.z*.18)),1);
    // Carbon floor, rear diffuser, and vertical turning vanes.
    raceUnion(result,raceBox(p-float3(0,.075,-.24),float3(.73,.012,1.41),.025),2);
    float3 diffuser=p-float3(0,.13,-1.72); diffuser.yz=rotate2(diffuser.yz,.16);
    raceUnion(result,raceBox(diffuser,float3(.65,.014,.25),.015),2);
    raceUnion(result,raceBox(float3(abs(p.x)-.42,p.y-.14,p.z+1.78),float3(.014,.075,.23),.006),2);
    // Cockpit seat and driver, with a separate reflective visor.
    raceUnion(result,raceEllipsoid(p-float3(0,.40,-.17),float3(.195,.105,.30)),2);
    raceUnion(result,raceEllipsoid(p-float3(0,.65,-.27),float3(.126,.135,.145)),12);
    raceUnion(result,raceEllipsoid(p-float3(0,.665,-.145),float3(.115,.048,.025)),11);
    return result;
}
float2 raceRunningGear(float3 p,float2 result) {
    float3 m=float3(abs(p.x),p.y,p.z);
    float z=abs(p.z-1.27)<abs(p.z+1.30)?1.27:-1.30;
    float halfWidth=z>0?.133:.161;
    float3 wheel=m-float3(.875,.345,z);
    float outer=raceCylinderX(wheel,.326,halfWidth)-.019;
    float hollow=raceCylinderX(wheel,.212,halfWidth+.08);
    raceUnion(result,max(outer,-hollow),3);
    raceUnion(result,raceCylinderX(wheel,.208,halfWidth-.032),4);
    raceUnion(result,raceCylinderX(wheel-float3(halfWidth-.015,0,0),.063,.03),4);
    // Double wishbones and pushrods connect the chassis to each exposed wheel.
    float front=min(raceRod(m,float3(.21,.24,.66),float3(.86,.30,1.27),.016),
                    raceRod(m,float3(.19,.24,1.65),float3(.86,.30,1.27),.016));
    front=min(front,raceRod(m,float3(.23,.43,.89),float3(.86,.35,1.27),.014));
    front=min(front,raceRod(m,float3(.18,.47,.61),float3(.83,.26,1.27),.018));
    float rear=min(raceRod(m,float3(.27,.23,-.64),float3(.87,.30,-1.30),.018),
                   raceRod(m,float3(.24,.23,-1.71),float3(.87,.30,-1.30),.018));
    rear=min(rear,raceRod(m,float3(.25,.55,-.77),float3(.84,.30,-1.30),.018));
    raceUnion(result,min(front,rear),2);
    // Elliptical halo and its three supports.
    float2 ellipse=float2(p.x/.282,(p.z+.075)/.51);
    float halo=length(float2((length(ellipse)-1)*.282,p.y-.815))-.032;
    halo=min(halo,raceRod(p,float3(0,.815,.435),float3(0,.47,.56),.032));
    halo=min(halo,raceRod(m,float3(.23,.815,-.36),float3(.25,.51,-.51),.032));
    raceUnion(result,halo,2);
    raceUnion(result,raceRod(m,float3(.25,.55,.21),float3(.48,.60,.29),.013),2);
    raceUnion(result,raceEllipsoid(m-float3(.51,.61,.29),float3(.10,.039,.060)),5);
    // Camera on the airbox, and nose-to-front-wing pylons.
    raceUnion(result,raceBox(p-float3(0,1.12,-.57),float3(.18,.023,.035),.012),2);
    raceUnion(result,raceBox(float3(abs(p.x)-.095,p.y-.18,p.z-1.94),float3(.012,.085,.055),.01),2);
    return result;
}
float2 raceWings(float3 p,float time,float2 result) {
    raceUnion(result,raceAerofoil(p-float3(0,.115,2.10),.99,.19,.020),5);
    raceUnion(result,raceAerofoil(p-float3(0,.168,1.91),.97,.15,.019),1);
    raceUnion(result,raceAerofoil(p-float3(0,.213,1.76),.92,.12,.016),2);
    float endplate=raceBox(float3(abs(p.x)-.98,p.y-.235,p.z-2.03),float3(.015,.115,.28),.018);
    endplate=max(endplate,p.y-(.45-.085*p.z));
    raceUnion(result,endplate,1);
    raceUnion(result,raceAerofoil(p-float3(0,.84,-2.00),.77,.20,.028),1);
    float3 flap=p-float3(0,1.015,-2.08);
    flap.yz=rotate2(flap.yz,.15+.16*smoothstep(6.0,8.0,fmod(time,18.0)));
    raceUnion(result,raceAerofoil(flap,.77,.17,.024),5);
    raceUnion(result,raceBox(float3(abs(p.x)-.78,p.y-.87,p.z+2.02),float3(.018,.205,.265),.02),1);
    raceUnion(result,raceRod(float3(abs(p.x),p.y,p.z),float3(.22,.17,-1.69),float3(.22,.86,-2.04),.025),2);
    return result;
}
float2 raceMap(float3 p,float time) {
    p.y-=sin(time*7)*.003;
    float2 result=raceBody(p);
    result=raceRunningGear(p,result);
    return raceWings(p,time,result);
}
