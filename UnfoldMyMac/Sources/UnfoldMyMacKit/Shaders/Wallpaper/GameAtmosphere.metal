// Shared image placement and bounded atmosphere primitives for the game collection.
// Logos are composited afterwards by the original, untinted emblem pass.
float2 gameCanvasUV(float2 uv, constant WallpaperUniforms &u) {
    return (uv * u.size - u.size * .5) / (float2(1600, 1000) * min(u.size.x / 1600., u.size.y / 1000.)) + .5;
}

float gameArc(float2 p, float radius, float progress) {
    float angle = fract(atan2(p.x, -p.y) / 6.2831853 + 1.0);
    return exp(-pow((length(p) - radius) * 550, 2.0)) * (.13 + .87 * step(angle, saturate(progress)));
}

float3 gameArtwork(float2 uv, constant WallpaperUniforms &u, texture2d<float> art) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float viewportAspect = u.size.x / u.size.y;
    float imageAspect = float(art.get_width()) / float(art.get_height());
    float2 fit = float2(min(1.0, viewportAspect / imageAspect), min(1.0, imageAspect / viewportAspect));
    float motion = 1.0 - step(.5, u.environment.z);
    float2 drift = float2(sin(u.time * .07), cos(u.time * .053)) * .005;
    float2 photo = (uv - .5) * fit * .97 + .5 + (drift + u.motion.xy * .008) * motion;
    float3 color = art.sample(s, photo).rgb;
    float lid = saturate(u.interaction.x);
    color *= .82 + .18 * lid;
    float vignette = smoothstep(.28, .85, length((uv - .5) * float2(1, .8)));
    color *= 1.0 - vignette * .17;
    // A restrained exposure flag behind the official mark, with no baked-in text.
    color *= 1.0 - (1.0 - smoothstep(.03, .42, uv.x)) * .20;
    float2 canvas = gameCanvasUV(uv, u);
    float reading = (1.0 - smoothstep(.34, .64, canvas.x)) * smoothstep(.42, .57, canvas.y);
    color *= 1.0 - reading * .76;
    return color;
}

// Wind direction is meteorological (where it comes from); leaf travel points away from it.
float3 gameWindLeaves(float2 uv, constant WallpaperUniforms &u) {
    float bearing = u.channels.y * 6.2831853;
    float2 travel = float2(-sin(bearing), cos(bearing)) * u.channels.x * .075;
    float3 light = 0;
    for (int i = 0; i < 24; i++) {
        float seed = hash21(float2(float(i), 83));
        float2 p = fract(float2(seed * 11.1, seed * 3.7) + (travel + float2(0, .005)) * u.time * (.5 + seed));
        float2 d = (uv - p) * float2(u.size.x / u.size.y, 1);
        d = rotate2(d, bearing + sin(u.time * .5 + seed * 13));
        float size = .003 + seed * .004;
        float leaf = 1.0 - smoothstep(.8, 1.2, abs(d.x) / size + abs(d.y) / (size * .42));
        light += float3(.9, .13, .065) * leaf * (.35 + seed * .5) * u.channels.z;
    }
    return light;
}

float3 gameMotes(float2 uv, constant WallpaperUniforms &u, float2 drift, float3 tint, float radius, int count) {
    float3 light = 0;
    float aspect = u.size.x / u.size.y;
    for (int i = 0; i < count; i++) {
        float seed = hash21(float2(float(i), 17));
        float2 p = fract(float2(seed * 7.3, seed * 19.1) + drift * u.time * (.4 + seed));
        p.x += sin(u.time * .22 + seed * 30) * .018;
        float2 delta = (uv - p) * float2(aspect, 1);
        float glow = exp(-dot(delta, delta) / (radius * radius * (.4 + seed)));
        light += tint * glow * (.14 + .16 * u.energy) * (.6 + .4 * sin(seed * 12 + u.time));
    }
    return light;
}

float gameRain(float2 uv, constant WallpaperUniforms &u, float density, float speed) {
    float2 grid = float2((uv.x + uv.y * .13) * density, uv.y * 12 - u.time * speed);
    float2 cell = floor(grid);
    float2 f = fract(grid);
    float seed = hash21(float2(cell.x, 31));
    float streak = exp(-pow((f.x - seed) * 85, 2.0));
    float tail = smoothstep(.1, .75, fract(f.y + seed));
    return streak * tail * step(.45, seed) * (.035 + .04 * u.energy);
}

float3 gameLeaves(float2 uv, constant WallpaperUniforms &u, float3 tint, float speed) {
    float3 color = 0;
    for (int i = 0; i < 16; i++) {
        float seed = hash21(float2(float(i), 63));
        float2 p = fract(float2(seed * 11.1, seed * 3.7) + float2(.024, .018) * u.time * speed * (.5 + seed));
        p.y += sin(u.time * .4 + seed * 19) * .028;
        float2 delta = (uv - p) * float2(u.size.x / u.size.y, 1);
        delta = rotate2(delta, sin(u.time * .7 + seed * 13) * 2);
        float size = .003 + seed * .004;
        float shape = abs(delta.x) / size + abs(delta.y) / (size * .42);
        float edge = 1.0 - smoothstep(.8, 1.2, shape);
        color += tint * edge * (.4 + seed * .4);
    }
    return color;
}
