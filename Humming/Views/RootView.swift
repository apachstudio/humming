import SwiftUI

struct RootView: View {
    @State private var hasOnboarded = false
    @StateObject private var store = HumStore()

    var body: some View {
        Group {
            if hasOnboarded {
                HomeView()
                    .transition(.opacity)
            } else {
                OnboardingView {
                    withAnimation(.easeOut(duration: 0.3)) {
                        hasOnboarded = true
                    }
                }
                .transition(.opacity)
            }
        }
        .environmentObject(store)
    }
}

#Preview {
    RootView()
}
