// Generated fan artwork with the publisher's original logo in the emblem pass.
fragment float4 gameForzaFragment(WallpaperVertex in [[stage_in]], constant WallpaperUniforms &u [[buffer(0)]],
                         texture2d<float> art [[texture(0)]]) {
    float2 uv = in.uv;
    float3 color = gameArtwork(uv, u, art);
    color += gameMotes(uv, u, float2(-.027, -.004), float3(1, .73, .51), .0028, 22);
    float cloud = exp(-pow((uv.y - .32 - sin(uv.x * 4 - u.time * (.025 + u.channels.z * .1)) * .018) * 22, 2.0));
    color += float3(.40, .23, .27) * cloud * .065;
    float glint = pow(max(0.0, sin(u.time * .32)), 12.0);
    color += float3(.30, .22, .13) * glint * exp(-dot((uv - float2(.78, .67)) * 20, (uv - float2(.78, .67)) * 20));
    color *= 1.0 - (1.0 - u.channels.y) * .35 * u.channels.w;
    color += float3(.48, .68, .9) * gameRain(uv, u, 180, 2.0) * u.channels.x * 3;
    color += float3(.14, .18, .24) * cloud * u.channels.z * .15;
    return float4(saturate(color), 1);
}
