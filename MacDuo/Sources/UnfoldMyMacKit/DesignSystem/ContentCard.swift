import SwiftUI
import UnfoldMyMacCore

struct ContentCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    @ViewBuilder var content: () -> Content
    var body: some View {
        let p = UnfoldMyMacPalette(dark: scheme == .dark)
        content().padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(p.card, in: .rect(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(p.ink.opacity(contrast == .increased ? 0.55 : 0.08), lineWidth: 1) }
    }
}
