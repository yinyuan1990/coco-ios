import SwiftUI

// 监控端登录视图
struct MonitorLoginView: View {
    @EnvironmentObject var appState: AppState  // 添加这一行
    
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isPasswordVisible: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var showRegisterView: Bool = false
    @State private var hasLocalAccount: Bool = false
    
    @State private var isLoading: Bool = false
    @State private var isLoggedIn: Bool = false
    @State private var loginStep: LoginStep = .idle  // 新增：登录步骤状态
    
    @State private var showUserAgreement = false
    @State private var showPrivacyPolicy = false
        
    // 新增：登录步骤枚举
    enum LoginStep {
        case idle
        case authenticating    // 正在验证账号密码
        case connecting        // 正在连接WebSocket
        case success           // 登录成功
        case failed            // 登录失败
    }
    
    // 添加环境变量用于导航控制
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景图预留位置 - UI还没切
                // TODO: 替换为实际背景图
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.white]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 顶部关闭按钮
                    HStack {
                        Button(action: {
                            // TODO: 返回首页或关闭登录界面
                            //dismiss()
                            appState.navigateBack()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.gray)
                                .frame(width: 32, height: 32)
                                .background(Color.black.opacity(0.1))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    // 登录表单
                    VStack(spacing: 20) {
                        // 用户名输入框
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "person")
                                    .foregroundColor(.gray)
                                    .frame(width: 20)
                                Text("用户名")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            
                            TextField("请输入您的用户名", text: $username)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                                .background(hasLocalAccount ? Color.gray.opacity(0.15) : Color.gray.opacity(0.1))
                                .cornerRadius(12)
                                .font(.system(size: 16))
                                .foregroundColor(hasLocalAccount ? .gray : .primary)
                                .disabled(hasLocalAccount)  // 有本地账号时禁用输入
                        }
                        
                        // 密码输入框
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "lock")
                                    .foregroundColor(.gray)
                                    .frame(width: 20)
                                Text("密码")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            
                            HStack {
                                if isPasswordVisible {
                                    TextField("请输入您的密码", text: $password)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .font(.system(size: 16))
                                } else {
                                    SecureField("请输入您的密码", text: $password)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .font(.system(size: 16))
                                }
                                
                                Button(action: {
                                    isPasswordVisible.toggle()
                                }) {
                                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 16))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        // 登录按钮
                        Button(action: {
                            handleLogin()
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text(getLoginButtonText())
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isLoading ? Color.gray : Color.blue)
                                                .cornerRadius(12)
                        }
                        .disabled(isLoading)  // 加载时禁用按钮
                        .padding(.top, 10)
                        
                        // 注册链接 - 只有没有账号时才显示
                        if !hasLocalAccount {
                        HStack {
                            Text("没有账号？")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            Button(action: {
                                showRegisterView = true
                            }) {
                                Text("点击注册")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.top, 10)
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    Spacer()
                    
                    // 底部协议条款
                    VStack(spacing: 4) {
                        Text("登录/注册即表示您同意")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 4) {
                            Button(action: {
                                showUserAgreement = true
                            }) {
                                Text("《用户协议》")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                            }
                            
                            Text("和")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            
                            Button(action: {
                                showPrivacyPolicy = true
                            }) {
                                Text("《隐私政策》")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.bottom, 30)
                    .sheet(isPresented: $showUserAgreement) {
                        WebView(url: APIConfig.StaticPages.userAgreement, title: "用户协议", isLocal: true)
                    }
                    .sheet(isPresented: $showPrivacyPolicy) {
                        WebView(url: APIConfig.StaticPages.privacyPolicy, title: "隐私政策", isLocal: true)
                    }
                }
            }
            // 添加点击手势隐藏键盘
            .onTapGesture {
                hideKeyboard()
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadLocalAccountInfo()
            // 监听WebSocket连接状态
            setupWebSocketNotificationListener()
         }
        .onDisappear {
            // 移除通知监听
            NotificationCenter.default.removeObserver(self, name: .webSocketConnectionStateChanged, object: nil)
        }
        .sheet(isPresented: $showRegisterView, onDismiss: {
            // 🔥 sheet 关闭后重新加载本地账号信息
            // RegisterView 在 dismiss 前已经保存了账号信息到本地
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                loadLocalAccountInfo()
                print("📱 注册页面关闭，重新加载本地账号: hasLocalAccount=\(hasLocalAccount)")
            }
        }) {
            RegisterView(onRegisterSuccess: { registeredUsername, registeredPassword in
                // 🔥 注册成功后，先设置状态，再关闭 sheet
                print("✅ 注册成功回调: username=\(registeredUsername)")
                self.username = registeredUsername
                self.password = registeredPassword
                self.hasLocalAccount = true
            })
        }
        .alert("提示", isPresented: $showAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // 设置WebSocket通知监听
    // 设置WebSocket通知监听
    // 设置WebSocket通知监听
    private func setupWebSocketNotificationListener() {
        // 监听 STOMP 连接状态变化
        NotificationCenter.default.addObserver(
            forName: .webSocketConnectionStateChanged,
            object: nil,
            queue: .main
        ) { notification in
            print("🔔 收到STOMP连接状态变化通知")
            
            // 获取连接状态
            if let connectionStateRaw = notification.userInfo?["connectionState"] as? String,
               let connectionState = ConnectionState(rawValue: connectionStateRaw) {
                
                switch connectionState {
                case .connected:
                    print("✅ STOMP连接成功")
                    
                    // 只在连接阶段处理状态变化
                    if loginStep == .connecting {
                        print("✅ STOMP连接成功，更新登录状态")
                        loginStep = .success
                        isLoading = false
                        // 🔥 登录成功不弹框，直接进入主页
                        
                        // 在这里调用 AppState 的登录成功方法
                        if let permanentToken = UserDefaults.standard.string(forKey: "permanent_token") {
                            appState.loginSuccess(token: permanentToken)
                        }
                    }
                    
                case .disconnected, .error:
                    print("❌ STOMP连接断开或出错")
                    
                    // 只在连接阶段处理状态变化
                    if loginStep == .connecting {
                        print("❌ STOMP连接失败")
                        loginStep = .failed
                        isLoading = false
                        showAlert(message: "连接失败，请检查网络")
                    }
                    
                case .connecting:
                    print("🔄 STOMP连接中...")
                }
            }
        }
        
    }
    
    
    

    // 获取登录按钮文本
    private func getLoginButtonText() -> String {
        switch loginStep {
        case .idle:
            return "登录"
        case .authenticating:
            return "验证中..."
        case .connecting:
            return "连接中..."
        case .success:
            return "登录成功"
        case .failed:
            return "登录"
        }
    }
        
    // 监听WebSocket连接状态
    
    // 加载本地账号信息
    private func loadLocalAccountInfo() {
        if let savedAccount = AccountStorageManager.shared.loadAccountInfo() {
            username = savedAccount.collectorAccount
            password = savedAccount.password
            hasLocalAccount = true
            print("已加载本地保存的账号信息")
        } else {
            hasLocalAccount = false
            print("没有本地保存的账号信息")
        }
    }
    
    // 清除本地账号信息
    private func clearLocalAccount() {
        if AccountStorageManager.shared.clearAccountInfo() {
            username = ""
            password = ""
            hasLocalAccount = false
            showAlert(message: "已清除本地保存的账号信息")
        }
    }

    // 隐藏键盘的方法
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // 处理登录逻辑 - 修改为分步骤处理
    
    
    
    
    private func handleLogin() {
        // 输入验证
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showAlert(message: "请输入用户名")
            return
        }
        
        guard !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showAlert(message: "请输入密码")
            return
        }
        
        // 开始登录流程
        isLoading = true
        loginStep = .authenticating
        
        Task {
            do {
                // 第一步：API登录验证
                let loginResponse = try await APIService.shared.login(
                    username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                
                await MainActor.run {
                    // 保存登录信息
                    UserDefaults.standard.set(loginResponse.token, forKey: "jwt_token")
                    UserDefaults.standard.set(loginResponse.permanentToken, forKey: "permanent_token")
                    UserDefaults.standard.set(loginResponse.username, forKey: "username")
                    UserDefaults.standard.set(loginResponse.deviceId, forKey: "device_id")
                    UserDefaults.standard.set(loginResponse.userType, forKey: "user_type")
                    
                    // 🔥 保存昵称
                    if let nickname = loginResponse.nickname {
                        UserDefaults.standard.set(nickname, forKey: "nickname")
                        print("✅ 保存昵称: \(nickname)")
                    }
                    
                    // 🔥 保存推流IP地址
                    if let streamPushIp = loginResponse.streamPushIp {
                        UserDefaults.standard.set(streamPushIp, forKey: "stream_push_ip")
                        print("✅ 保存推流IP: \(streamPushIp)")
                    }
                    
                    // 🔥 保存试用/激活信息
                    if let trialInfo = loginResponse.trialInfo {
                        saveTrialInfo(trialInfo)
                    }
                    
                    // 进入WebSocket连接阶段
                    loginStep = .connecting
                }
                
                // 🔥 登录时不检查试用状态，允许进入主页
                // 推流和唤醒时会检查试用状态，到时再弹框引导激活
                
                // 第二步：获取设备简化配置
                let thinConfig = try await ConfigManager.shared.getThinRemoteConfig(deviceId: loginResponse.deviceId)
                ConfigManager.shared.cacheThinConfig(thinConfig)
                
                await MainActor.run {
                    // 第三步：建立WebSocket连接
                    WebSocketManager.shared.connect(deviceId: loginResponse.deviceId)
                    
                    // 保存账号信息到本地
                    let savedAccountInfo = SavedAccountInfo(
                        collectorAccount: loginResponse.username,
                        controllerAccount: "",
                        password: password,
                        deviceId: loginResponse.deviceId,
                        savedDate: Date()
                    )
                    
                    if AccountStorageManager.shared.saveAccountInfo(savedAccountInfo) {
                        print("账号信息已保存到本地")
                    }
                }
                
                // 注意：这里不设置isLoading = false，等WebSocket连接成功后再设置
                
            } catch let error as APIError {
                await MainActor.run {
                    loginStep = .failed
                    isLoading = false
                    
                    // 🔥 获取错误消息
                    let errorMessage: String
                    switch error {
                    case .accountBanned(let reason):
                        // 🔥 账号被封禁，显示封禁原因（不清空账号信息）
                        errorMessage = "账号已被封禁\n原因：\(reason)"
                        print("❌ 账号被封禁: \(reason)")
                        
                    case .serverErrorWithMessage(let msg):
                        errorMessage = msg
                        
                        // 🔥 如果是"账号不存在"，清空本地存储并显示注册行
                        if msg.contains("账号不存在") || msg.contains("用户名不存在") {
                            print("⚠️ 账号不存在，清空本地存储并显示注册行")
                            _ = AccountStorageManager.shared.clearAccountInfo()
                            username = ""
                            password = ""
                            hasLocalAccount = false
                        }
                    default:
                        errorMessage = error.localizedDescription
                    }
                    
                    // 🔥 弹框显示错误信息
                    showAlert(message: errorMessage)
                }
            } catch {
                await MainActor.run {
                    loginStep = .failed
                    isLoading = false
                    // 🔥 弹框显示错误信息
                    showAlert(message: "登录失败：\(error.localizedDescription)")
                }
            }
        }
    }
    
    // 显示提示信息
    private func showAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
    
    // 🔥 保存试用/激活信息到 UserDefaults
    private func saveTrialInfo(_ trialInfo: TrialInfo) {
        UserDefaults.standard.set(trialInfo.trialRequired, forKey: "trial_required")
        UserDefaults.standard.set(trialInfo.activated ?? false, forKey: "activated")
        
        if let level = trialInfo.activationLevel {
            UserDefaults.standard.set(level, forKey: "activation_level")
        }
        if let levelName = trialInfo.activationLevelName {
            UserDefaults.standard.set(levelName, forKey: "activation_level_name")
        }
        if let expireAt = trialInfo.activationExpireAt {
            UserDefaults.standard.set(expireAt, forKey: "activation_expire_at")
        }
        if let qualityAccess = trialInfo.qualityAccess {
            UserDefaults.standard.set(qualityAccess, forKey: "quality_access")
        }
        
        UserDefaults.standard.set(trialInfo.trialEnded ?? false, forKey: "trial_ended")
        
        if let currentStage = trialInfo.currentStage {
            UserDefaults.standard.set(currentStage, forKey: "current_stage")
        }
        if let totalStages = trialInfo.totalStages {
            UserDefaults.standard.set(totalStages, forKey: "total_stages")
        }
        if let stageSeconds = trialInfo.stageSeconds {
            UserDefaults.standard.set(stageSeconds, forKey: "stage_seconds")
        }
        if let remainingSeconds = trialInfo.remainingSeconds {
            UserDefaults.standard.set(remainingSeconds, forKey: "remaining_seconds")
        }
        if let usedSeconds = trialInfo.usedSeconds {
            UserDefaults.standard.set(usedSeconds, forKey: "used_seconds")
        }
        
        print("✅ 保存试用信息: trialRequired=\(trialInfo.trialRequired), activated=\(trialInfo.activated ?? false), level=\(trialInfo.activationLevelName ?? "无")")
    }
}

// SwiftUI预览
#Preview {
    MonitorLoginView()
}
