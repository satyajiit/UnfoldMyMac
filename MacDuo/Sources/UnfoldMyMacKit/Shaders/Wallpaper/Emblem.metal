// MTKTextureLoader supplies premultiplied source pixels. Never tint or deform marks.
fragment float4 emblemFragment(WallpaperVertex in [[stage_in]], texture2d<float> mark [[texture(0)]]) {
    constexpr sampler original(filter::linear, address::clamp_to_edge);
    return mark.sample(original, in.uv);
}
