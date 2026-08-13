import SwiftUI

// ✅ AppDelegate 用于动态控制方向
class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.all  // 默认支持所有方向
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}

@main
struct srsApp: App {
    @StateObject private var appState = AppState()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // App 启动时执行一次
        // 🧪 测试AES加密
        AESUtils.testEncryption()
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}

// 根视图，根据应用状态显示不同界面
struct RootView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            switch appState.currentView {
            case .splash:
                SplashView()  // 🔥 启动页（显示 Ai，1秒后跳转登录）
            case .home:
                HomeView()
            case .monitorLogin:
                MonitorLoginView()
            case .content:
                ContentView()
}
        }
        .animation(.easeInOut(duration: 0.3), value: appState.currentView)
    }
}
