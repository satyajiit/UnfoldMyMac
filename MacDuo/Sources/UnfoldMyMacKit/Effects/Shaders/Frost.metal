#include <metal_stdlib>
using namespace metal;

struct VertexOut { float4 position [[position]]; float2 uv; };
struct FrostUniforms { float motion; float finalFade; float strength; float pad; float2 pixel; float2 padding; };

vertex VertexOut frostVertex(uint id [[vertex_id]]) {
    float2 p = float2((id << 1) & 2, id & 2);
    VertexOut out;
    out.position = float4(p * 2.0 - 1.0, 0.0, 1.0);
    out.uv = p; // bottom-left origin; capture textures have top-left origin
    return out;
}

float2 coverage(float2 uv, float2 width) {
    return smoothstep(-width, width, uv) * (1.0 - smoothstep(1.0 - width, 1.0 + width, uv));
}

fragment float4 frostFragment(VertexOut in [[stage_in]], texture2d<float> map [[texture(0)]],
                              constant FrostUniforms &u [[buffer(0)]]) {
    constexpr sampler smp(filter::linear, mip_filter::linear, address::clamp_to_edge);
    // The reference projects onto moving geometry. A stationary desktop needs identity UVs.
    float2 uv = in.uv;
    float2 texUV = float2(uv.x, 1.0 - uv.y);
    float edge = clamp(uv.y, 0.0, 1.0);
    float radius = 72.0 * u.motion * pow(edge, 1.35) * u.strength;
    float effect = u.motion * pow(clamp((edge - 0.2) / 0.8, 0.0, 1.0), 1.35) * u.strength;
    float2 aa = max(fwidth(uv), u.pixel * 0.5);
    float baseLod = log2(max(1.0, max(length(dfdx(uv) / u.pixel), length(dfdy(uv) / u.pixel))));
    // At zero blur the captured frame is an exact, ungraded identity image.
    float3 color = map.sample(smp, texUV, level(baseLod)).rgb;
    if (radius > 0.0) {
        float lod = max(baseLod, log2(max(1.0, radius)));
        float2 footprint = max(aa, u.pixel * radius * 0.75);
        float3 blurred = float3(0);
        for (int y = -2; y <= 2; y++) {
            for (int x = -2; x <= 2; x++) {
                float wx = x == 0 ? 6.0 : (abs(x) == 1 ? 4.0 : 1.0);
                float wy = y == 0 ? 6.0 : (abs(y) == 1 ? 4.0 : 1.0);
                float2 sampleUV = uv + float2(x, y) * u.pixel * radius;
                float2 cov = coverage(sampleUV, footprint);
                blurred += map.sample(smp, float2(sampleUV.x, 1.0 - sampleUV.y), level(lod)).rgb * cov.x * cov.y * wx * wy / 256.0;
            }
        }
        // Keep activation continuous at the image boundary; the full kernel applies by 1 px.
        color = mix(color, blurred, smoothstep(0.0, 1.0, radius));
    }
    color *= (1.0 - min(1.0, effect * 2.0)) * (1.0 - u.finalFade);
    return float4(color, 1.0);
}
