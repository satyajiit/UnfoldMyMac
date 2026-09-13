import SwiftUI

struct ContentBadge: View {
    let title: String
    var symbol: String? = nil
    var highlighted = false
    var selected = false
    @Palette private var palette

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).accessibilityHidden(true) }
            Text(title)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(selected ? palette.card : highlighted ? palette.accent : palette.secondary)
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(selected ? palette.ink : highlighted ? palette.accent.opacity(0.1) : palette.ink.opacity(0.06), in: .capsule)
        .fixedSize()
    }
}
