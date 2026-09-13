import SwiftUI
import UnfoldMyMacCore

struct EffectInspectorAbout: View {
    let effect: EffectDescriptor
    @Palette private var palette
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                EffectCover(url: effect.coverURL, contentMode: .fit).frame(height: 160).clipShape(.rect(cornerRadius: 12))
                Text("Cover artwork · Preview renders the real effect").font(UnfoldMyMacType.caption).foregroundStyle(palette.secondary)
                ContentDescription(overview: effect.metadata?.overview ?? effect.detail, sections: effect.metadata?.sections ?? [])
                ContentFlowLayout { ForEach(effect.tags, id: \.self) { ContentBadge(title: $0) } }
                Divider()
                Text("Created by").font(UnfoldMyMacType.headline)
                ForEach(Array(effect.contentAuthors.enumerated()), id: \.offset) { _, author in ContentAuthorRow(author: author) }
                if !effect.credit.isEmpty { Text(effect.credit).font(UnfoldMyMacType.caption).foregroundStyle(palette.secondary) }
                Label(effect.requiresCapture ? "Uses Screen Recording. Frames stay on this Mac." : "No Screen Recording permission needed.", systemImage: "hand.raised")
                    .font(UnfoldMyMacType.caption).foregroundStyle(palette.secondary)
            }.padding(24)
        }
    }
}
