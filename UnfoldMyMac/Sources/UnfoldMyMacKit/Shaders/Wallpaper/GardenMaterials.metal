// Layered surface detail and area-light approximations; no stochastic per-frame noise.
float gardenNoise(float3 p) {
    float3 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
    float2 q=i.xy+float2(37,17)*i.z;
    float a=mix(mix(hash21(q),hash21(q+float2(1,0)),f.x),mix(hash21(q+float2(0,1)),hash21(q+1),f.x),f.y);
    q+=float2(37,17);
    float b=mix(mix(hash21(q),hash21(q+float2(1,0)),f.x),mix(hash21(q+float2(0,1)),hash21(q+1),f.x),f.y);
    return mix(a,b,f.z);
}
float3 gardenSky(float3 rd,GardenState s) {
    float sun=pow(max(0.0,dot(rd,normalize(float3(-.6,.9,.6)))),28.0);
    return mix(float3(.014,.046,.06),float3(.045,.105,.115),s.day*s.open)+float3(.55,.36,.15)*sun*s.open*.6;
}
float3 gardenMossMaterial(float3 p,float3 n,float3 light,GardenState s) {
    // Broad, low-contrast colour variation reads as velvet at Retina scale. No pixel-sized fibers.
    float terrain=gardenNoise(p*3.5)*.78+gardenNoise(p*10.0)*.22;
    float velvet=.97+.06*gardenNoise(p*42.0);
    float moss=smoothstep(-.08,.72,n.y);
    float3 sage=mix(float3(.11,.205,.145),float3(.23,.335,.215),terrain);
    float3 color=mix(float3(.023,.048,.043),sage,moss)*(light*.77+.24)*velvet;
    color+=float3(.13,.21,.135)*moss*pow(max(n.y,0.0),3.0)*.20;
    float2 contact=(p.xz-gardenSnailOrigin(s).xz)/float2(.93,.34);
    color*=1.0-.22*exp(-dot(contact,contact)*1.5)*moss;
    float lightPool=exp(-dot(p.xz,p.xz)*.17);
    color+=float3(.30,.24,.105)*gardenCharge(s)*lightPool*moss*.40;
    float2 roots=gardenRootSignal(p.xz,s);
    color+=float3(.13,.24,.15)*roots.x*.08+float3(.90,.54,.17)*roots.y*.85;
    return color;
}
float3 gardenPetalMaterial(GardenHit hit,float3 light,float fresnel,float softbox,GardenState s) {
    float radius=length(hit.local.xz);
    float tip=smoothstep(.04,.49,radius);
    float3 base=hit.material>8.5?float3(.40,.27,.46):float3(.57,.37,.35);
    float3 pearl=hit.material>8.5?float3(.80,.73,.88):float3(.93,.84,.70);
    float3 tint=mix(base,pearl,tip*.83+.17);
    float3 color=tint*(light*.61+.31);
    float veins=.5+.5*cos(atan2(hit.local.x,hit.local.z)*54.0+radius*13.0);
    color*=1.0-.022*veins*smoothstep(.1,.4,radius);
    color+=pearl*(fresnel*.13+softbox*.10);
    // Light passes through the cup and warms its centre, without bright outlines or glitter.
    float heart=exp(-radius*radius*24.0);
    color+=float3(.27,.14,.045)*heart*(.22+gardenCharge(s)*.75);
    return color;
}
float3 gardenMaterial(GardenHit hit,float3 rd,GardenState s) {
    float3 p=hit.local,n=hit.normal,eye=-rd;
    float key=max(0.0,dot(n,normalize(float3(-.6,.9,.7))));
    float fill=max(0.0,dot(n,normalize(float3(.7,.3,-.6))));
    float fresnel=pow(1.0-max(0.0,dot(n,eye)),3.0);
    float3 reflection=reflect(rd,n);
    float spec=pow(max(0.0,dot(reflection,normalize(float3(-.5,1,.8)))),80.0);
    float strip=pow(max(0.0,dot(reflection,normalize(float3(-.9,.65,.1)))),24.0);
    float3 sunlight=mix(float3(.65,.79,.83),float3(1.0,.89,.69),s.day*.65);
    float3 light=sunlight*(.26+key*.74)*(.82+.18*s.open)+float3(.25,.20,.35)*fill;
    float softbox=pow(max(0.0,dot(reflection,normalize(float3(-.65,.8,1)))),14.0);
    float3 lantern=float3(-.05,1.75,.24)-p;
    float lamp=1.0/(1.0+dot(lantern,lantern)*6.0);
    light+=float3(.8,.45,.17)*lamp*(.48+gardenCharge(s)*1.7);
    float3 col=float3(.09,.25,.19);
    if(hit.material<1.5) {
        col=gardenMossMaterial(p,n,light,s);
    } else if(hit.material<2.5) {
        float2 q=(p.xy-float2(-.22,.83))/float2(.61,.58);
        float r=length(q),a=atan2(q.y,q.x);
        float phase=26.0*sqrt(r+.015)-a;
        float spiral=pow(.5+.5*cos(phase),28.0);
        float ridge=sin(phase)*pow(.5+.5*cos(phase),10.0);
        col=mix(float3(.075,.17,.19),float3(.58,.70,.66),key*.6+fresnel*.3);
        col+=mix(float3(.075,.02,.12),float3(.06,.13,.06),.5+.5*sin(r*9.0))*fresnel;
        col=mix(col,float3(.065,.12,.15),spiral*.24);
        col*=.55+light*.5;
        col+=float3(.64,.75,.68)*ridge*.035+float3(.60,.80,.76)*softbox*.24;
        col+=float3(.75,.91,.85)*(spec*.85+strip*.20+fresnel*.18);
        col+=float3(.48,.26,.075)*exp(-5.0*length(q-float2(0,.6)));
    } else if(hit.material<3.5) {
        col=float3(.11,.24,.23)*light+float3(.40,.65,.57)*fresnel*.65;
        col+=float3(.45,.68,.59)*softbox*.18;
        col+=float3(.55,.84,.80)*(spec*.45+strip*.12);
    } else if(hit.material<4.5) {
        col=gardenSky(reflection,s)*.8+float3(.2,.39,.39)*fresnel+float3(.8,.91,.80)*spec*.75;
    } else if(hit.material<5.5) {
        col=float3(.30,.23,.14)*light+float3(.73,.60,.38)*(spec*.5+strip*.2)+float3(.16,.08,.015)*lamp;
    } else if(hit.material<6.5) {
        col=float3(.10,.23,.16)*(light+.14)+float3(.25,.36,.22)*fresnel*.20;
    } else if(hit.material<7.5) {
        col=float3(.91,.65,.32)*(.70+.20*s.battery+gardenCharge(s)*.24);
    } else if(hit.material>9.5) {
        col=float3(.69,.49,.24)*(light*.40+.45)+float3(.22,.15,.06)*gardenCharge(s);
    } else {
        col=gardenPetalMaterial(hit,light,fresnel,softbox,s);
    }
    if(hit.material>=2.0 && hit.material<=5.0) col+=float3(.95,.57,.19)*gardenStemSignal(p,s)*.85;
    return col*(.64+.36*s.open)+float3(.015,.018,.028)*(1.0-s.open);
}
float3 gardenWater(float3 p,float3 rd,GardenState s) {
    float pool=1.0-smoothstep(.80,1.0,length(p.xz/float2(4.7,2.8)));
    float r=length(p.xz-float2(.7,.4));
    float wave=sin(r*17.0-s.time*1.8)*exp(-r*.7);
    float3 n=normalize(float3(.009*cos(p.x*5.0+s.time*.47),1,.012*sin(p.z*7.0+s.time*.51)+s.wind*.025*wave));
    float3 reflection=gardenSky(reflect(rd,n),s);
    float caustic=pow(.5+.5*sin(p.x*9.0+sin(p.z*7.0+s.time*.32)+s.time*.24),12.0);
    float3 color=mix(float3(.009,.025,.032),reflection*.63,pool);
    color+=float3(.03,.11,.08)*caustic*pool*.2;
    float2 roots=gardenRootSignal(p.xz,s);
    float current=.65+.18*s.activity*sin(p.x*4.0-s.time*(.5+s.activity));
    color+=float3(.08,.32,.25)*roots.x*current*(.10+.7*s.battery)*pool*.65;
    color+=float3(.95,.56,.18)*roots.y*pool*.85;
    if(s.charge>=0.0 && s.charge<2.8) {
        float radius=length(p.xz-float2(-3.6,.61));
        float ripple=exp(-pow((radius-s.charge*.50)*28.0,2.0));
        color+=float3(.34,.48,.36)*ripple*pool*(1.0-smoothstep(.4,2.8,s.charge))*.48;
    }
    // Broad reflected greenhouse lantern and plant light streaks, distorted by the water normal.
    float2 q=(p.xz-float2(-.1,-.1))/float2(.55,1.8);
    float lantern=exp(-dot(q,q)*2.0)*(.80+.20*sin(p.z*24.0+n.z*30.0));
    color+=float3(.24,.14,.055)*lantern*pool*(1.0+gardenCharge(s)*2.5);
    float2 warmPool=(p.xz-float2(-.1,.35))/float2(2.4,1.8);
    color+=float3(.13,.082,.028)*exp(-dot(warmPool,warmPool))*pool*gardenCharge(s);
    color+=float3(.055,.16,.15)*max(0.0,wave)*(.10+s.wind)*pool*.25;
    return color;
}
