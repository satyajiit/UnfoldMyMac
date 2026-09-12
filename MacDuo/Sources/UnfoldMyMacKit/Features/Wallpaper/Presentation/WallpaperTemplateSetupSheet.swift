import SwiftUI
import UnfoldMyMacCore

struct WallpaperTemplateSetupSheet: View {
    @Bindable var setup: WallpaperSetupController
    let request: WallpaperSetupRequest
    @State private var formHeight: CGFloat = 420
    private var maximumFormHeight: CGFloat { max(240, min(540, (NSScreen.main?.visibleFrame.height ?? 900)-240)) }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeading(title: request.template.title, subtitle: "Connections and settings for this wallpaper.")
            ScrollView {
              VStack(alignment: .leading, spacing: 22) {
               ForEach(request.template.setup ?? []) { requirement in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(requirement.kind.title).font(UnfoldMyMacType.title3)
                        Spacer()
                        Text(requirement.required ? "Required" : "Optional").font(UnfoldMyMacType.caption).modifier(SecondaryTextStyle())
                    }
                    connector(requirement.kind)
                }
                Divider()
               }
              }.onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { formHeight = $0 }
            }
            .frame(height: min(formHeight, maximumFormHeight))
            .scrollBounceBehavior(.basedOnSize)
            HStack {
                Button("Cancel") { setup.cancel() }.keyboardShortcut(.cancelAction).modifier(UnfoldMyMacButtonStyle())
                Spacer()
                Button(request.applyAfterSetup ? "Use wallpaper" : "Save changes") { setup.finish() }
                    .modifier(UnfoldMyMacButtonStyle(prominent: true))
                    .disabled(request.applyAfterSetup && !setup.draftReady)
                    .accessibilityIdentifier("wallpaper.setup.finish")
            }
        }.padding(28).frame(width: 552).fixedSize(horizontal: false, vertical: true)
            .font(UnfoldMyMacType.body)
    }
    @ViewBuilder private func connector(_ kind: WallpaperSetupRequirement.Kind) -> some View {
        let connection = Binding(get: { setup.draft[kind.rawValue] ?? .init() }, set: { setup.draft[kind.rawValue] = $0 })
        switch kind {
        case .githubProfile: GitHubProfileSetup(connection: connection)
        case .codexActivity: CodexActivitySetup(connection: connection)
        default: WallpaperLocalConnectionSetup(kind: kind, connection: connection)
        }
    }
}

extension WallpaperSetupRequirement.Kind {
    var title: String {
        switch self {
        case .githubProfile: "GitHub profile"
        case .codexActivity: "Codex live activity"
        case .codexHistory: "Codex usage"
        case .claudeCode: "Claude Code"
        case .toolFile: "Your tool feed"
        }
    }
}
