// Generated fan artwork with the publisher's original logo in the emblem pass.
fragment float4 gameCyberpunkFragment(WallpaperVertex in [[stage_in]], constant WallpaperUniforms &u [[buffer(0)]],
                         texture2d<float> art [[texture(0)]]) {
    float2 uv = in.uv;
    float3 color = gameArtwork(uv, u, art);
    color += float3(.25, .75, 1) * gameRain(uv, u, 190, 2.2);
    float neon = .5 + .5 * sin(u.time * .75 + uv.y * 7);
    float reflection = pow(max(0.0, sin(uv.x * 34 + sin(uv.y * 28 + u.time))), 14.0) * smoothstep(.67, 1., uv.y);
    color += mix(float3(.02, .30, .42), float3(.40, .015, .23), neon) * reflection * .10;
    color += gameMotes(uv, u, float2(.018, -.008), float3(.25, .85, 1), .0018, 12);
    float2 c = gameCanvasUV(uv, u);
    for (int i = 0; i < 2; i++) {
        float traffic = i == 0 ? u.channels.x : u.channels.y;
        float lane = exp(-pow((c.y - .93 - float(i) * .014) * 650, 2.0));
        float range = step(.055, c.x) * step(c.x, .43);
        float filled = step(c.x, .055 + .375 * traffic);
        float packet = pow(.5 + .5 * sin(c.x * 140 - u.time * (i == 0 ? 1.0 : -1.0) * (1 + traffic * 12)), 14.0);
        color += (i == 0 ? float3(.05, .9, 1) : float3(1, .14, .54)) * lane * range * (.12 + filled * .5 + packet * traffic);
    }
    return float4(saturate(color), 1);
}
