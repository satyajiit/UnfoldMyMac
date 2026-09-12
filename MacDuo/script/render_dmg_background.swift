// render_dmg_background — draw the UnfoldMyMac installer window artwork.
//
// The DMG a user double-clicks is the first UnfoldMyMac surface they ever see, so it is drawn
// in the product's own typeface and palette rather than left as Finder's default white box.
//
// WHY THIS IS GENERATED AND NOT A COMMITTED PNG. The artwork embeds the product name, the
// version and the OS floor. Those are facts that change, and a committed image is a fact nobody
// re-renders: it goes stale silently and ships stale. Rendering at package time keeps it honest,
// and the fonts it needs already ship inside the app.
//
// LIGHT IS THE DEFAULT, and the reason is Finder, not taste. Finder draws the "UnfoldMyMac" and
// "Applications" captions itself, in the system label colour, and that colour follows the
// VIEWER's appearance setting, not this background. The artwork cannot control it, so it has to
// bet on which mismatch is least bad. Light Mode is the common default and draws DARK captions,
// which read correctly on a light ground; the same captions on a near-black ground would be
// dark on near-black and effectively invisible. The bet loses for a Dark Mode viewer, who gets
// white captions on light, so --theme dark stays one word away.
//
// Usage: xcrun swift render_dmg_background.swift --out DIR --fonts DIR
//                                                [--theme light|dark] [--version 1.0.0]
// Writes background.png (1x), background@2x.png and layout.plist. The caller combines the two
// PNGs into a HiDPI TIFF with `tiffutil -cathidpicheck` and positions the real icons from
// layout.plist, so the drawn arrow and the real icons cannot drift apart.

import AppKit
import CoreText
import Foundation

let WIDTH: CGFloat = 660
let HEIGHT: CGFloat = 420

// Finder icon-slot centres, measured from the TOP-LEFT of the window content, which is the same
// origin the background is drawn against. package_dmg.sh positions the real icons at exactly
// these coordinates by reading layout.plist; two hand-kept copies of these numbers is how an
// installer ends up with an arrow pointing at empty space.
let APP_ICON_CENTER_X: CGFloat = 175
let APPLICATIONS_ICON_CENTER_X: CGFloat = 485
let ICON_ROW_CENTER_Y: CGFloat = 222
let ICON_SIZE: Int = 128

struct Palette {
    let ground: NSColor, title: NSColor, subtitle: NSColor, accent: NSColor, footer: NSColor
}

func hex(_ value: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255, alpha: alpha)
}

// Straight from Sources/UnfoldMyMacCore/Design/UnfoldMyMacColors.swift, so the installer and the
// app it installs are the same two palettes.
let lightPalette = Palette(ground: hex(0xF5F5F5), title: hex(0x1D1D1F), subtitle: hex(0x595963),
                           accent: hex(0x005BC6), footer: hex(0x595963, alpha: 0.75))
let darkPalette = Palette(ground: hex(0x1A1A1A), title: hex(0xF5F5F7), subtitle: hex(0xB9B9C3),
                          accent: hex(0x8FBFFF), footer: hex(0xB9B9C3, alpha: 0.75))

func argument(_ name: String) -> String? {
    let args = CommandLine.arguments
    guard let index = args.firstIndex(of: name), index + 1 < args.count else { return nil }
    return args[index + 1]
}

guard let outPath = argument("--out"), let fontPath = argument("--fonts") else {
    FileHandle.standardError.write(Data("render_dmg_background: --out and --fonts are required\n".utf8))
    exit(2)
}
let theme = argument("--theme") ?? "light"
let version = argument("--version") ?? ""
let palette = theme == "dark" ? darkPalette : lightPalette

// Registered into this process only. Nothing about the build host changes, and nothing has to be
// installed for a release to render correctly.
let fontDirectory = URL(fileURLWithPath: fontPath, isDirectory: true)
for face in ["SpaceGrotesk-Regular", "SpaceGrotesk-Medium", "SpaceGrotesk-Bold"] {
    let url = fontDirectory.appendingPathComponent("\(face).ttf")
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
}

// A missing face must be fatal. Near-right artwork drawn in a substituted system face is the
// hardest kind of wrong to notice, and it would ship.
func font(_ name: String, _ size: CGFloat) -> NSFont {
    guard let font = NSFont(name: name, size: size) else {
        FileHandle.standardError.write(Data("render_dmg_background: font \(name) did not register from \(fontPath)\n".utf8))
        exit(1)
    }
    return font
}

/// AppKit's origin is bottom-left; every layout number in this file is measured from the top.
func fromTop(_ y: CGFloat) -> CGFloat { HEIGHT - y }

func draw(scale: CGFloat) -> NSBitmapImageRep {
    let pixelsWide = Int(WIDTH * scale), pixelsHigh = Int(HEIGHT * scale)
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixelsWide, pixelsHigh: pixelsHigh,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
        FileHandle.standardError.write(Data("render_dmg_background: could not allocate the bitmap\n".utf8))
        exit(1)
    }
    rep.size = NSSize(width: WIDTH, height: HEIGHT)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    palette.ground.setFill()
    NSRect(x: 0, y: 0, width: WIDTH, height: HEIGHT).fill()

    // A soft accent bloom centred on the icon row, so the eye lands on the gesture before the text.
    if let gradient = NSGradient(colors: [palette.accent.withAlphaComponent(theme == "dark" ? 0.13 : 0.10),
                                          palette.accent.withAlphaComponent(0)]) {
        gradient.draw(in: NSRect(x: WIDTH / 2 - 300, y: fromTop(ICON_ROW_CENTER_Y) - 190,
                                 width: 600, height: 380), relativeCenterPosition: .zero)
    }

    func text(_ string: String, _ nsFont: NSFont, _ color: NSColor, topY: CGFloat) {
        let style = NSMutableParagraphStyle(); style.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [.font: nsFont, .foregroundColor: color, .paragraphStyle: style]
        let size = string.size(withAttributes: attributes)
        string.draw(in: NSRect(x: 0, y: fromTop(topY) - size.height, width: WIDTH, height: size.height),
                    withAttributes: attributes)
    }

    text("UnfoldMyMac", font("SpaceGrotesk-Bold", 34), palette.title, topY: 74)
    text("Drag UnfoldMyMac into your Applications folder",
         font("SpaceGrotesk-Regular", 14), palette.subtitle, topY: 122)

    // The arrow is the only graphic, and that is deliberate. Anything else in this band competes
    // with the two real Finder icons, which the artwork cannot see and cannot lay out around.
    // Both endpoints are derived from the same constants written into layout.plist, so the drawn
    // arrow and the positioned icons cannot drift apart.
    let shaftStart = NSPoint(x: APP_ICON_CENTER_X + 88, y: fromTop(ICON_ROW_CENTER_Y))
    let shaftEnd = NSPoint(x: APPLICATIONS_ICON_CENTER_X - 98, y: fromTop(ICON_ROW_CENTER_Y))
    let shaft = NSBezierPath()
    shaft.move(to: shaftStart); shaft.line(to: shaftEnd)
    shaft.lineWidth = 2.5; shaft.lineCapStyle = .round
    palette.accent.withAlphaComponent(0.75).setStroke()
    shaft.stroke()

    let head = NSBezierPath()
    head.move(to: NSPoint(x: shaftEnd.x + 16, y: shaftEnd.y))
    head.line(to: NSPoint(x: shaftEnd.x, y: shaftEnd.y + 9))
    head.line(to: NSPoint(x: shaftEnd.x, y: shaftEnd.y - 9))
    head.close()
    palette.accent.withAlphaComponent(0.95).setFill()
    head.fill()

    let footer = version.isEmpty ? "Apple silicon · macOS 26 or later"
                                 : "Version \(version) · Apple silicon · macOS 26 or later"
    text(footer, font("SpaceGrotesk-Medium", 11), palette.footer, topY: 380)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let outDirectory = URL(fileURLWithPath: outPath, isDirectory: true)
try FileManager.default.createDirectory(at: outDirectory, withIntermediateDirectories: true)

for (scale, name) in [(CGFloat(1), "background.png"), (CGFloat(2), "background@2x.png")] {
    guard let data = draw(scale: scale).representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write(Data("render_dmg_background: PNG encoding failed for \(name)\n".utf8))
        exit(1)
    }
    try data.write(to: outDirectory.appendingPathComponent(name))
}

let layout: [String: Any] = [
    "windowWidth": Int(WIDTH), "windowHeight": Int(HEIGHT), "iconSize": ICON_SIZE,
    "appIconCenterX": Int(APP_ICON_CENTER_X), "appIconCenterY": Int(ICON_ROW_CENTER_Y),
    "applicationsIconCenterX": Int(APPLICATIONS_ICON_CENTER_X), "applicationsIconCenterY": Int(ICON_ROW_CENTER_Y),
]
let plist = try PropertyListSerialization.data(fromPropertyList: layout, format: .xml, options: 0)
try plist.write(to: outDirectory.appendingPathComponent("layout.plist"))
