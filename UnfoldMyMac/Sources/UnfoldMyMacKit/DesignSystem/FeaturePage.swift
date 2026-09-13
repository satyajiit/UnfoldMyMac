import SwiftUI

/// The large heading scrolls with its feature. Once it leaves view, the native
/// toolbar carries a compact title and gives the content the window's height.
struct FeaturePage<Header: View, Content: View>: View {
    let title: String
    var onScroll: ((CGFloat) -> Void)? = nil
    @Palette private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var titleIsCollapsed = false
    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header()
                    .padding(.horizontal, 28).padding(.top, 8).padding(.bottom, 20)
                    .frame(maxWidth: 940, alignment: .leading)
                    .frame(maxWidth: .infinity)
                Divider().overlay(palette.ink.opacity(0.04))
                content()
                    .padding(.horizontal, 28).padding(.vertical, 24)
                    .frame(maxWidth: 940, alignment: .leading)
                    .frame(maxWidth: .infinity)
            }
            .coordinateSpace(name: "feature.content")
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            max(0, geometry.contentOffset.y + geometry.contentInsets.top)
        } action: { _, offset in
            titleIsCollapsed = offset > 48
            onScroll?(offset)
        }
        .scrollEdgeEffectHidden(true, for: .top)
        .clipped()
        .background(palette.canvas)
        .foregroundStyle(palette.ink)
        .toolbarBackgroundVisibility(titleIsCollapsed ? .visible : .hidden, for: .windowToolbar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(title)
                    .font(UnfoldMyMacType.headline)
                    .foregroundStyle(palette.ink)
                    .opacity(titleIsCollapsed ? 1 : 0)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: titleIsCollapsed)
                    .accessibilityHidden(!titleIsCollapsed)
                    .accessibilityAddTraits(.isHeader)
            }.sharedBackgroundVisibility(.hidden)
        }
    }
}
