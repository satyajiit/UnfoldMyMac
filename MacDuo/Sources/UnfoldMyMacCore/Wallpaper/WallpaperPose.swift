import Foundation

/// What one frame of a scene needs from a data snapshot: the reactive energy, up to four normalised channels
/// and an optional scalar grid. Computed when the snapshot changes, never per frame or per body evaluation.
/// A metric with no sample yet reads as the template's `idleEnergy` (W6), so a scene can rest above zero.
public struct WallpaperPose: Equatable, Sendable {
    public var energy: Double
    public var channels: SIMD4<Float>
    public var grid: WallpaperScalarGrid?

    public init(energy: Double = 0, channels: SIMD4<Float> = .zero, grid: WallpaperScalarGrid? = nil) {
        self.energy = energy; self.channels = channels; self.grid = grid
    }
    public init(template: WallpaperTemplate, snapshot: WallpaperSnapshot, at date: Date = .now) {
        energy = snapshot.number(template.reactiveMetric, at: date).map { $0 / template.reactiveScale } ?? template.idleEnergy ?? 0
        var values = SIMD4<Float>.zero
        for (index, binding) in (template.channels ?? []).prefix(4).enumerated() {
            values[index] = Float(min(1, max(0, (snapshot.number(binding.metric, at: date) ?? 0) / binding.scale)))
        }
        channels = values
        grid = template.gridBinding.flatMap { snapshot.grid($0, at: date) }
    }
}
