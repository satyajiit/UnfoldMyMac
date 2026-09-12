import SwiftUI

struct WallpaperSettingsPage: View {
    @Bindable var model: WallpaperModel
    @Environment(\.filePicker) private var filePicker
    var body: some View {
        FeaturePage(title: "Playback settings") {
            PageHeading(title: "Playback settings", subtitle: "Motion and artwork shared by your wallpapers.")
        } content: {
            VStack(spacing: 18) {
                ContentCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Motion & energy", icon: .motion).font(UnfoldMyMacType.title3)
                        Picker("Frame rate", selection: Binding(get: { model.preferences.maximumFPS }, set: { model.setMaximumFPS($0) })) {
                            Text("Smooth · 60 fps").tag(60)
                            Text("Gentle · 30 fps").tag(30)
                        }.pickerStyle(.segmented).accessibilityIdentifier("wallpaper.fps")
                        Text("Automatically slows in Low Power Mode or under thermal pressure, and pauses when your display sleeps. Reduce Motion keeps a still scene with live data.")
                            .font(UnfoldMyMacType.callout).modifier(SecondaryTextStyle())
                        Text("Desktop playback uses all connected displays. Stopping reveals your existing wallpaper.")
                            .font(UnfoldMyMacType.callout).modifier(SecondaryTextStyle())
                    }
                }
                ContentCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Your art", icon: .image).font(UnfoldMyMacType.title3)
                        Text("Give image-based scenes a new background. Daydream adds motion, floating glass and stickers to your image.")
                            .modifier(SecondaryTextStyle())
                        HStack {
                            Button("Choose image…") { filePicker.pick(WallpaperFileRequests.background) { url in if let url { model.importBackground(url) } } }.modifier(UnfoldMyMacButtonStyle())
                            if model.preferences.customBackground {
                                Button("Use original art") { model.setCustomBackground(false) }.modifier(UnfoldMyMacButtonStyle())
                            }
                        }
                    }
                }
                Text("Profiles, logins and live data are configured from each wallpaper's Set up or Configure button.")
                    .font(UnfoldMyMacType.callout).modifier(SecondaryTextStyle())
                if let error = model.error { ErrorCard(message: error, needsPermission: false) }
            }
        }
    }
}
