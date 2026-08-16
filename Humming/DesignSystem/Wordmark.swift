import SwiftUI

/// Renders the "humming" brand wordmark from the Figma SVG asset.
/// Pass progress 0→1 to animate a left-to-right reveal for the onboarding splash.
struct WordmarkView: View {
    var progress: CGFloat = 1

    var body: some View {
        Image("humming-wordmark")
            .resizable()
            .scaledToFit()
            .mask(
                GeometryReader { proxy in
                    Rectangle()
                        .frame(
                            width: proxy.size.width * max(0, min(1, progress)),
                            height: proxy.size.height
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
            )
    }
}

#Preview {
    ZStack {
        HumTheme.charcoal.ignoresSafeArea()
        WordmarkView()
            .frame(width: 200)
    }
}
