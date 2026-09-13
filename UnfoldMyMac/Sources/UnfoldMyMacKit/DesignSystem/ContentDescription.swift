import SwiftUI
import UnfoldMyMacCore

struct ContentDescription: View {
    let overview: String
    var sections: [ContentSection] = []
    @Palette private var palette
    @Environment(\.workspace) private var workspace
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 9) {
                Text("About this design").font(UnfoldMyMacType.title3)
                markdown(overview)
            }
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.title).font(UnfoldMyMacType.headline)
                    markdown(section.body)
                }
            }
        }.textSelection(.enabled)
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == "https", url.host != nil, url.user == nil, url.password == nil else { return .discarded }
                workspace.open(url)
                return .handled
            })
    }
    private func markdown(_ value: String) -> some View {
        Text((try? AttributedString(markdown: value, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(value))
            .font(UnfoldMyMacType.body).foregroundStyle(palette.secondary)
            .lineSpacing(5).fixedSize(horizontal: false, vertical: true)
    }
}
