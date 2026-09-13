import SwiftUI
import UnfoldMyMacCore

struct ContentAuthorRow: View {
    let author: ContentAuthor
    var logoURL: URL? = nil
    @Environment(\.workspace) private var workspace
    @Palette private var palette

    var body: some View {
        HStack(spacing: 10) {
            if let logoURL = logoURL ?? author.logo.flatMap(BundleResources.contentMark) {
                EffectCover(url: logoURL, contentMode: .fit).frame(width: 32, height: 32).clipShape(.rect(cornerRadius: 8))
            } else {
                Image(systemName: "person.crop.circle").font(.title2).foregroundStyle(palette.secondary)
                    .frame(width: 32, height: 32)
            }
            VStack(alignment: .leading, spacing: 3) {
                if let url = author.publicURL {
                    Button { workspace.open(url) } label: {
                        Label(author.name, systemImage: "arrow.up.right").labelStyle(.titleAndIcon)
                    }.buttonStyle(.plain).foregroundStyle(palette.accent)
                        .help(url.absoluteString).accessibilityLabel("Visit \(author.name)")
                } else { Text(author.name) }
                if let role = author.role { Text(role).font(UnfoldMyMacType.caption).foregroundStyle(palette.secondary) }
            }
        }.font(UnfoldMyMacType.callout)
    }
}
