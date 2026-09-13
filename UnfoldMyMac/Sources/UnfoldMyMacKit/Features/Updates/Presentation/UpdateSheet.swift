import SwiftUI
import UnfoldMyMacCore

/// The update conversation, from "there is a new version" to "relaunch to finish".
///
/// Every state shares one header and one reserved progress strip, so downloading does not resize the
/// sheet or push the notes away — the user can keep reading what they are installing while it
/// installs.
struct UpdateSheet: View {
    let model: UpdateModel
    @Palette private var palette
    @Environment(\.workspace) private var workspace

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            UpdateReleaseNotes(notes: model.state.release?.notes ?? "")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            progress.frame(height: 44).padding(.horizontal, 24)
            Divider()
            footer
        }
        .frame(width: 640, height: min(580, max(420, (NSScreen.main?.visibleFrame.height ?? 900) - 120)))
        .background(Color(nsColor: .windowBackgroundColor))
        .font(UnfoldMyMacType.body)
    }

    private var header: some View {
        HStack(spacing: 12) {
            BrandMark(size: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(UnfoldMyMacType.title2)
                Text(subtitle).font(UnfoldMyMacType.callout).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if let badge = model.state.badge {
                ContentBadge(title: badge, highlighted: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 16)
    }

    @ViewBuilder private var progress: some View {
        switch model.state {
        case .downloading(_, let received, let total):
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: total > 0 ? Double(received) / Double(total) : 0)
                    .accessibilityIdentifier("updates.progress")
                Text(total > 0 ? "\(received.formatted(.byteCount(style: .file))) of \(total.formatted(.byteCount(style: .file)))"
                               : received.formatted(.byteCount(style: .file)))
                    .font(UnfoldMyMacType.caption).foregroundStyle(.secondary)
            }.frame(maxHeight: .infinity)
        case .verifying:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Checking the signature and the checksum.")
                    .font(UnfoldMyMacType.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
        default:
            Color.clear
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text(caption).font(UnfoldMyMacType.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if case .available = model.state {
                Button("Skip This Version") { model.skipThisVersion() }
                    .buttonStyle(.link).accessibilityIdentifier("updates.sheet.skip")
            }
            Spacer(minLength: 8)
            buttons
        }
        .controlSize(.large)
        .padding(.horizontal, 24).padding(.vertical, 16)
    }

    @ViewBuilder private var buttons: some View {
        switch model.state {
        case .available:
            Button("Remind Me Later") { model.remindLater() }
                .keyboardShortcut(.cancelAction).buttonStyle(.bordered)
                .accessibilityIdentifier("updates.sheet.later")
            Button("Update Now") { model.beginDownload() }
                .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
                .accessibilityIdentifier("updates.sheet.update")
        case .downloading:
            Button("Cancel") { model.cancelDownload() }
                .keyboardShortcut(.cancelAction).buttonStyle(.bordered)
                .accessibilityIdentifier("updates.sheet.cancel")
        case .verifying:
            Button("Cancel") {}.buttonStyle(.bordered).disabled(true)
        case .readyToRelaunch:
            Button("Later") { model.dismissPrompt() }
                .keyboardShortcut(.cancelAction).buttonStyle(.bordered)
            Button("Relaunch Now") { model.relaunch() }
                .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
                .accessibilityIdentifier("updates.sheet.relaunch")
        default:
            Button("Close") { model.dismissPrompt() }
                .keyboardShortcut(.cancelAction).buttonStyle(.bordered)
            if case .failed(let failure) = model.state {
                if failure.error.suggestsManualDownload {
                    // Retrying would fail the same way; the release page is the way through.
                    Button("Get It from GitHub") { openReleases() }
                        .buttonStyle(.borderedProminent).accessibilityIdentifier("updates.sheet.manual")
                } else {
                    Button("Try Again") { model.checkNow(.manual) }
                        .buttonStyle(.borderedProminent).accessibilityIdentifier("updates.sheet.retry")
                }
            }
        }
    }

    private func openReleases() {
        if let url = URL(string: AppIdentity.latestReleasePage) { workspace.open(url) }
    }

    private var title: String {
        guard let release = model.state.release else { return "\(AppIdentity.name) Update" }
        return "\(AppIdentity.name) \(release.version)"
    }

    private var subtitle: String {
        guard let release = model.state.release else { return "You are on version \(model.currentVersion)." }
        var parts = ["Version \(release.version)"]
        if release.assetSize > 0 { parts.append(release.assetSize.formatted(.byteCount(style: .file))) }
        if let published = release.publishedAt {
            parts.append("Released \(published.formatted(date: .abbreviated, time: .omitted))")
        }
        return parts.joined(separator: " · ")
    }

    private var caption: String {
        switch model.state {
        case .available: "You are on \(model.currentVersion). This downloads over your network."
        case .downloading: "Downloading…"
        case .verifying: "Making sure this really came from us."
        case .readyToRelaunch: "\(AppIdentity.name) will quit and reopen. Nothing else closes."
        case .failed(let failure): failure.message
        default: ""
        }
    }
}
