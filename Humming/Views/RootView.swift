import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .results(let hum):
                        ResultsView(hum: hum)
                    case .library:
                        LibraryView()
                    case .detail(let id):
                        if let hum = model.hum(id: id) {
                            DetailView(hum: hum)
                        } else {
                            ContentUnavailableView(
                                "Hum not found",
                                systemImage: "waveform",
                                description: Text("This melody is no longer in your library.")
                            )
                        }
                    }
                }
        }
        .overlay {
            if model.showSplash {
                SplashView()
                    .transition(.opacity)
            }
        }
        .fullScreenCover(isPresented: $model.isRecording) {
            RecordingView()
                .environment(model)
        }
        .fullScreenCover(isPresented: $model.isProcessing) {
            ProcessingView()
        }
        .alert(
            "Humming",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation(.easeOut(duration: 0.35)) {
                    model.dismissSplash()
                }
            }
        }
    }
}
