// An assembling, open architectural accelerator. No geometry from the first collection.
float foundryBox(float3 p, float3 b, float radius) {
    float3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - radius;
}
float2 foundryMap(float3 p, float time, float energy) {
    p.xz = rotate2(p.xz, -.24 + .09 * sin(time * .21));
    float lane = clamp(round(p.z / .56), -3.0, 3.0);
    float3 q = p - float3(0, 0, lane * .56);
    q.xy = rotate2(q.xy, lane * .21 + sin(time * .38 + lane * .52) * (.09 + energy * .10));
    float assembly = .07 * lane + .10 * sin(time * .65 - lane * .70);
    float breadth = 1.03 + assembly;
    q.y *= 1.0 + assembly * .45;
    float2 distance;
    distance.x = min(foundryBox(float3(q.x, abs(q.y) - 1.13, q.z), float3(breadth, .075, .075), .035),
                     foundryBox(float3(abs(q.x) - breadth, q.y, q.z), float3(.075, 1.13, .075), .035));
    distance.y = 1;
    // Separate narrow emissive strips run along the inner edge of each structural rib.
    float track = min(foundryBox(float3(q.x, abs(q.y) - 1.025, q.z - .02), float3(breadth - .10, .014, .081), .009),
                      foundryBox(float3(abs(q.x) - breadth + .105, q.y, q.z - .02), float3(.014, 1.025, .081), .009));
    if (track < distance.x) distance = float2(track, 2);
    // Offset ceramic chips assemble in staggered rows outside the open chamber.
    float3 chip = q;
    chip.y -= clamp(round(chip.y / .52), -2.0, 2.0) * .52;
    chip.x = abs(chip.x) - breadth - .30 - .06 * sin(time * .8 + lane);
    float block = foundryBox(chip, float3(.12, .12, .13), .024);
    if (block < distance.x) distance = float2(block, 3);
    return distance;
}
float3 foundryNormal(float3 p, float time, float energy) {
    float2 e = float2(.0015, 0);
    return normalize(float3(foundryMap(p + e.xyy, time, energy).x - foundryMap(p - e.xyy, time, energy).x,
        foundryMap(p + e.yxy, time, energy).x - foundryMap(p - e.yxy, time, energy).x,
        foundryMap(p + e.yyx, time, energy).x - foundryMap(p - e.yyx, time, energy).x));
}
float foundryShadow(float3 p, float3 light, float time, float energy) {
    float visibility = 1, travel = .035;
    for (int i = 0; i < 12; i++) {
        float distance = foundryMap(p + light * travel, time, energy).x;
        visibility = min(visibility, 10 * distance / travel);
        travel += clamp(distance, .03, .22);
    }
    return clamp(visibility, .18, 1.0);
}
float3 foundrySurface(float3 p, float3 rd, float material, constant WallpaperUniforms &u) {
    float3 normal = foundryNormal(p, u.time, u.energy);
    float3 light = normalize(float3(-3, 5, 6));
    float diffuse = max(dot(normal, light), 0.0);
    diffuse *= foundryShadow(p + normal * .008, light, u.time, u.energy);
    float specular = pow(max(dot(reflect(rd, normal), light), 0.0), 48.0);
    float fresnel = pow(1.0 - max(dot(normal, -rd), 0.0), 3.0);
    float ao = clamp(foundryMap(p + normal * .13, u.time, u.energy).x / .13, .30, 1.0);
    float3 ceramic = mix(float3(.86, .94, .89), float3(.24, .40, .42), u.channels.x * .35);
    float3 color = ceramic * (.20 + diffuse * .83) * ao + specular * .65;
    color += u.accent.rgb * fresnel * .75;
    float3 reflection = reflect(rd, normal);
    color += float3(.40, .25, .95) * pow(max(dot(reflection, normalize(float3(4,1,-3))), 0.0), 6.0) * .9;
    color += float3(.85,1,.95) * pow(max(dot(reflection, normalize(float3(-.6,.9,0))), 0.0), 30.0) * 1.4;
    color += u.accent.rgb * pow(max(0.0, -normal.y), 2.0) * .23;
    if (material > 1.5 && material < 2.5) {
        float pulse = pow(.5 + .5 * sin(p.z * 5 - u.time * 2.4), 6.0);
        color = u.accent.rgb * (1.0 + pulse * (1.2 + u.energy));
    }
    if (material > 2.5) color = mix(color, u.accent.rgb * .5, .24);
    return color;
}
fragment float4 codexFoundryFragment(WallpaperVertex in [[stage_in]], constant WallpaperUniforms &u [[buffer(0)]]) {
    float2 canvas = (in.uv - .5) * u.size / min(u.size.y, u.size.x / 1.6);
    float2 p = (canvas - float2(.35, -.015)) * 2.8;
    float3 ro = float3(2.8, 2.1, 6.5);
    float3 forward = normalize(-ro), right = normalize(cross(forward, float3(0, 1, 0)));
    float3 up = cross(right, forward), rd = normalize(forward * 2.8 + right * p.x - up * p.y);
    float3 color = u.background.rgb;
    float glow = exp(-length((canvas - float2(.32, .02)) * float2(1.4, 1.0)) * 3.0);
    color += float3(.035, .19, .14) * glow;
    // A receding engineering grid belongs to the environment, not the type surface.
    if (rd.y < -.001) {
        float groundT = (-1.55 - ro.y) / rd.y;
        float3 ground = ro + rd * groundT;
        float2 grid = abs(fract(ground.xz * 1.7) - .5) / max(fwidth(ground.xz * 1.7), .002);
        float line = 1 - min(min(grid.x, grid.y), 1.0);
        color += u.accent.rgb * line * .11 * exp(-length(ground.xz) * .35);
        color += u.accent.rgb * exp(-dot(ground.xz, ground.xz) * .40) * .13;
    }
    float t = 0, material = 0; bool surface = false;
    for (int i = 0; i < 92; i++) {
        float2 hit = foundryMap(ro + rd * t, u.time, u.energy);
        material = hit.y;
        if (hit.x < .002) { surface = true; break; }
        if (t > 13) break;
        t += hit.x * .82;
    }
    if (surface) color = foundrySurface(ro + rd * t, rd, material, u);
    // A stream of luminous packets travels through the empty center and between ribs.
    for (int i = 0; i < 28; i++) {
        float index = float(i), phase = fract(index * .618 + u.time * .27);
        float3 packet = float3(sin(index * 2.4) * .67, cos(index * 1.8) * .72, 2.5 - phase * 5.0);
        float along = dot(packet - ro, rd);
        float distance = length(ro + rd * along - packet);
        float visible = along < t + .04 ? 1.0 : .10;
        float bright = exp(-distance * distance * 1600.0) + exp(-distance * distance * 90.0) * .13;
        color += mix(u.accent.rgb, float3(.66,.52,1), fract(index*.37)) * bright * visible * (1.0 + u.energy * 1.6 + u.channels.y);
    }
    // The central light column has depth: use closest approach to the chamber's z axis.
    float beamT = -dot(ro.xy, rd.xy) / max(dot(rd.xy, rd.xy), .0001);
    float3 beamPoint = ro + rd * beamT;
    float beam = exp(-dot(beamPoint.xy, beamPoint.xy) * 120.0) * exp(-abs(beamPoint.z) * .40);
    color += u.accent.rgb * beam * .38 * (.8 + u.energy + u.channels.y);
    // Reserve a calm, readable region for the headline and real-data counters.
    color *= 1.0 - .45 * (1 - smoothstep(-.20, .04, canvas.x));
    color = 1.0 - exp(-color * 1.35);
    color += (hash21(in.uv * u.size) - .5) * .006;
    return float4(color, 1);
}
