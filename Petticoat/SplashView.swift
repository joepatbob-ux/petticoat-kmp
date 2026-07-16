import SwiftUI

struct SplashView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [SMA.splashTop, SMA.splashBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            SensiLockup(
                wordmarkColor: .white,
                copelandColor: .white.opacity(0.85),
                size: 72
            )
        }
        .task {
            try? await Task.sleep(for: .seconds(1.8))
            model.route = .login
        }
    }
}

#Preview {
    SplashView()
        .environment(AppModel())
}
