import SwiftUI
import UnfoldMyMacCore

/// The open-source asks, at the foot of the sidebar above Settings. Kept to three caption-weight
/// rows because the sidebar is 180 points wide at its minimum; anything card-shaped clips there.
struct SidebarSupport: View {
    @Environment(\.workspace) private var workspace
    @Palette private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Open source")
                .font(UnfoldMyMacType.caption)
                .foregroundStyle(palette.secondary)
                .padding(.horizontal, 12).padding(.bottom, 3)
                .accessibilityAddTraits(.isHeader)
            row("Star on GitHub", icon: .star, link: AppIdentity.repository, id: "sidebar.star")
            row("Contribute", icon: .contribute, link: AppIdentity.contributing, id: "sidebar.contribute")
            row("Report a bug", icon: .reportIssue, link: AppIdentity.newIssue, id: "sidebar.report")
        }
        .padding(.vertical, 6)
    }

    private func row(_ title: String, icon: UnfoldMyMacIcon, link: String, id: String) -> some View {
        Button { if let url = URL(string: link) { workspace.open(url) } } label: {
            HStack(spacing: 6) {
                Label(title, icon: icon).labelStyle(.titleAndIcon).lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: UnfoldMyMacIcon.externalLink.rawValue)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(palette.secondary)
            }
            .font(UnfoldMyMacType.caption)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .foregroundStyle(palette.ink)
        .accessibilityIdentifier(id)
        .accessibilityLabel("\(title). Opens in your browser.")
    }
}
