import SwiftUI
import UnfoldMyMacCore

/// Native text over physical scenes, shared by the preview and every desktop surface.
struct WallpaperSceneOverlay: View {
    let template: WallpaperTemplate
    let snapshot: WallpaperSnapshot
    let inputs: WallpaperInputService?

    var body: some View {
        if let inputs {
            if template.id == "hinge-garden" { WallpaperGardenQuote(inputs: inputs) }
            if template.id == "the-workshop", inputs.showsWorkshopCounts || inputs.workshopQuote != nil {
                GeometryReader { geometry in
                    VStack(spacing: 7) {
                        if let quote = inputs.workshopQuote {
                            Text(quote.text)
                                .font(.system(size: max(14, min(28, geometry.size.width * 0.018)), design: .serif))
                                .lineLimit(1).minimumScaleFactor(0.8)
                                .opacity(quote.opacity)
                                .accessibilityIdentifier("workshop.motivating-line")
                        } else {
                            Text("THE WORKSHOP").font(.system(size: max(10, min(12, geometry.size.width * 0.009)), weight: .medium))
                                .tracking(3)
                        }
                        if inputs.showsWorkshopCounts {
                            Text(caption).font(.system(size: max(11, min(15, geometry.size.width * 0.011))))
                                .monospacedDigit().accessibilityIdentifier("workshop.live-counts")
                        }
                    }
                    .foregroundStyle(Color(red: 0.28, green: 0.30, blue: 0.25))
                    .frame(width: geometry.size.width * 0.9)
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.895)
                }
            }
        }
    }

    private var caption: String {
        var parts: [String] = []
        if let apps = snapshot.number("apps.count") { parts.append("\(Int(apps)) \(apps == 1 ? "app" : "apps") open") }
        if let items = snapshot.number("desktop.items") { parts.append("\(Int(items)) \(items == 1 ? "item" : "items") on the shelves") }
        return parts.isEmpty ? "A little room to make things." : parts.joined(separator: "  ·  ")
    }
}
