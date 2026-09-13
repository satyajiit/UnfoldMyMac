// Generated fan artwork with the publisher's original logo in the emblem pass.
fragment float4 gameWolverineFragment(WallpaperVertex in [[stage_in]], constant WallpaperUniforms &u [[buffer(0)]],
                         texture2d<float> art [[texture(0)]]) {
    float2 uv = in.uv;
    float3 color = gameArtwork(uv, u, art);
    // Warm mist supports the original dark title without recolouring its pixels.
    float2 canvas = (uv * u.size - u.size * .5) / (float2(1600, 1000) * min(u.size.x / 1600., u.size.y / 1000.)) + .5;
    float glow = exp(-pow((canvas.x - .20) * 4.5, 4.0) - pow((canvas.y - .20) * 5.0, 4.0));
    color = mix(color, float3(.90, .68, .30), glow * .91);
    color += float3(.5, .66, .8) * gameRain(uv, u, 150, 1.5);
    float mist = exp(-pow((uv.y - .74 - sin(uv.x * 6 + u.time * .1) * .025) * 11, 2.0));
    color += float3(.22, .30, .37) * mist * .10;
    // Three recovery slashes fill from the bottom with actual battery reserve.
    for (int i = 0; i < 3; i++) {
        float2 d = (canvas - float2(.365 + float(i) * .021, .618)) * float2(1.6, 1);
        float slash = exp(-pow((d.x + d.y * .25) * 600, 2.0)) * (1.0 - smoothstep(.04, .045, abs(d.y)));
        float fill = step(.5 - d.y / .08, u.channels.x);
        float pulse = .85 + .15 * sin(u.time * 2) * u.channels.y;
        color += mix(float3(.95, .64, .16), float3(1, .16, .07), u.channels.z) * slash * (.12 + fill * .8) * pulse;
    }
    return float4(saturate(color), 1);
}
