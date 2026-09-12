// A tilted volumetric accretion disk, opaque event horizon, lensing and relativistic jets.
float horizonNoise(float2 p) {
    float2 cell = floor(p), f = fract(p); f = f * f * (3 - 2 * f);
    return mix(mix(hash21(cell), hash21(cell + float2(1,0)), f.x),
               mix(hash21(cell + float2(0,1)), hash21(cell + 1), f.x), f.y);
}
float3 horizonSpace(float2 p, float time) {
    float3 color = float3(.004, .005, .012);
    for (int i = 0; i < 3; i++) {
        float layer = float(i), scale = 95 + layer * 64;
        float2 space = p * scale + float2(time * .10 * (layer + 1), 0);
        float2 cell = floor(space), offset = fract(space) - .5;
        float seed = hash21(cell + layer * 29);
        float star = exp(-dot(offset, offset) * (80 + layer * 50)) * step(.977, seed);
        color += mix(float3(.45,.58,.9), float3(1,.79,.55), seed) * star * (.25 + .25 * sin(seed * 65 + time * .5));
    }
    float mist = horizonNoise(p * 5) * horizonNoise(p * 13 + .5);
    color += float3(.028, .014, .045) * mist;
    return color;
}
float3 horizonDisk(float3 q, float time, float energy, float signal, float footprint) {
    float radius = length(q.xz), angle = atan2(q.z, q.x);
    float radial = smoothstep(.57, .70, radius) * (1 - smoothstep(1.42, 2.30, radius));
    float shear = angle * 3.0 + time * (.65 + .26 / max(radius, .6));
    // Filter radial detail at the projected pixel footprint, especially at grazing angles.
    float turbulence = horizonNoise(float2(radius * 16 - time * .6, sin(shear) * 3));
    float bands = .62 + .23 * sin(radius * 42 + turbulence * 5) * exp(-pow(footprint * 42, 2.0))
                       + .15 * sin(radius * 76 - shear * 3) * exp(-pow(footprint * 76, 2.0));
    float filaments = pow(.5 + .5 * sin(shear * 4 + radius * 15 + turbulence * 3), 3.0)
        * exp(-pow(footprint * 35, 2.0));
    float heat = exp(-(radius - .67) * 1.45);
    float3 amber = mix(float3(.65,.075,.012), float3(1,.58,.15), heat);
    amber = mix(amber, float3(.85,.91,1), pow(heat, 5.0) * .68);
    float doppler = .48 + .52 * smoothstep(-1.6, 1.6, q.x);
    return amber * radial * (bands + filaments * (.4 + energy + signal)) * doppler;
}
fragment float4 grokHorizonFragment(WallpaperVertex in [[stage_in]], constant WallpaperUniforms &u [[buffer(0)]]) {
    float2 canvas = (in.uv - .5) * u.size / min(u.size.y, u.size.x / 1.6);
    float2 p = (canvas - float2(.34, -.015)) * 3.05;
    p = rotate2(p, -.24);
    float pixel = 3.05 / min(u.size.y, u.size.x / 1.6);
    float3 ro = float3(0, 0, 5.5), rd = normalize(float3(p.x, -p.y, -2.8));
    float b = dot(ro, rd), discriminant = b * b - dot(ro, ro) + .56 * .56;
    float horizonT = discriminant > 0 ? -b - sqrt(discriminant) : 100;
    // Weak-field bending around the silhouette draws a dense crown of background stars.
    float r = length(p), lens = .14 / max(r * r, .10);
    float3 color = horizonSpace(canvas + normalize(p + .0001) * lens * .12, u.time);
    color += float3(.15,.033,.006) * exp(-r * r * 2.5) * .35;
    float3 diskOrigin = ro, diskRay = rd;
    diskOrigin.yz = rotate2(diskOrigin.yz, .27 + sin(u.time * .12) * .025);
    diskRay.yz = rotate2(diskRay.yz, .27 + sin(u.time * .12) * .025);
    // Finite depth slices provide volume/parallax while keeping the 60 Hz workload bounded.
    float3 accretion = 0;
    for (int i = 0; i < 17; i++) {
        float height = (float(i) - 8) * .007;
        float t = (height - diskOrigin.y) / (abs(diskRay.y) > .001 ? diskRay.y : .001);
        if (t > 0 && t < horizonT) {
            float3 point = diskOrigin + diskRay * t;
            float density = exp(-height * height * 600);
            float footprint = pixel * max(1.0, t) / (2.8 * max(abs(diskRay.y), .05));
            float visibility = smoothstep(0.0, pixel * max(t, 1.0) * 2, horizonT - t);
            accretion += horizonDisk(point, u.time, u.energy, u.channels.y, footprint) * density * visibility * .127;
        }
    }
    // The distant disk is lensed above and below the horizon into narrow photon arcs.
    float ringRadius = .293;
    float photonWidth = max(.008, pixel * 1.2);
    float photon = exp(-pow((r - ringRadius) / photonWidth, 2.0));
    float halo = exp(-abs(r - ringRadius) * 23) * .17;
    float azimuth = atan2(p.y, p.x);
    float streak = .7 + .3 * sin(azimuth * 19 + u.time * 1.4 + sin(azimuth * 5) * 3);
    float warpedRadius = .68 + max(0.0, r - .30) * 18.0;
    float3 lensedDisk = horizonDisk(float3(cos(azimuth) * warpedRadius, 0, sin(azimuth) * warpedRadius),
        u.time, u.energy, u.channels.y, pixel * 18);
    float arc = smoothstep(.286,.304,r) * (1 - smoothstep(.35,.405,r));
    float impact = sqrt(max(0.0, dot(ro,ro) - b*b));
    color *= mix(.018, 1.0, smoothstep(.56 - pixel, .56 + pixel, impact));
    color += float3(1,.69,.34) * (photon * .9 * streak + halo * smoothstep(.282,.298,r));
    color += lensedDisk * arc * 1.3;
    color += accretion * (1.45 + u.energy * .65);
    // Faint bipolar jets extend from the poles, behind the horizon.
    float jetWidth = .012 + abs(p.y) * .065;
    float jet = exp(-pow(p.x / jetWidth, 2.0)) * exp(-abs(p.y) * 2.1) * smoothstep(.30,.6,abs(p.y));
    jet *= .60 + .4 * sin(p.y * 34 - u.time * 2.2);
    color += float3(.24,.35,.95) * jet * (.40 + u.energy * .55);
    // Orbiting embers have actual perspective and horizon occlusion.
    for (int i = 0; i < 34; i++) {
        float index = float(i), a = index * 2.399 + u.time * .22;
        float orbit = 1.45 + fract(index * .618) * 1.1;
        float3 ember = float3(cos(a) * orbit, sin(index * 3.1) * .10, sin(a) * orbit);
        ember.yz = rotate2(ember.yz, -.27);
        float along = dot(ember - ro, rd);
        float d = length(ro + rd * along - ember);
        if (along < horizonT) color += float3(1,.42,.11) * exp(-d*d*1900) * (.30 + .8*u.energy);
    }
    color *= mix(.34, 1.0, smoothstep(-.25,.05,canvas.x));
    color = 1 - exp(-color * 1.35);
    color += (hash21(in.uv*u.size) - .5) * .004;
    return float4(color, 1);
}
