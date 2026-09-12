#include <metal_stdlib>
using namespace metal;
struct WallpaperVertex { float4 position [[position]]; float2 uv; };
struct WallpaperUniforms { float2 size; float time; float energy; float4 accent; float4 background; float4 channels; float4 params[2]; };
vertex WallpaperVertex wallpaperVertex(uint id [[vertex_id]]) {
    float2 p = float2((id << 1) & 2, id & 2);
    return {float4(p * 2.0 - 1.0, 0, 1), float2(p.x, 1.0-p.y)};
}
float hash21(float2 p) { return fract(sin(dot(p,float2(127.1,311.7)))*43758.5453); }
float2 rotate2(float2 p, float angle) { float s=sin(angle), c=cos(angle); return float2(c*p.x-s*p.y,s*p.x+c*p.y); }
float torus(float3 p,float2 radii) { return length(float2(length(p.xz)-radii.x,p.y))-radii.y; }
float3 atmosphere(float2 uv, constant WallpaperUniforms &u) {
    float glow=exp(-3.5*length((uv-float2(.72,.48))*float2(1.2,1)));
    float3 color=u.background.rgb + u.accent.rgb*glow*.095;
    color += (hash21(uv*u.size)-.5)*.008;
    return color;
}
float3 studioLight(float3 normal,float3 eye,float3 base,float roughness) {
    float diffuse=max(dot(normal,normalize(float3(-.6,.8,1))),0.0);
    float rim=pow(1.0-max(dot(normal,eye),0.0),2.4);
    float stripe=pow(max(dot(reflect(-eye,normal),normalize(float3(-.4,.6,1))),0.0),roughness);
    float stripe2=pow(max(dot(reflect(-eye,normal),normalize(float3(.8,-.1,.7))),0.0),roughness*.5);
    return base*(.13+diffuse*.72)+float3(.9,1,1)*stripe*1.3+base*stripe2*.8+base*rim*.7;
}
