#include <metal_stdlib>
using namespace metal;

struct CurtainsUniforms {
    float closure;
    float strength;
    float aspect;
    float pad;
};
struct ClothPoint {
    float4 position [[position]];
    float3 world;
    float3 normal;
    float2 uv;
    float fold;
    float side;
};
struct ShadowPoint {
    float4 position [[position]];
    float2 uv;
};
constant float tau = 6.28318530718;

// The leading edge touches the display at zero, then immediately enters each half.
// Progress alone drives the deformation: reverse scrubbing retraces the same pose.
float curtainEdge(float v, constant CurtainsUniforms &u) {
    float p = u.closure;
    float outer = mix(-0.095, -0.015, p);
    float width = mix(0.095, 0.525, p);
    float drape = sin(M_PI_F * v) * sin(M_PI_F * p);
    return outer + width - 0.023 * drape;
}

float3 clothPosition(float2 uv, float side, constant CurtainsUniforms &u, thread float &fold) {
    float p = u.closure;
    float outer = mix(-0.095, -0.015, p);
    float edge = curtainEdge(uv.y, u);
    // Unequal pleat spacing and deeper hanging folds avoid a repeated ribbed sheet.
    float phase = tau * (uv.x * 11.0 + 0.19 * sin(uv.x * tau * 2.0 + side * 0.35)
                        + 0.07 * sin(uv.x * tau * 5.0));
    phase += 0.86 * sin(uv.y * 3.4 + uv.x * 5.0 + side * 0.4) * sin(M_PI_F * uv.y);
    phase += 0.3 * sin(p * M_PI_F) * sin(uv.y * 7.0 + uv.x * 9.0);
    fold = cos(phase);
    float amplitude = mix(0.012, 0.048, u.strength) * mix(0.68, 1.0, p);
    amplitude *= (0.82 + 0.18 * sin(uv.x * 17.0 + side)) * (0.88 + 0.12 * uv.y);
    float z = amplitude * (fold + 0.19 * cos(phase * 2.0 + 0.6));
    z += 0.004 * u.strength * sin(uv.y * 14.0 + uv.x * 23.0 + side) * pow(uv.y, 3.0);
    // A narrow rolled leading edge gives the centre seam thickness.
    z += 0.015 * exp(-pow((uv.x - 0.985) / 0.025, 2.0));
    float x = mix(outer, edge, uv.x);
    if (side > 0.5) x = 1.0 - x;
    float y = mix(-0.035, 1.035, uv.y);
    return float3((x - 0.5) * 2.0 * u.aspect, (0.5 - y) * 2.0, z);
}

vertex ClothPoint curtainVertex(uint id [[vertex_id]], uint side [[instance_id]],
                                const device float2 *points [[buffer(0)]], constant CurtainsUniforms &u [[buffer(1)]]) {
    ClothPoint out;
    float2 uv = points[id];
    float fold, unused;
    float3 world = clothPosition(uv, float(side), u, fold);
    float3 du = clothPosition(uv + float2(0.0002, 0), float(side), u, unused) - world;
    float3 dv = clothPosition(uv + float2(0, 0.0002), float(side), u, unused) - world;
    float3 normal = normalize(cross(dv, du));
    if (normal.z < 0) normal = -normal;
    out.position = float4(world.x / u.aspect, world.y, 0.5 - world.z * 0.1, 1.0);
    out.world = world;
    out.normal = normal;
    out.uv = uv;
    out.fold = fold;
    out.side = float(side);
    return out;
}

fragment float4 curtainFragment(ClothPoint in [[stage_in]], constant CurtainsUniforms &u [[buffer(1)]]) {
    float3 n = normalize(in.normal);
    float3 eye = normalize(float3(0, 0, 4) - in.world);
    float3 key = normalize(float3(-1.8, 2.7, 3.6) - in.world);
    float3 fill = normalize(float3(2.1, 0.7, 2.3) - in.world);
    float diffuse = max(0.0, dot(n, key));
    float ambientOcclusion = mix(0.33, 1.0, smoothstep(-0.95, 0.8, in.fold));
    float spot = 0.65 + 0.35 * exp(-pow((in.uv.y - 0.18) * 2.0, 2.0));
    spot *= 0.90 + 0.10 * sin(in.uv.x * 3.8 + 0.6);
    float illumination = (0.19 + 0.73 * diffuse + 0.15 * max(0.0, dot(n, fill))) * ambientOcclusion * spot;
    // Velvet has broad grazing sheen, not a polished plastic specular lobe.
    float sheen = pow(1.0 - abs(dot(n, eye)), 2.6) * 0.13 * (0.35 + diffuse);
    float softSpecular = pow(max(0.0, dot(n, normalize(key + eye))), 18.0) * 0.025;
    float3 garnet = float3(0.32, 0.010, 0.025);
    float3 color = garnet * illumination + float3(0.48, 0.11, 0.095) * sheen;
    color += float3(1.0, 0.68, 0.44) * softSpecular;
    // Fine, low-contrast woven fibres; fwidth suppresses moiré on small previews.
    float weaveFrequency = 1100.0;
    float weave = sin(in.uv.x * weaveFrequency * tau) * sin(in.uv.y * 1700.0 * tau);
    float weaveVisible = 1.0 - smoothstep(0.2, 0.7, max(fwidth(in.uv.x) * weaveFrequency, fwidth(in.uv.y) * 1700.0));
    color *= 1.0 + 0.025 * weave * weaveVisible;
    // A slim antique-brass selvedge follows the rolled opening, away from the join.
    float piping = 1.0 - smoothstep(0.0018, 0.0045, abs(in.uv.x - 0.975));
    float3 brass = float3(0.30, 0.15, 0.048) * (0.28 + 0.72 * diffuse);
    color = mix(color, brass, piping * 0.7);
    float hem = 1.0 - 0.17 * exp(-pow((in.uv.y - 0.96) / 0.004, 2.0));
    color *= hem;
    // Opaque even at minimum fold depth. Fully closed is fabric, never a fade to black.
    return float4(color, 1.0);
}

vertex ShadowPoint curtainShadowVertex(uint id [[vertex_id]]) {
    float2 points[3] = { float2(-1, -1), float2(3, -1), float2(-1, 3) };
    ShadowPoint out;
    out.position = float4(points[id], 0.9, 1.0);
    out.uv = float2((points[id].x + 1.0) * 0.5, (1.0 - points[id].y) * 0.5);
    return out;
}
fragment float4 curtainShadowFragment(ShadowPoint in [[stage_in]], constant CurtainsUniforms &u [[buffer(1)]]) {
    float edge = curtainEdge((in.uv.y + 0.035) / 1.07, u);
    float distance = max(0.0, min(in.uv.x - edge, 1.0 - edge - in.uv.x));
    float softness = 0.024;
    float alpha = 0.30 * (1.0 - smoothstep(0.0, softness, distance));
    alpha *= smoothstep(0.0, 0.12, u.closure);
    return float4(0, 0, 0, alpha);
}
