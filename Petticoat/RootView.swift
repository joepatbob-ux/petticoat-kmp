import SwiftUI

struct RootView: View {
    @State private var model = AppModel()

    var body: some View {
        ZStack {
            switch model.route {
            case .splash:
                SplashView()
                    .transition(.opacity)
            case .login:
                LoginView()
                    .transition(.opacity)
            case .main:
                MainView()
                    .transition(.opacity)
            }
        }
        .environment(model)
    }
}

/// Signed-in container: Dashboard is the root, Account is presented as a sheet.
struct MainView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            DashboardView()
        }
        .sheet(isPresented: $model.showAccount) {
            AccountView()
        }
    }
}

#Preview {
    RootView()
}
