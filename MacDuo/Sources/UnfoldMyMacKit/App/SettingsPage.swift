import SwiftUI
import UnfoldMyMacCore

/// Preferences shared by every feature belong here.
struct SettingsPage: View {
    @Bindable var model: EffectsModel
    @Environment(\.appInfo) private var appInfo
    var body: some View {
        FeaturePage(title: "Settings") {
            PageHeading(title: "Settings", subtitle: "Make \(AppIdentity.name) feel at home on your Mac.")
        } content: {
            VStack(alignment: .leading, spacing: 20) {
                appearance
                accessibility
                about
            }
        }
    }

    private var appearance: some View {
        ContentCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Appearance").font(UnfoldMyMacType.headline)
                Picker("Theme", selection: Binding(get: { model.settings.appearance }, set: { model.setAppearance($0) })) {
                    ForEach(AppearancePreference.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }.pickerStyle(.segmented).accessibilityIdentifier("settings.appearance")
                Text("Choose a look, or follow your Mac’s appearance.")
                    .font(UnfoldMyMacType.callout).modifier(SecondaryTextStyle())
            }
        }
    }

    private var accessibility: some View {
        ContentCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Accessibility", icon: .accessibility).font(UnfoldMyMacType.headline)
                LabeledContent("Reduce Motion", value: model.reduceMotion ? "On" : "Off")
                LabeledContent("Reduce Transparency", value: model.reduceTransparency ? "On" : "Off")
                Text("These preferences follow your macOS accessibility settings.")
                    .font(UnfoldMyMacType.callout).modifier(SecondaryTextStyle())
            }
        }
    }

    private var about: some View {
        ContentCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    BrandMark(size: 36)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(AppIdentity.name).font(UnfoldMyMacType.headline)
                        Text("Version \(appInfo.version) · Made for macOS")
                            .font(UnfoldMyMacType.caption).modifier(SecondaryTextStyle())
                    }
                }
                Text("Closing the window keeps the app in your Dock and menu bar. Click its Dock icon to reopen it, or choose Quit from the app menu to exit.")
                    .font(UnfoldMyMacType.callout).modifier(SecondaryTextStyle()).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
