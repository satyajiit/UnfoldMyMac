// Generated fan artwork with the publisher's original logo in the emblem pass.
fragment float4 gameGhostTsushimaFragment(WallpaperVertex in [[stage_in]], constant WallpaperUniforms &u [[buffer(0)]],
                         texture2d<float> art [[texture(0)]]) {
    float2 uv = in.uv;
    float3 color = gameArtwork(uv, u, art);
    color += gameWindLeaves(uv, u);
    float mist = exp(-pow((uv.y - .67 - sin(uv.x * 6 + u.time * .12) * .02) * 14, 2.0));
    color += float3(.14, .22, .29) * mist * .11;
    color += gameMotes(uv, u, float2(.025, -.004), float3(.65, .78, .91), .0015, 12);
    float2 c = gameCanvasUV(uv, u);
    float2 compass = (c - float2(.40, .62)) * float2(1.6, 1);
    float bearing = u.channels.y * 6.2831853;
    float2 needle = rotate2(compass, -bearing);
    float arrow = (1.0 - smoothstep(.003, .004, abs(needle.x))) * step(-.034, needle.y) * step(needle.y, .018);
    float tip = (1.0 - smoothstep(.010, .012, abs(needle.x) + abs(needle.y + .027)));
    color += float3(.92, .88, .76) * (gameArc(compass, .044, 1) * .45 + arrow * .65 + tip) * u.channels.z;
    return float4(saturate(color), 1);
}
