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

/// Signed-in container. On iPhone (compact) the dashboard is the root of a
/// NavigationStack; on iPad (regular) it becomes a NavigationSplitView. Account is
/// presented as a sheet in both modes.
struct MainView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        @Bindable var model = model
        Group {
            if hSize == .regular {
                MainSplitView()
            } else {
                NavigationStack {
                    DashboardView()
                }
            }
        }
        .sheet(isPresented: $model.showAccount) {
            AccountView()
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $model.showAddDevice) {
            AddDeviceView()
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $model.showHelp) {
            HelpSupportView()
                .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    RootView()
}
