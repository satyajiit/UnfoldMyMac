import SwiftUI

struct CatalogSearchField: View {
    @Binding var query: String
    var identifier = "catalog.search"
    @Palette private var palette

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(palette.secondary)
            TextField("Search designs, creators, or features", text: $query)
                .textFieldStyle(.plain).accessibilityIdentifier(identifier)
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).accessibilityLabel("Clear search")
            }
        }
        .padding(10).background(palette.card, in: .rect(cornerRadius: 10))
        .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(palette.ink.opacity(0.12)) }
    }
}
