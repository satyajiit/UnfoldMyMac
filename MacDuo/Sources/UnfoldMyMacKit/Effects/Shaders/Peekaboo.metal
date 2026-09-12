#include <metal_stdlib>
using namespace metal;

struct PeekabooUniforms { float closure; float strength; float aspect; float time; };
struct ToyPoint {
    float4 position [[position]];
    float3 world;
    float3 normal;
    float2 uv;
    float side;
};
constant float toyTau = 6.28318530718;
constant float toyWidth = 0.57;

// The envelope is zero at either endpoint: immediate entry, a sealed finish,
// and a genuinely clear desktop at zero, regardless of time or strength.
float toyEdge(float v, float side, constant PeekabooUniforms &u) {
    float envelope = sin(M_PI_F * u.closure);
    float wave = sin(v * toyTau * 2.5 + side * 0.65 + u.time * 0.8);
    return 0.505 * u.closure + envelope * (0.012 + 0.018 * u.strength * wave);
}
float3 toyBodyPosition(float2 uv, float side, constant PeekabooUniforms &u) {
    float x = toyEdge(uv.y, side, u) - (1.0 - uv.x) * toyWidth;
    if (side > 0.5) x = 1.0 - x;
    float bevel = saturate((uv.x - 0.80) / 0.20);
    float round = sqrt(max(0.0, 1.0 - bevel * bevel));
    float breathing = 0.009 * u.strength * sin(u.time * 1.15 + uv.y * 5.0 + side);
    float z = 0.035 + (0.20 + breathing) * round;
    z += 0.065 * cos(uv.y * toyTau * 3.0 + 0.20 * sin(uv.x * 6.0) + side * 0.3) * round;
    return float3((x - 0.5) * 2.0 * u.aspect, (0.5 - uv.y) * 2.14, z);
}
float toyEyeRadius(constant PeekabooUniforms &u) { return min(0.19, u.aspect * 0.15); }
float3 toyEyeCenter(float side, float which, constant PeekabooUniforms &u) {
    float v = 0.43 + which * 0.026 + side * 0.015;
    float x = toyEdge(v, side, u) - 0.095 - which * 0.145;
    if (side > 0.5) x = 1.0 - x;
    float2 uv = float2(1.0 - (0.095 + which * 0.145) / toyWidth, v);
    float3 surface = toyBodyPosition(uv, side, u);
    return float3((x - 0.5) * 2.0 * u.aspect, surface.y, surface.z + toyEyeRadius(u) * 0.52);
}
float4 toyProjection(float3 world, constant PeekabooUniforms &u) {
    // Orthographic geometry keeps the faces at a stable scale throughout travel.
    return float4(world.x / u.aspect, world.y, 0.65 - world.z * 0.5, 1.0);
}

vertex ToyPoint peekabooBodyVertex(uint id [[vertex_id]], uint side [[instance_id]],
    const device float2 *points [[buffer(0)]], constant PeekabooUniforms &u [[buffer(1)]]) {
    float2 uv = points[id];
    float3 world = toyBodyPosition(uv, float(side), u);
    float3 du = toyBodyPosition(float2(min(1.0, uv.x + 0.001), uv.y), float(side), u)
              - toyBodyPosition(float2(max(0.0, uv.x - 0.001), uv.y), float(side), u);
    float3 dv = toyBodyPosition(float2(uv.x, uv.y + 0.001), float(side), u)
              - toyBodyPosition(float2(uv.x, uv.y - 0.001), float(side), u);
    float3 normal = normalize(cross(dv, du));
    if (normal.z < 0) normal = -normal;
    return { toyProjection(world, u), world, normal, uv, float(side) };
}

float3 toyLighting(float3 base, float3 normal, float3 world, float gloss) {
    float3 n = normalize(normal);
    float3 view = normalize(float3(0, 0, 5) - world);
    float3 key = normalize(float3(-1.7, 2.8, 3.5) - world);
    float3 fill = normalize(float3(2.8, 0.5, 2.4) - world);
    float light = 0.30 + 0.64 * max(0.0, dot(n, key)) + 0.20 * max(0.0, dot(n, fill));
    float shine = pow(max(0.0, dot(n, normalize(key + view))), 65.0);
    float broad = pow(max(0.0, dot(n, normalize(fill + view))), 18.0);
    float rim = pow(1.0 - max(0.0, dot(n, view)), 3.0);
    return base * light + float3(1.0, 0.92, 0.8) * shine * gloss
        + float3(0.66, 0.76, 1.0) * broad * gloss * 0.22 + base * rim * 0.45;
}

fragment float4 peekabooBodyFragment(ToyPoint in [[stage_in]], constant PeekabooUniforms &u [[buffer(1)]]) {
    float3 base = in.side < 0.5 ? float3(0.96, 0.145, 0.018) : float3(0.22, 0.075, 0.86);
    float3 color = toyLighting(base, in.normal, in.world, 0.9);
    // Soft socket shadows anchor the real sphere meshes in the vinyl surface.
    for (int eye = 0; eye < 2; ++eye) {
        float3 centre = toyEyeCenter(in.side, float(eye), u);
        float d = length((in.world.xy - centre.xy) / toyEyeRadius(u));
        color *= 1.0 - 0.52 * exp(-pow(d / 1.20, 4.0));
    }
    // A shallow embossed smile follows each body's local coordinates.
    float distanceFromEdge = (1.0 - in.uv.x) * toyWidth * 2.0 * u.aspect;
    float mx = (distanceFromEdge - 0.17 * 2.0 * u.aspect) / min(0.21, u.aspect * 0.17);
    float my = in.world.y + 0.29 + 0.055 * (1.0 - mx * mx);
    float smile = length(float2(max(0.0, abs(mx) - 0.9) * 0.16, my));
    float aa = max(fwidth(my), 0.001);
    float mouth = 1.0 - smoothstep(0.012 - aa, 0.012 + aa, smile);
    color = mix(color, float3(0.012, 0.009, 0.025), mouth);
    float lip = exp(-pow((smile - 0.022) / 0.008, 2.0)) * (1.0 - mouth);
    color += float3(0.22, 0.15, 0.20) * lip;
    return float4(color, 1.0);
}

vertex ToyPoint peekabooEyeVertex(uint id [[vertex_id]], uint instance [[instance_id]],
    const device float2 *points [[buffer(0)]], constant PeekabooUniforms &u [[buffer(1)]]) {
    float side = float(instance / 2), which = float(instance % 2);
    float2 uv = points[id];
    float theta = uv.y * M_PI_F, phi = uv.x * toyTau;
    float3 n = float3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi));
    // Short, staggered blinks. Strength zero is a calm, motionless expression.
    float blink = pow(max(0.0, cos(u.time * 1.5 + 1.1 + side * 0.22)), 48.0) * u.strength;
    float squash = 1.0 - 0.96 * blink;
    float3 world = toyEyeCenter(side, which, u) + n * float3(1, squash, 0.84) * toyEyeRadius(u);
    float3 normal = normalize(n / float3(1, squash, 0.84));
    return { toyProjection(world, u), world, normal, uv, side };
}

fragment float4 peekabooEyeFragment(ToyPoint in [[stage_in]], constant PeekabooUniforms &u [[buffer(1)]]) {
    float3 n = normalize(in.normal);
    float direction = in.side < 0.5 ? 1.0 : -1.0;
    float3 gaze = normalize(float3(direction * 0.25 + 0.13 * u.strength * sin(u.time * 0.9),
        0.06 * u.strength * sin(u.time * 0.7 + in.side), 1.0));
    float pupilDistance = dot(n, gaze);
    float aa = max(fwidth(pupilDistance), 0.002);
    float pupil = smoothstep(0.84 - aa, 0.84 + aa, pupilDistance);
    float3 base = mix(float3(0.97, 0.88, 0.69), float3(0.007, 0.009, 0.018), pupil);
    return float4(toyLighting(base, n, in.world, mix(0.45, 1.05, pupil)), 1.0);
}
