// Official artwork remains a rigid image plane; only camera and atmosphere move.
fragment float4 viceCountdownFragment(WallpaperVertex in [[stage_in]], constant WallpaperUniforms &u [[buffer(0)]],
                                      texture2d<float> art [[texture(0)]]) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float2 uv=in.uv;
    float aspect=u.size.x/u.size.y;
    float imageAspect=float(art.get_width())/float(art.get_height());
    // Fit the full artwork to the shared composition canvas, extend the sky off-canvas.
    float scale=min(u.size.x/1600.,u.size.y/1000.);
    float2 canvas=(uv*u.size-u.size*.5)/(float2(1600,1000)*scale)+.5;
    float2 photo=(canvas-.5)*float2(1.,imageAspect/1.6);
    photo=photo*.988+.5+float2(sin(u.time*.055),cos(u.time*.043))*.004;
    float3 sampled=art.sample(s,photo).rgb;
    float3 sky=mix(float3(.12,.07,.20),float3(.39,.24,.46),smoothstep(-.5,1.5,canvas.y));
    float bounds=smoothstep(-.06,.02,canvas.x)*(1-smoothstep(.98,1.08,canvas.x))
                 *smoothstep(-.025,.025,photo.y)*(1-smoothstep(.975,1.025,photo.y));
    float3 color=mix(sky,sampled,bounds);
    // A soft left exposure flag reserves readable space, without flattening the art.
    float flag=1-smoothstep(.24,.57,canvas.x);
    color=mix(color,float3(.10,.045,.17),flag*.78);
    color*=1-.21*smoothstep(.68,1.12,canvas.y);
    float haze=exp(-pow((canvas.y-.84)*5,2.))* (.5+.5*sin(canvas.x*6+u.time*.09));
    color+=float3(.35,.12,.26)*haze*.065;
    // Slow foreground embers. Deliberately small and away from faces and lettering.
    for(int i=0;i<18;i++) {
        float fi=float(i), seed=hash21(float2(fi,9));
        float2 p=float2(fract(seed*8.7+u.time*.002*(.5+seed)),fract(seed*4.1-u.time*.004));
        float2 d=(uv-p)*float2(aspect,1);
        float light=exp(-dot(d,d)/(0.000004+seed*.000008));
        color+=float3(1,.55,.35)*light*.12*(.65+u.energy*.35);
    }
    return float4(color,1);
}
