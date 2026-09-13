// Generated fan artwork with the publisher's original logo in the emblem pass.
fragment float4 gameWukongFragment(WallpaperVertex in [[stage_in]], constant WallpaperUniforms &u [[buffer(0)]],
                         texture2d<float> art [[texture(0)]]) {
    float2 uv = in.uv;
    float3 color = gameArtwork(uv, u, art);
    color += gameLeaves(uv, u, float3(.73, .36, .09), .65);
    color += gameMotes(uv, u, float2(.006, -.004), float3(1, .81, .43), .002, 12);
    float cloud = exp(-pow((uv.y - .64 - sin(uv.x * 5 + u.time * .065) * .025) * 10, 2.0));
    color += float3(.35, .30, .22) * cloud * .065;
    // Community constellation: logarithmic crowd scale keeps quiet and busy days legible.
    for (int i = 0; i < 18; i++) {
        float fi = float(i);
        float2 p = float2(.54 + fi * .022, .40 - sin(fi * .19) * .09);
        float2 d = (uv - p) * float2(u.size.x / u.size.y, 1);
        float lit = step((fi + .5) / 18, u.channels.x);
        color += float3(1, .63, .20) * exp(-dot(d, d) / .00003) * (.06 + lit * .8);
    }
    return float4(saturate(color), 1);
}
