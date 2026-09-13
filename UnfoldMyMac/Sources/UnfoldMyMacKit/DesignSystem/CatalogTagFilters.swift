import SwiftUI

/// Visible, keyboard-accessible single-select tags, with a persistent reset choice.
struct CatalogTagFilters: View {
    let tags: [String]
    @Binding var selection: String?
    var allTitle = "All tags"
    @Palette private var palette

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 7) {
                chip(allTitle, value: nil)
                ForEach(tags, id: \.self) { chip($0, value: $0) }
            }.padding(.vertical, 3)
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Filter by tag")
    }

    private func chip(_ title: String, value: String?) -> some View {
        Button { selection = value } label: {
            HStack(spacing: 5) {
                if selection == value { Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)) }
                Text(title)
            }
            .font(UnfoldMyMacType.caption)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .foregroundStyle(selection == value ? palette.accent : palette.secondary)
            .background(selection == value ? palette.accent.opacity(0.12) : palette.card, in: .capsule)
            .overlay { Capsule().strokeBorder(selection == value ? palette.accent.opacity(0.55) : palette.ink.opacity(0.12)) }
        }
        .buttonStyle(.plain).fixedSize()
        .accessibilityAddTraits(selection == value ? [.isSelected] : [])
        .accessibilityIdentifier("catalog.tag.\(value ?? "all")")
    }
}
