import SwiftUI
import UnfoldMyMacCore

/// Renders a release's notes.
///
/// The text comes from a release description, so it is treated as untrusted input: truncated before
/// parsing, stripped of image syntax so nothing is fetched, capped in length, and rendered a line at
/// a time with `.inlineOnlyPreservingWhitespace` — the same call `ContentDescription` uses, because
/// the full syntax turns headings and bullets into presentation intents that `Text` draws without
/// their markers. Links go through the same https-only guard used everywhere else.
struct UpdateReleaseNotes: View {
    let notes: String
    var byteLimit = 16_384
    var lineLimit = 200
    @Palette private var palette
    @Environment(\.workspace) private var workspace

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if lines.isEmpty {
                    Text("Release notes for this version are on GitHub.")
                        .font(UnfoldMyMacType.callout).modifier(SecondaryTextStyle())
                } else {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in row(line) }
                    if truncated {
                        Button("Read the full notes on GitHub") {
                            if let url = URL(string: AppIdentity.latestReleasePage) { workspace.open(url) }
                        }
                        .buttonStyle(.link).font(UnfoldMyMacType.callout)
                        .accessibilityIdentifier("updates.notes.more")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24).padding(.vertical, 16)
        }
        .textSelection(.enabled)
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == "https", url.host != nil, url.user == nil, url.password == nil else { return .discarded }
            workspace.open(url)
            return .handled
        })
    }

    @ViewBuilder private func row(_ line: NoteLine) -> some View {
        switch line.kind {
        case .heading:
            Text(inline(line.text)).font(UnfoldMyMacType.headline)
                .foregroundStyle(palette.ink).padding(.top, 6)
        case .bullet:
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•").font(UnfoldMyMacType.body).foregroundStyle(palette.secondary)
                Text(inline(line.text)).font(UnfoldMyMacType.body).foregroundStyle(palette.secondary)
            }.fixedSize(horizontal: false, vertical: true)
        case .body:
            Text(inline(line.text)).font(UnfoldMyMacType.body)
                .foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func inline(_ value: String) -> AttributedString {
        (try? AttributedString(markdown: value, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(value)
    }

    private var parsed: (lines: [NoteLine], truncated: Bool) { UpdateNoteParser.parse(notes, byteLimit: byteLimit, lineLimit: lineLimit) }
    private var lines: [NoteLine] { parsed.lines }
    private var truncated: Bool { parsed.truncated }
}
