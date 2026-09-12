float3 auroraLocal(float3 p, float spin) {
    p.xy=rotate2(p.xy,-.25);
    p.yz=rotate2(p.yz,-.92);
    p.xz=rotate2(p.xz,spin);
    return p;
}
float2 earthUV(float3 p) {
    p=normalize(p);
    return float2(atan2(p.z,p.x)/(2*M_PI_F)+.5, .5-asin(clamp(p.y,-1.,1.))/M_PI_F);
}
float ovalValue(texture2d<float> grid, float3 p) {
    constexpr sampler s(filter::linear, s_address::repeat, t_address::clamp_to_edge);
    float2 uv=earthUV(p);
    // Earth map starts at -180 degrees; NOAA starts at 0. South is row zero.
    float longitude=fract(uv.x+.5);
    float latitude=(1-uv.y)*180.;
    return grid.sample(s,float2(longitude+.5/360.,(latitude+.5)/181.)).r;
}
fragment float4 auroraObservatoryFragment(WallpaperVertex in [[stage_in]], constant WallpaperUniforms &u [[buffer(0)]],
    texture2d<float> earth [[texture(0)]], texture2d<float> grid [[texture(1)]]) {
    constexpr sampler s(filter::linear, s_address::repeat, t_address::clamp_to_edge);
    float scale=min(u.size.x/1600.,u.size.y/1000.);
    float2 canvas=(in.uv*u.size-u.size*.5)/(float2(1600,1000)*scale)+.5;
    float2 q=(canvas-float2(.725,.50))*float2(1.6,1);
    float radius=.34;
    float r=length(q), edge=max(fwidth(r),.0004);
    float spin=.7+u.time*.016*(.75+u.energy*.5);
    float3 light=normalize(float3(-.7,.65,1.1));
    float3 color=float3(.018,.035,.073);
    float glow=exp(-length(q)*3.4);
    color+=float3(.015,.05,.08)*glow;
    // Stable stars; no flickering random field per frame.
    float2 cell=floor(in.uv*u.size/3.);
    float star=step(.9987,hash21(cell));
    float2 local=fract(in.uv*u.size/3.)-.5;
    color+=float3(.52,.68,.84)*star*exp(-dot(local,local)*14.)*.55;
    float halo=exp(-max(0.,r-radius)*90.)*smoothstep(radius-edge,radius+edge,r);
    color+=float3(.12,.34,.60)*halo*.60;
    if(r < radius+edge) {
        float3 normal=normalize(float3(float2(q.x,-q.y)/radius,sqrt(max(0.,1-dot(q,q)/(radius*radius)))));
        float3 model=auroraLocal(normal,spin);
        float3 albedo=earth.sample(s,earthUV(model)).rgb;
        float sun=max(0.,dot(normal,light));
        float limb=pow(1-normal.z,2.8);
        float3 surface=albedo*(.25+sun*.95)+float3(.045,.12,.23)*limb*.65;
        float ocean=1-smoothstep(.05,.22,albedo.r);
        surface+=float3(.09,.21,.30)*pow(max(0.,dot(reflect(-light,normal),float3(0,0,1))),28.)*ocean;
        float oval=ovalValue(grid,model);
        surface+=float3(.22,1,.66)*oval*.8;
        color=mix(color,surface,1-smoothstep(radius-edge,radius+edge,r));
    }
    // Layered thin atmospheric shells create real depth and Earth occludes the far side.
    if(r < radius*1.18 && grid.get_width()>1) {
        float3 emission=0;
        for(int i=0;i<14;i++) {
            float h=(float(i)+.5)/14.;
            float shell=radius*(1.008+h*.16);
            if(r>=shell) continue;
            float z=sqrt(max(0.,shell*shell-r*r));
            float3 p=auroraLocal(float3(q.x,-q.y,z)/shell,spin);
            float oval=ovalValue(grid,p);
            float longitude=atan2(p.z,p.x);
            float filament=.65+.35*sin(longitude*110.+sin(longitude*17.+u.time*.35)*2.-h*3.+u.time*.6);
            float density=pow(oval,.65)*filament*pow(1-h,1.7);
            float3 tint=mix(float3(.12,1,.55),float3(.62,.29,1),smoothstep(.12,.85,h));
            emission+=tint*density*(.22+u.energy*.08);
        }
        color+=emission;
    }
    // Slight perimeter falloff keeps desktop text legible without a hard vignette.
    color*=1-.16*smoothstep(.6,1.6,length((in.uv-.5)*float2(1.2,1)));
    return float4(color,1);
}
