import SwiftUI
import UnfoldMyMacCore

struct PageHeading: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(UnfoldMyMacType.title).accessibilityAddTraits(.isHeader)
            Text(subtitle).font(UnfoldMyMacType.body).modifier(SecondaryTextStyle())
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
