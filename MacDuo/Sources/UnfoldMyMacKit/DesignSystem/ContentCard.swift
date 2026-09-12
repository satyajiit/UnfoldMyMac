import SwiftUI
import UnfoldMyMacCore

struct ContentCard<Content: View>: View {
    @Palette private var palette
    @Environment(\.colorSchemeContrast) private var contrast
    @ViewBuilder var content: () -> Content
    var body: some View {
        content().padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.card, in: .rect(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(palette.ink.opacity(contrast == .increased ? 0.55 : 0.08), lineWidth: 1) }
    }
}
