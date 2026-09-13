import SwiftUI
import UnfoldMyMacCore

/// The update controls inside Settings' About card.
///
/// Part of that card rather than a fourth one: this is a control most people touch twice a year, and
/// it belongs next to the version it is talking about.
struct UpdateStatusRow: View {
    let model: UpdateModel
    @Palette private var palette
    @Environment(\.workspace) private var workspace

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(message).font(UnfoldMyMacType.callout)
                        .foregroundStyle(isProblem ? palette.ink : palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail { Text(detail).font(UnfoldMyMacType.caption).modifier(SecondaryTextStyle()) }
                }
                Spacer(minLength: 8)
                if model.state.isBusy { ProgressView().controlSize(.small) }
                action
            }
            if case .unsupported = model.state {} else {
                Toggle("Check for updates automatically", isOn: Binding(
                    get: { model.preferences.automaticChecks },
                    set: { model.setAutomaticChecks($0) }))
                    .toggleStyle(.switch).font(UnfoldMyMacType.callout)
                    .accessibilityIdentifier("settings.updates.automatic")
            }
        }
        .accessibilityIdentifier("settings.updates")
    }

    @ViewBuilder private var action: some View {
        switch model.state {
        case .unsupported:
            Button("Check on GitHub") {
                if let url = URL(string: AppIdentity.latestReleasePage) { workspace.open(url) }
            }.buttonStyle(.link).accessibilityIdentifier("settings.updates.github")
        case .available:
            Button("Update…") { model.showPrompt() }
                .modifier(UnfoldMyMacButtonStyle(prominent: true))
                .accessibilityIdentifier("settings.updates.install")
        case .readyToRelaunch:
            Button("Relaunch") { model.relaunch() }
                .modifier(UnfoldMyMacButtonStyle(prominent: true))
                .accessibilityIdentifier("settings.updates.relaunch")
        case .downloading, .verifying:
            Button("Show Progress") { model.showPrompt() }.modifier(UnfoldMyMacButtonStyle())
        case .checking:
            Button("Check Now") {}.modifier(UnfoldMyMacButtonStyle()).disabled(true)
        case .failed(let failure) where failure.error.suggestsManualDownload:
            Button("Get It from GitHub") {
                if let url = URL(string: AppIdentity.latestReleasePage) { workspace.open(url) }
            }.modifier(UnfoldMyMacButtonStyle()).accessibilityIdentifier("settings.updates.manual")
        case .failed:
            Button("Try Again") { model.checkNow(.manual) }.modifier(UnfoldMyMacButtonStyle())
        default:
            Button("Check Now") { model.checkNow(.manual) }
                .modifier(UnfoldMyMacButtonStyle())
                .accessibilityIdentifier("settings.updates.check")
        }
    }

    private var message: String {
        switch model.state {
        case .unsupported(let block): block.message
        case .checking: "Checking…"
        case .upToDate(let version, _): "\(AppIdentity.name) \(version) is the latest version."
        case .available(let release): "Version \(release.version) is available."
        case .downloading(let release, _, _): "Downloading version \(release.version)…"
        case .verifying(let release): "Checking version \(release.version)…"
        case .readyToRelaunch(let release, _): "Version \(release.version) is ready to install."
        case .failed(let failure): failure.message
        case .idle:
            model.preferences.lastCheck == nil
                ? "Checks for updates automatically."
                : "Last checked \(model.preferences.lastCheck!.formatted(.relative(presentation: .named)))."
        }
    }

    private var detail: String? {
        guard case .available(let release) = model.state else { return nil }
        var parts: [String] = []
        if let published = release.publishedAt { parts.append("Released \(published.formatted(date: .abbreviated, time: .omitted))") }
        if release.assetSize > 0 { parts.append(release.assetSize.formatted(.byteCount(style: .file))) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var isProblem: Bool {
        switch model.state {
        case .failed, .unsupported: true
        default: false
        }
    }
}
