import Foundation

/// Typography a template may tune: the shared `Style.json` supplies every value, a template overrides some.
public struct WallpaperStyle: Codable, Equatable, Sendable {
    public var boldFont: String? = nil
    public var mediumFont: String? = nil
    /// Font size (as a fraction of canvas width) at and above which the bold face is used.
    public var boldThreshold: Double? = nil
    /// Font size below which caption tracking applies.
    public var captionThreshold: Double? = nil
    public var captionTracking: Double? = nil
    public var displayTracking: Double? = nil
    public init(boldFont: String? = nil, mediumFont: String? = nil, boldThreshold: Double? = nil, captionThreshold: Double? = nil,
                captionTracking: Double? = nil, displayTracking: Double? = nil) {
        self.boldFont = boldFont; self.mediumFont = mediumFont; self.boldThreshold = boldThreshold
        self.captionThreshold = captionThreshold; self.captionTracking = captionTracking; self.displayTracking = displayTracking
    }
    public static let standard = WallpaperStyle(boldFont: "SpaceGrotesk-Bold", mediumFont: "SpaceGrotesk-Medium", boldThreshold: 0.035,
                                                captionThreshold: 0.02, captionTracking: 2, displayTracking: -1)
    public var isValid: Bool {
        let fontPattern = #"^[A-Za-z0-9-]{1,80}$"#
        return [boldFont, mediumFont].allSatisfy { $0 == nil || $0!.range(of: fontPattern, options: .regularExpression) != nil } &&
            [boldThreshold, captionThreshold].allSatisfy { $0 == nil || ($0!.isFinite && (0...1).contains($0!)) } &&
            [captionTracking, displayTracking].allSatisfy { $0 == nil || ($0!.isFinite && abs($0!) <= 20) }
    }
    /// This style's values over `base` where they are set.
    public func merged(over base: WallpaperStyle) -> WallpaperStyle {
        WallpaperStyle(boldFont: boldFont ?? base.boldFont, mediumFont: mediumFont ?? base.mediumFont,
                       boldThreshold: boldThreshold ?? base.boldThreshold, captionThreshold: captionThreshold ?? base.captionThreshold,
                       captionTracking: captionTracking ?? base.captionTracking, displayTracking: displayTracking ?? base.displayTracking)
    }
}
