//
//  AppState.swift
//  srs
//
//  Created by 陈源 on 8/30/25.
//

import SwiftUI
import Combine

// 定义应用的导航状态
enum AppView {
    case splash            // SplashView - 启动页（显示 Ai Logo）
    case home              // HomeView - 首页（暂不使用）
    case monitorLogin      // MonitorLoginView - 监控端登录
    case content           // ContentView - 推流页面
}

class AppState: ObservableObject {
    @Published var currentView: AppView = .splash  // 🔥 启动时显示 Splash 页面
    @Published var isLoggedIn: Bool = false
    @Published var permanentToken: String = ""
    
    init() {
        checkLoginStatus()
    }
    
    // 从 Splash 跳转到登录页
    func navigateToLogin() {
        currentView = .monitorLogin
    }
    
    private func checkLoginStatus() {
        if let token = UserDefaults.standard.string(forKey: "permanent_token"), !token.isEmpty {
            self.permanentToken = token
            self.isLoggedIn = true
            // 注意：不自动跳转，保持现有导航逻辑
        }
    }
    
    // 导航方法
    func navigateToMonitorLogin() {
        currentView = .monitorLogin
    }
    
    func navigateToContent() {
        currentView = .content
    }
    
    func navigateBack() {
        switch currentView {
        case .splash:
            break // Splash 页面不需要返回
        case .monitorLogin:
            currentView = .splash  // 登录页返回到 Splash（重新显示启动页）
        case .content:
            currentView = .monitorLogin
        case .home:
            break // 已经在首页
}
    }
    
    // 登录成功处理
    func loginSuccess(token: String) {
        self.permanentToken = token
        self.isLoggedIn = true
        UserDefaults.standard.set(token, forKey: "permanent_token")
        
        // 登录成功后跳转到推流页面
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.navigateToContent()
        }
    }
    
    // 登出处理
    func logout() {
        self.isLoggedIn = false
        self.permanentToken = ""
        UserDefaults.standard.removeObject(forKey: "permanent_token")
        // 登出后返回首页
        currentView = .home
    }
}
