// Generated fan artwork with the publisher's original logo in the emblem pass.
fragment float4 gameDoomFragment(WallpaperVertex in [[stage_in]], constant WallpaperUniforms &u [[buffer(0)]],
                         texture2d<float> art [[texture(0)]]) {
    float2 uv = in.uv;
    float3 color = gameArtwork(uv, u, art);
    color += gameMotes(uv, u, float2(.01, -.032), float3(1, .23, .045), .003, 38);
    float heat = smoothstep(.62, 1., uv.y) * (.5 + .5 * sin(uv.x * 15 + u.time * 1.3));
    color += float3(.22, .035, .005) * heat * (.18 + u.energy * .18);
    float pulse = .5 + .5 * sin(u.time * .6);
    color += float3(.10, .018, 0) * pulse * exp(-pow((uv.y - .65) * 5, 2.0));
    float2 c = gameCanvasUV(uv, u);
    for (int i = 0; i < 3; i++) {
        float2 d = abs(c - float2(.35 + float(i) * .025, .856));
        float cell = (1.0 - smoothstep(.008, .009, d.x)) * (1.0 - smoothstep(.009, .012, d.y));
        color += float3(1, .24, .045) * cell * (.1 + .8 * step((float(i) + .5) / 3, u.channels.x));
    }
    color += float3(.35, .05, 0) * heat * u.channels.x;
    return float4(saturate(color), 1);
}
