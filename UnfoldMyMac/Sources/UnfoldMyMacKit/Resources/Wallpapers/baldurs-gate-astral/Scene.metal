// Generated fan artwork with the publisher's original logo in the emblem pass.
fragment float4 gameBaldursGateFragment(WallpaperVertex in [[stage_in]], constant WallpaperUniforms &u [[buffer(0)]],
                         texture2d<float> art [[texture(0)]]) {
    float2 uv = in.uv;
    float3 color = gameArtwork(uv, u, art);
    color += gameMotes(uv, u, float2(.003, -.01), float3(.65, .45, 1), .0038, 28);
    float2 p = (uv - float2(.70, .30)) * float2(u.size.x / u.size.y, 1);
    float r = length(p), a = atan2(p.y, p.x);
    float ring = exp(-pow((r - .16) * 310, 2.0));
    float runes = pow(.5 + .5 * cos(a * 24 - u.time * .24), 12.0);
    color += float3(.40, .23, .85) * ring * runes * .20;
    color += float3(.065, .025, .16) * exp(-r * 7) * (.5 + .5 * sin(u.time * .45));
    float sector = fract(a / 6.2831853 + 1.0);
    float filled = step(sector, u.channels.x);
    float3 inventory = mix(float3(.55, .36, 1), float3(1, .48, .12), step(.9, u.channels.x));
    color += inventory * ring * pow(.5 + .5 * cos(a * 12), 8.0) * (.15 + filled * .85);
    float2 c = gameCanvasUV(uv, u);
    for (int i = 0; i < 12; i++) {
        float angle = float(i) / 12 * 6.2831853;
        float2 rune = float2(.405, .62) + float2(sin(angle) / 1.6, -cos(angle)) * .044;
        float2 d = (c - rune) * float2(1.6, 1);
        float diamond = 1.0 - smoothstep(.003, .005, abs(d.x) + abs(d.y));
        color += inventory * diamond * (.12 + .88 * step((float(i) + .5) / 12, u.channels.x));
    }
    return float4(saturate(color), 1);
}
