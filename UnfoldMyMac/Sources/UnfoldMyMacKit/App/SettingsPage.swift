import SwiftUI
import UnfoldMyMacCore

/// Preferences shared by every feature belong here.
struct SettingsPage: View {
    @Bindable var model: EffectsModel
    let updates: UpdateModel
    @Environment(\.appInfo) private var appInfo
    @Environment(\.workspace) private var workspace
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
                Divider()
                UpdateStatusRow(model: updates)
                Divider()
                Text("Closing the window keeps the app in your Dock and menu bar. Click its Dock icon to reopen it, or choose Quit from the app menu to exit.")
                    .font(UnfoldMyMacType.callout).modifier(SecondaryTextStyle()).fixedSize(horizontal: false, vertical: true)
                Divider()
                Text("\(AppIdentity.name) is free and open source under Apache-2.0. Stars and bug reports both help.")
                    .font(UnfoldMyMacType.callout).modifier(SecondaryTextStyle()).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    link("Star on GitHub", icon: .star, to: AppIdentity.repository, id: "about.star")
                    link("Contribute", icon: .contribute, to: AppIdentity.contributing, id: "about.contribute")
                    link("Report a bug", icon: .reportIssue, to: AppIdentity.newIssue, id: "about.report")
                    link("Website", icon: .website, to: AppIdentity.website, id: "about.website")
                }
            }
        }
    }

    private func link(_ title: String, icon: UnfoldMyMacIcon, to address: String, id: String) -> some View {
        Button { if let url = URL(string: address) { workspace.open(url) } } label: {
            Label(title, icon: icon).font(UnfoldMyMacType.callout)
        }
        .buttonStyle(.link)
        .accessibilityIdentifier(id)
        .accessibilityLabel("\(title). Opens in your browser.")
    }
}
