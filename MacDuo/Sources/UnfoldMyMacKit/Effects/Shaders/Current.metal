#include <metal_stdlib>
using namespace metal;
struct CurrentUniforms { float closure; float strength; float aspect; float time; float2 pixel; };
struct CurrentPoint { float4 position [[position]]; float2 uv; };
vertex CurrentPoint currentVertex(uint id [[vertex_id]]) {
    float2 points[3] = { float2(-1,-1), float2(3,-1), float2(-1,3) };
    return { float4(points[id],0,1), float2((points[id].x+1)*.5,(1-points[id].y)*.5) };
}
float currentHash(float2 p) { return fract(sin(dot(p,float2(127.1,311.7)))*43758.5453); }
float3 currentSRGB(float3 c) { return select(c*12.92,1.055*pow(max(c,0.0),float3(1.0/2.4))-.055,c>.0031308); }
fragment float4 currentFragment(CurrentPoint in [[stage_in]], constant CurrentUniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    float p = u.closure;
    float t = u.time * (.16 + .25*u.strength);
    float fold = sin(M_PI_F*p);
    float wave = sin(uv.y*7.0+t)*.024 + sin(uv.y*13.0-t*.7)*.011;
    float width = .515*p + wave*fold;
    float edge = width - min(uv.x,1-uv.x);
    float aa = max(u.pixel.x,u.pixel.y);
    float alpha = smoothstep(-aa,aa,edge);
    if (p >= .995) alpha = 1;
    if (alpha <= 0) return 0;

    float2 q = float2((uv.x-.5)*u.aspect,uv.y-.5);
    float3 mint = float3(.10,.88,.61), cyan = float3(.015,.38,.52), coral = float3(1.0,.17,.11);
    float3 color = float3(.004,.023,.030) + .025*float3(.1,.9,.75)*(1-uv.y);
    // Six folded ribbons, each with a lit crest, a shaded underside, and a soft bloom.
    for (int i=0; i<6; i++) {
        float fi = float(i);
        float path = q.y + .22*q.x + .15*sin(q.x*3.7+t+fi*.65) + .075*sin(q.x*7.0-t*.75+fi);
        float centre = (fi-2.5)*.175;
        float d = path-centre;
        float span = .055+.020*sin(q.x*2.0+fi+t*.6);
        float body = 1-smoothstep(span*.55,span,abs(d));
        float normalLight = pow(clamp(.5+.5*d/span,0.0,1.0),2.0);
        float3 tint = mix(cyan,mint,.5+.5*sin(fi*1.6+q.x*.6));
        tint = mix(tint,coral,smoothstep(.5,.95,sin(fi*2.2+q.x*.8-t*.3)));
        color = mix(color,tint*(.13+.75*normalLight),body*.90);
        float crest = exp(-pow((d-span*.43)/(.004+aa),2.0));
        color += tint*(crest*.8 + exp(-abs(d)*24)*.055)*(.45+.55*u.strength);
    }
    // One particle per cell: bounded cost even at full Retina resolution.
    float2 field = float2(q.x*15.0, q.y*15.0+t*.8);
    float2 cell = floor(field);
    float random = currentHash(cell);
    float2 point = float2(random,currentHash(cell+9.0))*.7+.15;
    float spark = exp(-dot(fract(field)-point,fract(field)-point)*900.0);
    float pulse = .55+.45*sin(t*1.7+random*6.28);
    color += mix(mint,coral,random)*spark*pulse*step(.76,random)*(.3+.7*u.strength);
    float rim = exp(-max(edge,0.0)*160.0)*fold;
    color += mix(mint,coral,smoothstep(.25,.75,uv.y))*rim*.48;
    return float4(currentSRGB(clamp(color,0.0,1.0))*alpha,alpha);
}
