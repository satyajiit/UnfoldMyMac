// Studio lighting keeps lacquer, exposed carbon, rubber and wheel metal distinct.
float3 raceLight(float3 n,float3 view,float3 base,float roughness) {
    float3 key=normalize(float3(-.6,1,.65)), fill=normalize(float3(1,.3,-.5));
    float diffuse=max(dot(n,key),0.0), rim=max(dot(n,fill),0.0);
    float3 reflected=reflect(-view,n);
    float softbox=exp(-pow((reflected.y-.63)/(.08+roughness*.35),2.0))
        * exp(-pow((reflected.x+.20)/.85,6.0));
    float highlight=pow(max(dot(n,normalize(key+view)),0.0),mix(125.0,14.0,roughness));
    float fresnel=pow(1-max(dot(n,view),0.0),5.0);
    float3 ambient=mix(float3(.07,.055,.07),float3(.25,.29,.34),smoothstep(-.4,.9,n.y));
    return base*(ambient+diffuse*1.6+rim*.45)
        + float3(1,.94,.87)*(softbox*.55+highlight*.65)*(1-roughness*.82)
        + float3(.39,.48,.61)*fresnel*(.15+.35*(1-roughness));
}
float3 raceMaterial(float3 q,float3 n,float3 view,float material,float time) {
    float3 base=float3(.64,.009,.026); float roughness=.13;
    if(material==1) {
        // A narrow white nose stripe and flowing sidepod shoulder line.
        float stripe=(1-smoothstep(.026,.042,abs(q.x)))*smoothstep(.65,.83,q.z);
        float sideStripe=exp(-pow((q.y-(.42+.045*sin(q.z*2)))*75,2.0))*smoothstep(.28,.48,abs(q.x));
        base=mix(base,float3(.9,.92,.94),max(stripe,sideStripe*.85));
        float airbox=step(.84,q.y)*step(-.52,q.z)*(1-step(-.34,q.z))*(1-smoothstep(.080,.115,abs(q.x)));
        float podInlet=exp(-pow((abs(q.x)-.47)/.135,6.0)-pow((q.y-.40)/.060,6.0))
            * step(.045,q.z)*(1-step(.23,q.z));
        base=mix(base,float3(.007,.011,.016),max(airbox,podInlet));
    }
    if(material==2) { base=float3(.017,.020,.026); roughness=.5; }
    if(material==3) { base=float3(.012,.014,.018); roughness=.91; }
    if(material==4) { base=float3(.32,.36,.42); roughness=.24; }
    if(material==5) { base=float3(.86,.89,.92); roughness=.18; }
    if(material==11) { base=float3(.055,.12,.15); roughness=.05; }
    if(material==12) { base=float3(.94,.71,.075); roughness=.16; }
    float3 color=raceLight(n,view,base,roughness);
    if(material==3 || material==4) {
        float z=abs(q.z-1.27)<abs(q.z+1.30)?1.27:-1.30;
        float2 wheel=q.yz-float2(.345,z);
        float radius=length(wheel), angle=atan2(wheel.x,wheel.y)+time*15;
        float outside=smoothstep(.91,.99,abs(q.x));
        if(material==3) {
            float bead=exp(-pow((radius-.270)*140,2.0));
            float arc=pow(.5+.5*cos(angle*2),6.0);
            color+=float3(.61,.48,.14)*bead*(.35+.65*arc)*outside;
            color*=.90+.10*sin(radius*320);
        } else {
            float spoke=pow(.5+.5*cos(angle*10),18.0);
            float hub=1-smoothstep(.065,.082,radius), lip=smoothstep(.183,.206,radius);
            float metal=max(max(spoke,hub),lip);
            color=mix(float3(.012,.017,.023),color*1.3,metal);
        }
    }
    if(material==2) {
        float weave=sin(q.x*240+q.z*210)*sin(q.z*240-q.x*210);
        color*=.95+.05*weave;
    }
    return color;
}
float3 raceTrack(float3 ground,float distance,float time,float3 backdrop) {
    float speed=time*4.4;
    float edge=smoothstep(1.48,1.49,abs(ground.x))*(1-smoothstep(1.66,1.67,abs(ground.x)));
    float stripe=smoothstep(-.05,.05,sin((ground.z+speed)*3.5));
    float3 kerb=mix(float3(.34,.006,.018),float3(.44,.47,.50),stripe);
    float3 color=mix(float3(.030,.034,.044),kerb,edge);
    color+=float3(.5,.008,.025)*exp(-pow((abs(ground.x)-1.43)*110,2.0));
    float paint=(1-smoothstep(.016,.028,abs(abs(ground.x)-1.23)))
        * smoothstep(.4,.44,fract((ground.z+speed)*.19));
    color+=float3(.10,.12,.15)*paint;
    float shadow=.76*exp(-pow(ground.x/.64,4.0)-pow(ground.z/1.70,4.0));
    float wheelShadow=exp(-pow((abs(ground.x)-.875)*6,2.0)-pow((abs(ground.z)-1.285)*5,2.0));
    color*=1-max(shadow,wheelShadow*.70);
    color+=float3(.10,.002,.005)*exp(-pow((abs(ground.x)-.45)*3,2.0)-ground.z*ground.z*.45);
    return mix(backdrop,color,exp(-distance*.042));
}
