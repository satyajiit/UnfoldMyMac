// Generated fan artwork with the publisher's original logo in the emblem pass.
fragment float4 gameHollowKnightFragment(WallpaperVertex in [[stage_in]], constant WallpaperUniforms &u [[buffer(0)]],
                         texture2d<float> art [[texture(0)]]) {
    float2 uv = in.uv;
    float3 color = gameArtwork(uv, u, art);
    color += gameMotes(uv, u, float2(-.003, -.006), float3(.43, 1, .78), .005, 32);
    float breath = .5 + .5 * sin(u.time * .38);
    float glow = exp(-dot((uv - float2(.72, .55)) * float2(3, 2), (uv - float2(.72, .55)) * float2(3, 2)));
    color += float3(.045, .18, .13) * glow * (.10 + breath * .10);
    float pool = smoothstep(.80, 1., uv.y) * sin(uv.y * 130 + sin(uv.x * 8) - u.time * 1.3);
    color += float3(.015, .038, .045) * pool;
    float2 c = gameCanvasUV(uv, u);
    for (int i = 0; i < 5; i++) {
        float2 d = (c - float2(.063 + float(i) * .024, .926)) * float2(1.6, 1);
        float glow = exp(-dot(d, d) / .000045);
        float filled = step((float(i) + .5) / 5, u.channels.x);
        color += float3(.5, 1, .84) * glow * (.14 + filled * .72);
    }
    color += float3(.06, .22, .18) * glow * u.channels.y * (.5 + breath * .5);
    return float4(saturate(color), 1);
}
