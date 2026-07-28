import SwiftUI

struct SplashView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            SMA.background.ignoresSafeArea()

            Image("SensiByCopeland")
                .resizable()
                .scaledToFit()
                .frame(width: 240)
                .accessibilityLabel("Sensi by Copeland")
        }
        .task {
            try? await Task.sleep(for: .seconds(0.6))
            model.route = .login
        }
    }
}

#Preview {
    SplashView()
        .environment(AppModel())
}
