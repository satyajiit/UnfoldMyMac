fragment float4 daydreamFragment(WallpaperVertex in [[stage_in]],constant WallpaperUniforms &u [[buffer(0)]],texture2d<float> art [[texture(0)]]) {
    constexpr sampler sampleArt(filter::linear,address::clamp_to_edge);
    float2 uv=in.uv;
    float aspect=u.size.x/u.size.y, imageAspect=float(art.get_width())/float(art.get_height());
    float2 crop=float2(min(1.0,aspect/imageAspect),min(1.0,imageAspect/aspect));
    float2 drift=float2(sin(u.time*.07),cos(u.time*.09))*.009;
    float2 warped=(uv-.5)*crop*.96+.5+drift;
    warped+=float2(sin(uv.y*9+u.time*.35),cos(uv.x*8+u.time*.25))*.003*(.3+u.energy);
    float3 color=art.sample(sampleArt,warped).rgb;
    color=mix(color,u.background.rgb,.28+.3*(1-smoothstep(.15,.8,uv.x)));
    // Glass lens floats over the image, refracting it instead of zooming the entire wallpaper.
    float2 center=float2(.73+.02*sin(u.time*.18),.46+.025*cos(u.time*.2));
    float2 d=(uv-center)*float2(aspect,1);float radius=.185;
    float len=length(d);float mask=1-smoothstep(radius-.002,radius+.002,len);
    float z=sqrt(max(0.0,radius*radius-dot(d,d)))/radius;
    float2 refracted=warped-d*.11*z;
    float3 glass=art.sample(sampleArt,refracted).rgb*.85;
    glass+=pow(1-z,3.0)*float3(.5,.8,1)*.75;
    glass+=pow(max(0.0,dot(normalize(float3(d/radius,z)),normalize(float3(-.6,-.7,1)))),60.0)*.8;
    color=mix(color,glass,mask);
    for(int i=0;i<18;i++){
        float fi=float(i), seed=hash21(float2(fi,2));
        float2 point=float2(fract(seed*12.3+u.time*.004),fract(seed*7.9-u.time*(.012+seed*.008)));
        float2 delta=(uv-point)*float2(aspect,1);
        color+=u.accent.rgb*exp(-dot(delta,delta)*18000)*(.25+.5*seed);
    }
    return float4(color,1);
}
