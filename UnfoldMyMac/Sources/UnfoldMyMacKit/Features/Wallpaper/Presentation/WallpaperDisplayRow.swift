import SwiftUI

/// Says which display this scene is put on, and offers the choice of it.
///
/// There is exactly one entry — the primary display — and that is the point of showing the row at all.
/// The scene is composed for a single aspect ratio, so painting it across a built-in panel and an
/// ultrawide gives the second a layout nobody designed; until it can be laid out per display the app draws
/// on one screen and leaves the rest alone. A wallpaper app that silently skips a monitor reads as broken,
/// so the row says plainly what it does instead of leaving the user to notice.
struct WallpaperDisplayRow: View {
    let displays: [WallpaperBackdropScreen]
    @Palette private var palette

    var body: some View {
        if let target = displays.first {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    Text("Display").font(UnfoldMyMacType.callout)
                    // Constant on purpose: the selection exists to be shown, not changed. When a scene can
                    // be laid out per display this gains entries and a preference to hold the answer.
                    Picker("Display", selection: .constant(target.id)) {
                        ForEach(displays) { Text($0.name.isEmpty ? "This display" : $0.name).tag($0.id) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: 260)
                    .accessibilityIdentifier("wallpaper.display")
                }
                Text("Primary display only. Other displays keep the wallpaper you chose for them.")
                    .font(UnfoldMyMacType.caption).foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
