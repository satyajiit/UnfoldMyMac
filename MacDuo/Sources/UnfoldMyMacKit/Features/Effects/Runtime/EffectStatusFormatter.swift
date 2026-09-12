import UnfoldMyMacCore

/// The one place runtime status becomes words, for the header, the diagnostics card and the menu bar tooltip.
@MainActor enum EffectStatusFormatter {
    static func label(for status: EffectRuntimeStatus, registry: EffectRegistry) -> String {
        switch status {
        case .off: "Off"
        case .ready: "Ready"
        case .sleeping: "Paused · sleeping"
        case .blocked(let state): state.rawValue
        case .preparing(let id): "Preparing \(registry.entry(for: id).descriptor.title)…"
        case .previewing(let id): "Previewing \(registry.entry(for: id).descriptor.title)"
        case .armed(let activation): "Ready · close to \(Int(activation))°"
        case .active(let id): "\(registry.entry(for: id).descriptor.title) active"
        case .screenRecordingNeeded: "Screen Recording needed"
        case .unavailable: "Effect unavailable"
        }
    }
}
