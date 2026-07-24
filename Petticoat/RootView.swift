import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
        // Drive the whole window's interface style so the appearance choice also
        // applies to presented sheets (which don't follow a preferredColorScheme
        // set on the presenter once they're open).
        .onChange(of: model.appearance, initial: true) { _, appearance in
            applyAppearance(appearance)
        }
    }

    private func applyAppearance(_ appearance: AppAppearance) {
        #if canImport(UIKit)
        let style: UIUserInterfaceStyle = switch appearance {
        case .light:  .light
        case .dark:   .dark
        case .system: .unspecified
        }
        for scene in UIApplication.shared.connectedScenes {
            (scene as? UIWindowScene)?.windows.forEach { $0.overrideUserInterfaceStyle = style }
        }
        #endif
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
