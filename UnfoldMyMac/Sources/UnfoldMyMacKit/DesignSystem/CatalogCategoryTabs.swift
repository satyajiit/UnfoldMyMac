import SwiftUI

struct CatalogCategoryTabs: View {
    let categories: [String]
    var title: (String) -> String
    @Binding var selection: String?
    @Palette private var palette
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 20) {
                tab("All designs", id: nil)
                ForEach(categories, id: \.self) { tab(title($0), id: $0) }
            }
        }.scrollIndicators(.hidden).padding(.vertical, 12)
            .background(palette.canvas.padding(.horizontal, -28))
    }
    private func tab(_ title: String, id: String?) -> some View {
        Button { selection = id } label: {
            VStack(spacing: 8) {
                Text(title).font(UnfoldMyMacType.callout).fixedSize()
                Capsule().fill(selection == id ? palette.accent : .clear).frame(height: 3)
            }.foregroundStyle(selection == id ? palette.ink : palette.secondary)
        }.buttonStyle(.plain).accessibilityAddTraits(selection == id ? [.isSelected] : [])
            .accessibilityIdentifier("catalog.category.\(id ?? "all")")
    }
}
