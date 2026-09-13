#include <metal_stdlib>
using namespace metal;

struct ImpactVertex { float4 position [[position]]; float2 uv; };
struct ImpactUniforms { float closure; float strength; float aspect; float time; float2 pixel; };

vertex ImpactVertex impactVertex(uint id [[vertex_id]]) {
    float2 p = float2((id << 1) & 2, id & 2);
    return {float4(p * 2.0 - 1.0, 0, 1), float2(p.x, 1.0 - p.y)};
}

float2 impactHash(float2 p) {
    return fract(sin(float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3)))) * 43758.5453);
}

// An impact spreads from the centre. Irregular glass facets grow independently,
// catch spectral light and seal together; opening retraces the same fracture.
fragment float4 fractureFragment(ImpactVertex in [[stage_in]], constant ImpactUniforms &u [[buffer(0)]]) {
    float2 p = (in.uv - .5) * float2(u.aspect, 1);
    float radius = length(p), corner = length(float2(u.aspect, 1)) * .5;
    float reach = .012 + u.closure * (corner + .15);
    float aa = max(u.pixel.y * 1.5, .0005);
    float front = 1.0 - smoothstep(reach - aa, reach + aa, radius);
    float2 grid = p * 8.0, cell = floor(grid), local = fract(grid);
    float nearest = 100.0, second = 100.0;
    float2 seed = 0, facet = 0;
    for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
        float2 offset = float2(x, y);
        float2 random = impactHash(cell + offset);
        float2 delta = offset + .15 + random * .7 - local;
        float distance = dot(delta, delta);
        if (distance < nearest) {
            second = nearest; nearest = distance; seed = random; facet = delta;
        } else { second = min(second, distance); }
    }
    float edge = (sqrt(second) - sqrt(nearest)) / 8.0;
    float seal = smoothstep(.78, 1.0, u.closure);
    float gap = sin(u.closure * M_PI_F) * .005;
    float shard = smoothstep(gap, gap + aa, edge);
    float crack = 1.0 - smoothstep(.001, .0035 + aa, edge);
    float glint = pow(max(0.0, sin(dot(facet, float2(3, -5)) + seed.x * 9 + u.closure * 5)), 16.0);
    float3 spectrum = .5 + .5 * cos(float3(0, 2.1, 4.2) + seed.x * 8 + u.closure * 4);
    float3 glass = mix(float3(.055, .12, .19), float3(.27, .43, .53), seed.y);
    glass += spectrum * (.12 + glint * .48) * u.strength;
    glass += float3(.65, .85, 1) * crack * .55;
    float rays = pow(abs(cos(atan2(p.y, p.x) * 7.0 + radius * 2)), 90.0);
    float impact = exp(-radius * 24.0) * rays;
    glass += float3(.7, .9, 1) * impact * .6;
    float alpha = front * mix(shard * (.66 + .2 * seed.y) + crack * .3, 1.0, seal);
    alpha = saturate(alpha);
    return float4(saturate(glass) * alpha, alpha);
}

// Ink unfurls in curled arms around a central pool; the perimeter never slides
// in from the sides. The two angular terms remain continuous across atan2's seam.
fragment float4 vortexFragment(ImpactVertex in [[stage_in]], constant ImpactUniforms &u [[buffer(0)]]) {
    float2 p = (in.uv - .5) * float2(u.aspect, 1);
    float radius = length(p), angle = atan2(p.y, p.x);
    float corner = length(float2(u.aspect, 1)) * .5;
    float curl = angle * 5.0 + radius * 19.0 - u.time * .55 - u.closure * 8.0;
    float tendril = sin(curl) * .065 + sin(angle * 9.0 - radius * 12.0 + u.time * .3) * .025;
    float reach = .014 + u.closure * (corner + .24);
    float flutter = sin(u.closure * M_PI_F) * (.45 + u.strength * .55);
    float signedEdge = radius - reach + tendril * flutter;
    float aa = max(u.pixel.y * 1.5, .0005);
    float alpha = 1.0 - smoothstep(-aa, aa, signedEdge);
    float rim = exp(-abs(signedEdge) * 65.0);
    float veins = pow(.5 + .5 * sin(curl * 2.0 + sin(radius * 24.0 - u.time)), 9.0);
    float3 ink = mix(float3(.025, .018, .09), float3(.20, .055, .30), .5 + .5 * sin(curl));
    ink += float3(.06, .48, .58) * veins * (.12 + u.strength * .35);
    ink += mix(float3(.22, .50, .88), float3(.73, .32, .65), .5 + .5 * sin(angle * 3.0)) * rim * .7;
    return float4(saturate(ink) * alpha, alpha);
}
