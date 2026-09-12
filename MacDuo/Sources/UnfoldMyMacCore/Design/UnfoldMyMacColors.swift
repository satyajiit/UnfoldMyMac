import Foundation

/// Fixed, opaque sRGB surfaces used for measurable text contrast.
public enum UnfoldMyMacColors {
    public static let lightCanvas: UInt32 = 0xF5F5F5
    public static let lightCard: UInt32 = 0xFFFFFF
    public static let lightInk: UInt32 = 0x1D1D1F
    public static let lightSecondary: UInt32 = 0x595963
    public static let lightAccent: UInt32 = 0x005BC6
    public static let darkCanvas: UInt32 = 0x1A1A1A
    public static let darkCard: UInt32 = 0x242424
    public static let darkInk: UInt32 = 0xF5F5F7
    public static let darkSecondary: UInt32 = 0xB9B9C3
    public static let darkControlAccent: UInt32 = 0x1870DA
    public static let darkAccent: UInt32 = 0x8FBFFF
    public static func luminance(_ hex: UInt32) -> Double {
        func linear(_ value: UInt32) -> Double {
            let c = Double(value) / 255
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear((hex >> 16) & 255) + 0.7152 * linear((hex >> 8) & 255) + 0.0722 * linear(hex & 255)
    }
    public static func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let x = luminance(a), y = luminance(b)
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
}
