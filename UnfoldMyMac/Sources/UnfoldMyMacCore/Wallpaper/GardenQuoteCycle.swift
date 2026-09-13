import Foundation

public struct GardenQuotePresentation: Equatable, Sendable {
    public var text: String
    public var opacity: Double
}

/// One shared clock across preview and desktop. Fade completely out before replacing a line.
public struct GardenQuoteCycle: Sendable {
    public static let lines = [
        "Small steps still move you forward.", "Give good things time to grow.",
        "Begin with one kind thing.", "Your pace can be a peaceful one.",
        "Make a little room for wonder.", "You can start again, softly.",
        "A little progress is still progress.", "Let today be a place to begin.",
        "Rest is part of growing.", "Keep tending to what matters."
    ]
    private var index = 0
    private var elapsed = 0.0
    private var transition: Double?
    private var swapped = false
    private let deck: [String]
    public init(lines: [String] = Self.lines) { deck = lines.isEmpty ? Self.lines : lines }
    public mutating func advance(delta: Double, next: Bool, animated: Bool, interval: Double) -> GardenQuotePresentation {
        guard animated else {
            transition = nil; elapsed = 0
            return .init(text: deck[index], opacity: 1)
        }
        let dt = min(0.1, max(0, delta))
        elapsed += dt
        if transition == nil && (next || elapsed >= interval) { transition = 0; swapped = false }
        var opacity = 1.0
        if let age = transition {
            var age = age+dt
            // Land on a fully hidden frame even when a slow tick steps over the midpoint.
            if age >= 0.8 && !swapped { index = (index+1) % deck.count; swapped = true; age = 0.8 }
            let phase = min(1, abs(age-0.8)/0.8)
            opacity = phase*phase*(3-2*phase)
            transition = age
            if age >= 1.6 { transition = nil; elapsed = 0; opacity = 1 }
        }
        return .init(text: deck[index], opacity: opacity)
    }
    public mutating func pause() { elapsed = 0; transition = nil }
}
