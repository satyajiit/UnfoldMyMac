import SwiftUI

struct WallpaperWorkshopSetup: View {
    @Binding var connection: WallpaperConnectionSettings

    var body: some View {
        Toggle("Show live counts", isOn: Binding(get: { connection.showsLiveCounts }, set: { connection.liveCounts = $0 }))
            .accessibilityIdentifier("workshop.counts")
        Toggle("Motivating lines", isOn: Binding(get: { connection.showsWorkshopLines }, set: { connection.oneLiners = $0 }))
            .accessibilityIdentifier("workshop.lines")
        Toggle("Pointer parallax", isOn: Binding(get: { connection.pointerParallax }, set: { connection.parallax = $0 }))
            .accessibilityIdentifier("workshop.parallax")
        Toggle("Mirror the workshop", isOn: Binding(get: { connection.mirrorsComposition }, set: { connection.mirrored = $0 }))
            .accessibilityIdentifier("workshop.mirror")
        Text("Open apps light the tool stations. Gentle lines fade every 45 seconds. Finder, this app and background helpers are excluded from the count.")
            .font(UnfoldMyMacType.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}
