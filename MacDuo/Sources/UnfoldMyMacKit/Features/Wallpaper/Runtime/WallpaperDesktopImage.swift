import AppKit

struct WallpaperDesktopImage: Codable, Equatable {
    var url: URL
    var scaling: Int?
    var clipping: Bool?
    var fill: [Double]?

    @MainActor init(url: URL, options: [NSWorkspace.DesktopImageOptionKey: Any] = [:]) {
        self.url = url
        scaling = (options[.imageScaling] as? NSNumber)?.intValue
        clipping = (options[.allowClipping] as? NSNumber)?.boolValue
        if let color = (options[.fillColor] as? NSColor)?.usingColorSpace(.deviceRGB) {
            fill = [color.redComponent, color.greenComponent, color.blueComponent]
        }
    }
    @MainActor var options: [NSWorkspace.DesktopImageOptionKey: Any] {
        var values: [NSWorkspace.DesktopImageOptionKey: Any] = [:]
        if let scaling { values[.imageScaling] = scaling }
        if let clipping { values[.allowClipping] = clipping }
        if let fill, fill.count == 3 { values[.fillColor] = NSColor(red: fill[0], green: fill[1], blue: fill[2], alpha: 1) }
        return values
    }
}
