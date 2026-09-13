// Generated fan artwork with the publisher's original logo in the emblem pass.
fragment float4 gameEldenRingFragment(WallpaperVertex in [[stage_in]], constant WallpaperUniforms &u [[buffer(0)]],
                         texture2d<float> art [[texture(0)]]) {
    float2 uv = in.uv;
    float3 color = gameArtwork(uv, u, art);
    color += gameMotes(uv, u, float2(.003, -.009), float3(1, .77, .32), .0035, 30);
    float2 p = (uv - float2(.71, .70)) * float2(u.size.x / u.size.y, 1);
    float ring = exp(-pow((length(p) - .085 - sin(u.time * .4) * .006) * 320, 2.0));
    color += float3(.75, .49, .12) * ring * .09;
    color += float3(.18, .14, .045) * exp(-pow((uv.x - .68) * 3, 2.0)) * (.035 + .025 * sin(u.time * .33));
    float3 grace = mix(float3(1, .72, .24), float3(.36, .78, 1), u.channels.y);
    color += grace * gameArc(p, .095, u.channels.x) * .85;
    color += grace * exp(-length(p) * 22) * u.channels.y * .15;
    return float4(saturate(color), 1);
}
