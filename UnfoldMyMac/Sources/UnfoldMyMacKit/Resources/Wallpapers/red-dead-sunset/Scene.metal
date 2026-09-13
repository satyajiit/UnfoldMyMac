// Generated fan artwork with the publisher's original logo in the emblem pass.
fragment float4 gameRedDeadFragment(WallpaperVertex in [[stage_in]], constant WallpaperUniforms &u [[buffer(0)]],
                         texture2d<float> art [[texture(0)]]) {
    float2 uv = in.uv;
    float3 color = gameArtwork(uv, u, art);
    color += gameMotes(uv, u, float2(.018, -.003), float3(1, .56, .28), .0025, 28);
    float haze = exp(-pow((uv.y - .55 - sin(uv.x * 3 - u.time * .06) * .012) * 17, 2.0));
    color += float3(.42, .12, .025) * haze * .08;
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float2 bird = float2(fract(.48 + fi * .036 + u.time * .003), .32 + fi * .012);
        float2 d = (uv - bird) * float2(u.size.x / u.size.y, 1);
        float wing = abs(d.y - abs(d.x) * (.35 + .2 * sin(u.time * 2.4 + fi)));
        float silhouette = (1.0 - smoothstep(.0005, .0012, wing)) * (1.0 - smoothstep(.004, .007, abs(d.x)));
        color *= 1.0 - silhouette * .6;
    }
    color *= 1.0 - (1.0 - u.channels.y) * .38 * u.channels.z;
    float2 solar = float2(.50 + .40 * u.channels.x, .51 - sin(u.channels.x * 3.14159265) * .22);
    float2 delta = (uv - solar) * float2(u.size.x / u.size.y, 1);
    color += float3(1, .62, .24) * exp(-dot(delta, delta) / .00015) * u.channels.y * u.channels.z;
    float arcY = .51 - sin(clamp((uv.x - .50) / .40, 0.0, 1.0) * 3.14159265) * .22;
    color += float3(.40, .23, .08) * exp(-pow((uv.y - arcY) * 650, 2.0)) * step(.50, uv.x) * step(uv.x, .90) * u.channels.z;
    return float4(saturate(color), 1);
}
