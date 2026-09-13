import SwiftUI

/// Native text stays crisp above the Metal miniature; only the short fade publishes at input cadence.
struct WallpaperGardenQuote: View {
    let inputs: WallpaperInputService
    var body: some View {
        if let quote = inputs.gardenQuote {
            GeometryReader { geometry in
                Text(quote.text)
                    .font(.system(size: min(42, max(17, geometry.size.width / 42)), weight: .regular, design: .serif))
                    .tracking(0.7)
                    .foregroundStyle(Color(red: 0.84, green: 0.87, blue: 0.81))
                    .multilineTextAlignment(.center).lineLimit(2)
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
                    .opacity(quote.opacity * 0.92)
                    .frame(width: geometry.size.width * 0.78)
                    .position(x: geometry.size.width*0.5, y: geometry.size.height*0.35)
                    .accessibilityIdentifier("wallpaper.garden.line")
            }.allowsHitTesting(false)
        }
    }
}
