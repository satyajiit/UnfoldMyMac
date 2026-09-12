#include <metal_stdlib>
using namespace metal;

struct ArtRevealUniforms {
    float closure;
    float strength;
    float aspect;
    float imageAspect;
    uint style;
    uint pad;
    float2 pixel;
};
struct ArtPoint { float4 position [[position]]; float2 uv; };
struct ArtPanel { float4 color; float shadow; };

vertex ArtPoint artRevealVertex(uint id [[vertex_id]]) {
    float2 points[3] = { float2(-1, -1), float2(3, -1), float2(-1, 3) };
    ArtPoint out;
    out.position = float4(points[id], 0, 1);
    out.uv = float2((points[id].x + 1) * 0.5, (1 - points[id].y) * 0.5);
    return out;
}

float2 imageUV(float2 uv, constant ArtRevealUniforms &u) {
    // Aspect-fill the art, never stretch it. The desktop is not sampled or scaled.
    float2 scale = u.aspect > u.imageAspect ? float2(1, u.imageAspect / u.aspect) : float2(u.aspect / u.imageAspect, 1);
    return (uv - 0.5) * scale + 0.5;
}
float cut(float y, uint style) {
    if (style == 0) return 0.5 + 0.072 * sin((y - 0.5) * M_PI_F * 1.5) + 0.028 * sin(y * M_PI_F * 2);
    if (style == 2) return 0.5;
    return 0.5 + 0.18 * (y - 0.5);
}
float4 over(float4 front, float4 back) { return front + back * (1 - front.a); }
float3 encodeSRGB(float3 color) {
    color = max(color, 0.0);
    return select(color * 12.92, 1.055 * pow(color, float3(1.0 / 2.4)) - 0.055, color > 0.0031308);
}

ArtPanel panel(float2 screen, float side, texture2d<float> art, constant ArtRevealUniforms &u) {
    constexpr sampler sampleArt(coord::normalized, address::clamp_to_edge, filter::linear, mip_filter::linear);
    float p = u.closure;
    float opening = 1 - p;
    float bend = sin(M_PI_F * p) * u.strength;
    float direction = side < 0.5 ? -1.0 : 1.0;
    float2 centre = float2(side < 0.5 ? 0.25 : 0.75, 0.5);
    float vertical = u.style == 0 ? 0.018 : (u.style == 2 ? 0.0 : (u.style == 3 ? 0.095 : 0.075));
    // Maximum extent of cut(y) on [0, 1]. Start at the edge with no offscreen run-up.
    float travel = u.style == 0 ? 0.5527866 : (u.style == 2 ? 0.5 : 0.59);
    float2 movement = float2(direction * opening * travel, direction * bend * vertical);
    float angle = direction * bend * (u.style == 0 ? 0.018 : (u.style == 2 ? 0.0 : (u.style == 3 ? 0.045 : 0.035)));
    float2 local = screen - centre - movement;
    float c = cos(angle), s = sin(angle);
    local = float2(c * local.x + s * local.y, -s * local.x + c * local.y);
    local /= float2(1 - bend * 0.10, 1 - bend * 0.025);
    float2 uv = local + centre;
    float boundary = cut(uv.y, u.style);
    float edge = side < 0.5 ? boundary - uv.x : uv.x - boundary;
    float distance = min(edge, min(min(uv.x, 1 - uv.x), min(uv.y, 1 - uv.y)));
    float aa = max(u.pixel.x, u.pixel.y) * 0.65;
    float alpha = smoothstep(-aa, aa, distance);
    float3 rgb = art.sample(sampleArt, imageUV(uv, u)).rgb;
    rgb *= 1 - 0.09 * bend;
    float3 rim = u.style == 0 ? float3(1.0, 0.62, 0.18) : (side < 0.5 ? float3(0.03, 0.8, 1) : float3(1, 0.06, 0.35));
    if (u.style == 3) rim = side < 0.5 ? float3(1.0, 0.32, 0.02) : float3(1.0, 0.8, 0.22);
    float edgeLight = (1 - smoothstep(0.001, 0.006, max(edge, 0.0))) * bend;
    rgb = mix(rgb, rim, edgeLight * 0.6);
    ArtPanel out;
    out.color = float4(encodeSRGB(rgb) * alpha, alpha);
    out.shadow = 0.24 * (1 - smoothstep(0.0, 0.027, max(-distance, 0.0))) * smoothstep(0.0, 0.1, opening);
    return out;
}

fragment float4 artRevealFragment(ArtPoint in [[stage_in]], texture2d<float> art [[texture(0)]],
                                  constant ArtRevealUniforms &u [[buffer(0)]]) {
    constexpr sampler sampleArt(coord::normalized, address::clamp_to_edge, filter::linear, mip_filter::linear);
    // A sealed join must not leave an antialiased hairline of desktop showing.
    if (u.closure >= 0.995) return float4(encodeSRGB(art.sample(sampleArt, imageUV(in.uv, u)).rgb), 1);
    ArtPanel left = panel(in.uv, 0, art, u);
    ArtPanel right = panel(in.uv, 1, art, u);
    float shadowAlpha = 1 - (1 - left.shadow) * (1 - right.shadow);
    float4 shadows = float4(0, 0, 0, shadowAlpha);
    return over(right.color, over(left.color, shadows));
}
