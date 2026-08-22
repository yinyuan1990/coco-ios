import SwiftUI

// ⭐ §53.4-定稿（2026-07-28）：**登录页不再让用户选线路，也不再选编码**。
//   线路由系统在推流前按网络关系自动决定（同 WiFi → P2P 单人直连；否则 → SRS 多人线路），
//   编码由总后台配置（默认 H265，观看端内核或本机硬编不支持时自动回退 H264）——
//   决策逻辑全部在 `Managers/SessionPolicy.swift`。
//   **SRT 已退役**：SRS 6.0.184 的 RTMP→RTC 桥写死丢弃 HEVC（§49.6-9），SRT+H265 必黑屏。
//
//   本枚举保留（rawValue 仍写进 `connect_mode`，供后端强制 SRS 与回滚用），
//   但 `.srt` 不再出现在任何 UI/决策里，`allCases` 也不再被登录页使用。
enum ConnectModeOption: String, CaseIterable {
    case srs = "srs"
    case p2p = "p2p"

    var title: String {
        switch self {
        // ⭐ 2026-07-11：SRS=多人线路、P2P=单人线路（仅改显示名，rawValue 仍是 srs/p2p）
        case .srs: return "多人线路"
        case .p2p: return "单人线路"
        }
    }

    var isEnabled: Bool { true }

    /// 本地记忆 key（现仅由系统写入决策结果，用户不再手选）
    static let storageKey = "selected_connect_mode"

    /// 读取上次选择（无则默认 SRS，与后端默认一致）
    static var lastSelected: ConnectModeOption {
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? ""
        return ConnectModeOption(rawValue: raw) ?? .srs
    }
}

// 监控端登录视图
struct MonitorLoginView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var username: String = ""           // 显示用（有本地账号时显示前8位）
    @State private var fullUsername: String = ""       // 完整账号（用于登录）
    // ⭐ 2026-08-16：登录页无密码输入框。password 只承载「本地保存的密码」，
    //   无保存值时登录自动用默认密码 123456（新注册账号的密码就是 123456）
    @State private var password: String = ""
    @State private var rememberPassword: Bool = true   // coco/aihj：老版无「记住密码」开关，登录成功一律保存账号（对齐老 iOS）
    // ⭐ §53.4-定稿：下面三个选择态**已不再驱动任何 UI**（线路/编码改为系统决策）。
    //   仅与保留下来的 `connectModeChip` / `CodecOptionChips` 一起留着，便于一键回滚到"用户手选"。
    @State private var selectedConnectMode: ConnectModeOption = ConnectModeOption.lastSelected
    @State private var selectedCodec: VideoCodecOption = VideoCodecOption.lastSelected
    @State private var selectedCodecSrs: VideoCodecOption = VideoCodecOption.lastSelected(key: VideoCodecOption.srsStorageKey, defaultCodec: .h264)
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var showRegisterView: Bool = false
    @State private var hasLocalAccount: Bool = false
    // ⭐ 2026-08-17 登录页不再输入账号：本地没存账号时按设备ID到服务器找回（老用户合并）
    @State private var isFetchingAccount: Bool = false   // 正在按设备ID找回账号
    @State private var accountRecovered: Bool = false    // 账号来自服务器找回（重装/老用户）
    
    @State private var isLoading: Bool = false
    @State private var isLoggedIn: Bool = false
    @State private var loginStep: LoginStep = .idle
    @State private var boundControlCount: Int = 1  // 🔥 绑定的控制端数量
    
    @State private var showUserAgreement = false
    @State private var showPrivacyPolicy = false
    @State private var showAlreadyBoundAlert = false  // 已绑定账号提示
    // ⭐ 2026-08-22：按住登录按钮 8 秒自动复制设备ID（手动计时实现——系统 onLongPressGesture
    //   在 8s 这种超长时长下不可靠，且无过程反馈）
    @State private var holdStartTime: Date? = nil      // 本次按压开始时间（nil=未按压）
    @State private var holdProgress: Double = 0        // 按压进度 0~1（驱动按钮上的进度条）
    @State private var holdCopyFired = false           // 本次按压已触发复制（松手不再当点按）
    @State private var holdTimer: Timer? = nil
    // ⭐ 强制更新（总后台「App更新配置」下发最低版本+下载地址，本地版本低则弹不可绕过弹窗）
    @State private var showForceUpdate = false
    @State private var forceUpdateMessage = ""
    @State private var forceUpdateUrl = ""
        
    enum LoginStep {
        case idle
        case authenticating
        case connecting
        case success
        case failed
    }
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // ⭐ 2026-08-22 需求：背景换星空光环。原 cocologin.gif（39.4MB）正中烧了
                //   「我的水印」白字无法修复，改用 AI 重绘的同风格无水印静态图（150KB）
                //   + 代码动画（缓慢呼吸缩放 + 星光闪烁），视觉近似动图且更省电。
                LoginAnimatedBackground()
                    .ignoresSafeArea()
                
                // 底部加一层轻微压暗，保证协议/版本等小字在亮色画面上也可读
                LinearGradient(
                    gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.35)]),
                    startPoint: .center,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
                
                VStack(spacing: 0) {
                    // 顶部关闭按钮（老样式）
                    HStack {
                        Button(action: {
                            appState.navigateBack()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.18))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    // ⭐ 2026-08-22 需求：登录 logo 去掉，只留应用名（白字+投影，衬星空动图背景）
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "幻境星空")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.5), radius: 6, y: 2)
                    
                    // ⭐ 2026-08-22 需求：登录按钮沉到底部——固定在「登录/注册即表示您同意」上方 100
                    Spacer()
                    
                    // 登录表单
                    VStack(spacing: 20) {
                        // ⭐ 2026-08-22 需求：账号展示行去掉（账号获取逻辑不变，只是不再显示）；
                        //   登录不输密码（本地保存值，无则默认 123456）
                        
                        // 登录按钮：轻点=登录；⭐ 按住 8 秒=自动复制设备ID（隐藏售后入口）。
                        //   手动计时实现：按住 1.5s 后按钮变提示文案+进度条，满 8s 震动+复制+弹窗。
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(loginButtonLabel)
                                .font(.system(size: holdHintVisible ? 15 : 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    (isLoading ? Color.gray : Color.blue)
                                    // 按压进度条（白色高亮从左往右推进到 8s 满格）
                                    Color.white.opacity(0.30)
                                        .frame(width: geo.size.width * CGFloat(holdProgress))
                                }
                            }
                        )
                        .cornerRadius(12)
                        .contentShape(Rectangle())
                        .scaleEffect(holdStartTime != nil ? 0.97 : 1.0)
                        .animation(.easeOut(duration: 0.15), value: holdStartTime != nil)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    guard !isLoading, holdStartTime == nil else { return }
                                    beginHoldTracking()
                                }
                                .onEnded { _ in
                                    endHoldTracking()
                                }
                        )
                        .padding(.top, 10)

                        // 注册链接（老样式：没有账号时显示）
                        if !hasLocalAccount {
                            HStack {
                                Text("没有账号？")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.75))
                                Button(action: {
                                    showRegisterView = true
                                }) {
                                    Text("一键注册")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color(hex: "8ED6FF"))
                                }
                            }
                            .padding(.top, 10)
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 100)
                    
                    // 底部协议条款（老样式）
                    VStack(spacing: 4) {
                        Text("登录/注册即表示您同意")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.65))
                        
                        HStack(spacing: 4) {
                            Button(action: {
                                showUserAgreement = true
                            }) {
                                Text("《用户协议》")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "8ED6FF"))
                            }
                            
                            Text("和")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.65))
                            
                            Button(action: {
                                showPrivacyPolicy = true
                            }) {
                                Text("《隐私政策》")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "8ED6FF"))
                            }
                        }
                    }
                    .padding(.bottom, 8)
                    
                    // 版本号（⭐ 2026-08-18：纯展示——设备ID已明放在登录按钮下方+一键复制，
                    //   原「点版本号弹 DeviceIdInfoView」隐藏入口去掉，不再跳转）
                    Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.45))
                        .padding(.bottom, 12)
                        .frame(maxWidth: .infinity)
                }
            }
            .onTapGesture {
                hideKeyboard()
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadLocalAccountInfo()
            // ⭐ 2026-08-17：本地没账号（重装/换机/老用户清数据）→ 按设备ID到服务器找回
            if !hasLocalAccount {
                fetchAccountByDevice()
            }
            selectedConnectMode = ConnectModeOption.lastSelected  // 同步上次选择
            setupWebSocketNotificationListener()
            checkForceUpdate()   // ⭐ 强制更新检查（总后台「App更新配置」，公共接口）
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: .webSocketConnectionStateChanged, object: nil)
        }
        .fullScreenCover(isPresented: $showRegisterView, onDismiss: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                loadLocalAccountInfo()
                print("📱 注册页面关闭，重新加载本地账号: hasLocalAccount=\(hasLocalAccount)")
            }
        }) {
            RegisterView(onRegisterSuccess: { registeredUsername, registeredPassword in
                print("✅ 注册成功回调: username=\(registeredUsername)")
                self.fullUsername = registeredUsername
                self.username = String(registeredUsername.prefix(8))
                self.password = registeredPassword
                self.hasLocalAccount = true
            })
        }
        .alert("提示", isPresented: $showAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        // ⭐ 强制更新：只有「立即更新」一个按钮，点完 0.5s 后重新弹出——不可绕过
        .alert("发现新版本", isPresented: $showForceUpdate) {
            Button("立即更新") {
                if let url = URL(string: forceUpdateUrl) {
                    UIApplication.shared.open(url)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showForceUpdate = true }
            }
        } message: {
            Text(forceUpdateMessage)
        }
        .alert("提示", isPresented: $showAlreadyBoundAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("您的设备已经绑定了账号（\(username)）\n如需解绑请联系管理员")
        }
        .fullScreenCover(isPresented: $showUserAgreement) {
            LocalWebView(fileName: "user_agreement", title: "用户协议")
        }
        .fullScreenCover(isPresented: $showPrivacyPolicy) {
            LocalWebView(fileName: "privacy_policy", title: "隐私政策")
        }
        // ⭐ 登录页 toast（扫码绑定成功回登录页时提示「请重新登录」，2.5s 自动消失）
        .overlay(alignment: .bottom) {
            if !appState.loginToast.isEmpty {
                Text(appState.loginToast)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(22)
                    .padding(.bottom, 80)
                    .transition(.opacity)
                    .onAppear {
                        // 5s：这里也用于承载「不在同一 WiFi，请选择多人线路」这类操作指引（§52.6），2.5s 读不完
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                            appState.loginToast = ""
                        }
                    }
            }
        }
    }
    
    // MARK: - ⭐ App 强制更新（与 Android AppUpdateManager 同一接口同一语义）
    // 公共接口 GET /api/config/app-update（无需登录），返回 {config:"{\"ios\":{enabled,minVersion,downloadUrl},...}"}。
    // 本地 CFBundleShortVersionString < minVersion 且 enabled → 弹不可绕过的强更弹窗跳 downloadUrl。
    // 网络/解析失败一律放行（不能因接口抖动把用户锁在门外）。
    private func checkForceUpdate() {
        guard let url = URL(string: APIConfig.shared.baseURL + "/api/config/app-update") else { return }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "GET"
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let outer = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let cfgStr = outer["config"] as? String,
                  let cfgData = cfgStr.data(using: .utf8),
                  let cfg = try? JSONSerialization.jsonObject(with: cfgData) as? [String: Any],
                  let iosCfg = cfg["ios"] as? [String: Any] else {
                print("📦 [强更] 检查失败(放行)")
                return
            }
            let enabled = (iosCfg["enabled"] as? Bool) ?? false
            let minVersion = (iosCfg["minVersion"] as? String) ?? ""
            let downloadUrl = (iosCfg["downloadUrl"] as? String) ?? ""
            guard enabled, !minVersion.isEmpty, !downloadUrl.isEmpty else {
                print("📦 [强更] 未开启或未配置 → 放行")
                return
            }
            let local = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
            if MonitorLoginView.compareVersion(local, minVersion) < 0 {
                print("📦 [强更] 本地=\(local) < 最低=\(minVersion) → 强制更新 \(downloadUrl)")
                DispatchQueue.main.async {
                    forceUpdateUrl = downloadUrl
                    forceUpdateMessage = "当前版本 \(local) 已停止支持，请更新到 \(minVersion) 及以上版本后继续使用。"
                    showForceUpdate = true
                }
            } else {
                print("📦 [强更] 本地=\(local) ≥ 最低=\(minVersion) → 放行")
            }
        }.resume()
    }

    /// 语义化版本比较（"2.4" vs "2.4.1" 逐段数字比），返回 <0 / 0 / >0
    private static func compareVersion(_ a: String, _ b: String) -> Int {
        let pa = a.split(separator: ".").map { Int($0.filter { $0.isNumber }) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0.filter { $0.isNumber }) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x < y ? -1 : 1 }
        }
        return 0
    }

    // 设置WebSocket通知监听
    private func setupWebSocketNotificationListener() {
        NotificationCenter.default.addObserver(
            forName: .webSocketConnectionStateChanged,
            object: nil,
            queue: .main
        ) { notification in
            print("🔔 收到STOMP连接状态变化通知")
            
            if let connectionStateRaw = notification.userInfo?["connectionState"] as? String,
               let connectionState = ConnectionState(rawValue: connectionStateRaw) {
                
                switch connectionState {
                case .connected:
                    print("✅ STOMP连接成功")
                    
                    if loginStep == .connecting {
                        print("✅ STOMP连接成功，更新登录状态")
                        loginStep = .success
                        isLoading = false
                        
                        if let permanentToken = UserDefaults.standard.string(forKey: "permanent_token") {
                            let scanValue = UserDefaults.standard.integer(forKey: "login_scan")
                            // 🔥 传递 boundControlCount + scan 决定跳转目标
                            appState.loginSuccess(token: permanentToken, boundControlCount: boundControlCount, scan: scanValue)
                        }
                    }
                    
                case .disconnected, .error:
                    print("❌ STOMP连接断开或出错")
                    
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

    // 连接方式单个选项芯片
    @ViewBuilder
    private func connectModeChip(_ mode: ConnectModeOption) -> some View {
        let isSelected = (selectedConnectMode == mode)
        let enabled = mode.isEnabled

        Button(action: {
            guard enabled else {
                showAlert(message: "\(mode.title) 即将上线，敬请期待")
                return
            }
            selectedConnectMode = mode
            UserDefaults.standard.set(mode.rawValue, forKey: ConnectModeOption.storageKey)
        }) {
            Text(mode.title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(
                    !enabled ? Color(hex: "C4C4C4")
                    : (isSelected ? .white : Color(hex: "65AEF7"))
                )
                .frame(minWidth: 44)
                .padding(.vertical, 6)
                .background(
                    Group {
                        if !enabled {
                            Color(hex: "F0F0F0")
                        } else if isSelected {
                            Color(hex: "65AEF7")
                        } else {
                            Color(hex: "EAF4FE")
                        }
                    }
                )
                .cornerRadius(6)
        }
        .disabled(false)  // SRT 仍可点击以弹出提示
    }

    // MARK: - ⭐ 按住登录按钮 8 秒复制设备ID（手动计时）
    
    private static let holdCopyDuration: Double = 8.0   // 触发复制需按住的秒数
    private static let holdHintDelay: Double = 1.5      // 按住超过这个时长才切提示文案（避免正常点按闪动）
    
    /// 按压提示是否已出现（超过 1.5s）
    private var holdHintVisible: Bool {
        holdStartTime != nil && holdProgress >= Self.holdHintDelay / Self.holdCopyDuration
    }
    
    /// 按钮文案：按住时显示剩余秒数提示，平时显示登录状态文案
    private var loginButtonLabel: String {
        if holdHintVisible && !holdCopyFired {
            let remaining = max(0, Int(ceil(Self.holdCopyDuration * (1 - holdProgress))))
            return "继续按住 \(remaining) 秒复制设备ID"
        }
        return getLoginButtonText()
    }
    
    /// 手指按下：开始计时，0.1s 步进刷进度条；满 8s 复制设备ID+震动+弹窗
    private func beginHoldTracking() {
        holdStartTime = Date()
        holdCopyFired = false
        holdProgress = 0
        
        let timer = Timer(timeInterval: 0.1, repeats: true) { _ in
            guard let start = holdStartTime else { return }
            let elapsed = Date().timeIntervalSince(start)
            holdProgress = min(elapsed / Self.holdCopyDuration, 1.0)
            
            if elapsed >= Self.holdCopyDuration && !holdCopyFired {
                holdCopyFired = true
                holdTimer?.invalidate()
                holdTimer = nil
                
                let deviceId = DeviceIDManager.shared.getDeviceID()
                UIPasteboard.general.string = deviceId
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                showAlert(message: "设备ID已复制到剪贴板：\n\(deviceId)")
            }
        }
        // .common 模式：手指按住期间 RunLoop 可能进 tracking 模式，默认模式的 Timer 会被饿死
        RunLoop.main.add(timer, forMode: .common)
        holdTimer = timer
    }
    
    /// 手指松开：快速点按（<1.5s）当登录；按了一半松手只取消不登录；已触发复制则啥也不做
    private func endHoldTracking() {
        holdTimer?.invalidate()
        holdTimer = nil
        let elapsed = holdStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let copied = holdCopyFired
        holdStartTime = nil
        holdProgress = 0
        holdCopyFired = false
        
        if !copied && elapsed < Self.holdHintDelay && !isLoading {
            handleLogin()
        }
    }
    
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
    
    private func loadLocalAccountInfo() {
        if let savedAccount = AccountStorageManager.shared.loadAccountInfo() {
            // 🔥 保存完整账号用于登录
            fullUsername = savedAccount.collectorAccount
            // 🔥 显示前8位（昵称风格）
            username = String(fullUsername.prefix(8))
            password = savedAccount.password
            hasLocalAccount = true
            rememberPassword = true
            print("已加载本地账号: 显示=\(username), 完整=\(fullUsername)")
        } else {
            hasLocalAccount = false
            print("没有本地保存的账号信息")
        }
    }
    
    // ⭐ 2026-08-17 按设备ID找回账号（老用户合并的关键一步）：
    //   设备ID才是真正身份，账号只是个挂在 users.device_id 上的形式编号。
    //   老用户重装 App 后本地无账号，但后端 device_id 反查就能拿回原账号——
    //   之后一键登录用默认密码 123456，后端 deviceId 兜底放行并把老密码归一。
    private func fetchAccountByDevice() {
        guard !hasLocalAccount, !isFetchingAccount else { return }
        isFetchingAccount = true
        Task {
            defer { Task { @MainActor in isFetchingAccount = false } }
            do {
                let deviceId = DeviceIDManager.shared.getDeviceID()
                let url = URL(string: "\(APIConfig.shared.baseURL)/api/auth/account-by-device")!
                var req = URLRequest(url: url, timeoutInterval: 8)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try JSONEncoder().encode(["deviceId": deviceId])
                let (data, _) = try await URLSession.shared.data(for: req)
                struct AccountByDeviceResponse: Decodable {
                    let exists: Bool
                    let username: String?
                    let nickname: String?
                }
                let resp = try JSONDecoder().decode(AccountByDeviceResponse.self, from: data)
                await MainActor.run {
                    if resp.exists, let name = resp.username, !name.isEmpty {
                        fullUsername = name
                        username = String(name.prefix(8))
                        hasLocalAccount = true
                        accountRecovered = true
                        print("🔁 [账号找回] 设备ID反查到账号: \(name)（老用户合并，密码走默认123456+后端兜底）")
                    } else {
                        print("📱 [账号找回] 该设备未注册过账号 → 引导一键注册")
                    }
                }
            } catch {
                // 查询失败不阻断（登录按钮点击时会重试），新设备照常走注册
                print("⚠️ [账号找回] account-by-device 请求失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func clearLocalAccount() {
        if AccountStorageManager.shared.clearAccountInfo() {
            username = ""
            fullUsername = ""
            password = ""
            hasLocalAccount = false
            showAlert(message: "已清除本地保存的账号信息")
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func handleLogin() {
        // ⭐ 2026-08-17：账号不再由用户输入。没有账号（本地没存 + 设备ID也查不到）→ 引导注册
        guard !fullUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if isFetchingAccount {
                showAlert(message: "正在获取本机账号，请稍候…")
            } else {
                fetchAccountByDevice()  // 可能是刚才网络失败，重试一次
                showAlert(message: "本机还未注册账号，请点击下方「一键注册」")
            }
            return
        }
        
        isLoading = true
        loginStep = .authenticating
        
        Task {
            do {
                // ⭐ 账号只是形式，登录一律用完整账号（本地保存的 or 按设备ID找回的）
                let loginUsername = fullUsername
                // ⭐ 2026-08-16 一键登录：密码不再由用户输入——
                //   本地有保存密码 → 用保存的；否则（含按设备找回的老账号）用默认密码 123456。
                //   老账号密码不是 123456 也没关系：后端按 deviceId 匹配放行并把密码归一成 123456。
                let loginPassword: String
                if !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    loginPassword = password
                } else {
                    loginPassword = "123456"
                }
                print("🔑 [一键登录] 账号=\(loginUsername) 来源=\(accountRecovered ? "设备找回" : "本地保存") 密码=\(password.isEmpty ? "默认123456" : "本地保存")")
                let loginResponse = try await APIService.shared.login(
                    username: loginUsername.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: loginPassword.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                
                await MainActor.run {
                    UserDefaults.standard.set(loginResponse.token, forKey: "jwt_token")
                    UserDefaults.standard.set(loginResponse.permanentToken, forKey: "permanent_token")
                    UserDefaults.standard.set(loginResponse.username, forKey: "username")
                    UserDefaults.standard.set(loginResponse.deviceId, forKey: "device_id")
                    UserDefaults.standard.set(loginResponse.userType, forKey: "user_type")
                    
                    // 🔥 保存用户ID（用于问题反馈等功能）
                    if let userId = loginResponse.userId {
                        UserDefaults.standard.set(userId, forKey: "user_id")
                        print("✅ 保存用户ID: \(userId)")
                    }
                    
                    if let nickname = loginResponse.nickname {
                        UserDefaults.standard.set(nickname, forKey: "nickname")
                        print("✅ 保存昵称: \(nickname)")
                    }
                    
                    if let streamPushIp = loginResponse.streamPushIp {
                        UserDefaults.standard.set(streamPushIp, forKey: "stream_push_ip")
                        print("✅ 保存推流IP: \(streamPushIp)")
                    }

                    // ⭐ §53.4-定稿：连接方式**改以后端下发为准**（不再被登录页选择覆盖）。
                    //   "srs" = 总后台一键强制多人线路；其它（auto/p2p/缺省）= 交给 SessionPolicy
                    //   在推流前按"与观看端是否同 WiFi"自动决定。用户已无从手选。
                    let connectMode = (loginResponse.connectMode ?? "auto").lowercased()
                    UserDefaults.standard.set(connectMode, forKey: "connect_mode")
                    UserDefaults.standard.set(loginResponse.maxP2PViewers ?? 4, forKey: "maxP2PViewers")
                    // ⭐ §53.21：forceRelay / iceServers 不再落地——P2P 中继与打洞代码已物理删除
                    //  （纯局域网 host-only 直连），后端这两个字段对 iOS 已无消费方。
                    //   顺带清掉历史残留，防旧 key 误导排查。
                    UserDefaults.standard.removeObject(forKey: "forceRelay")
                    UserDefaults.standard.removeObject(forKey: "iceServers")

                    // ⭐ §53.4.4 编码默认值改由总后台配置（本机硬编或观看端内核不支持时
                    //   由 SessionPolicy/H265Support 自动回退 h264）。
                    //   §56.27：产品默认改 h264——字段缺省（老后端）也按 h264，与后端部署无关。
                    // ⭐ aihj 版拍板：只要 SRS + H264，忽略后端下发的编码配置，一律写死 h264。
                    let codecP2p = "h264"
                    let codecSrs = "h264"
                    UserDefaults.standard.set(codecP2p, forKey: VideoCodecOption.storageKey)
                    UserDefaults.standard.set(codecSrs, forKey: VideoCodecOption.srsStorageKey)

                    // ⭐ §53.20.2：本机公网出口 IP（后端按请求来源回填）。SessionPolicy 拿它与
                    //   PC 上报的 publicIp 比对，防 /24 网段号撞车误判同 WiFi。老后端无此字段 → 存空。
                    UserDefaults.standard.set(loginResponse.clientIp ?? "", forKey: "public_ip")

                    // ⭐ 需求#13（2026-07-31）：后端下发的 iOS 最新版本号（总后台可配，空=不提示）。
                    //   进推流页前 ContentView 与本地 CFBundleShortVersionString 比对，不一致弹提示（软提示，可继续用）。
                    UserDefaults.standard.set(loginResponse.latestVersions?.ios ?? "", forKey: "latest_ios_version")

                    print("✅ 连接方式(后端): \(connectMode), 编码默认(后端) P2P=\(codecP2p)/SRS=\(codecSrs), maxP2PViewers: \(loginResponse.maxP2PViewers ?? 4)（P2P=纯局域网直连，无中继/打洞）")
                    
                    if let trialInfo = loginResponse.trialInfo {
                        saveTrialInfo(trialInfo)
                    }
                    
                    // 🔥 保存绑定控制端数量和scan字段
                    boundControlCount = loginResponse.boundControlCount ?? 1
                    let scanValue = loginResponse.scan ?? 0
                    UserDefaults.standard.set(scanValue, forKey: "login_scan")
                    print("✅ 绑定控制端数量: \(boundControlCount), scan: \(scanValue)")
                    
                    loginStep = .connecting
                }
                
                let thinConfig = try await ConfigManager.shared.getThinRemoteConfig(deviceId: loginResponse.deviceId)
                ConfigManager.shared.cacheThinConfig(thinConfig)
                
                await MainActor.run {
                    WebSocketManager.shared.connect(deviceId: loginResponse.deviceId)
                    
                    // 根据"记住密码"选项保存账号（⭐ 2026-08-16：存实际登录用的密码，
                    //   首登无保存值时存的就是默认密码 123456）
                    if rememberPassword {
                        let savedAccountInfo = SavedAccountInfo(
                            collectorAccount: loginResponse.username,
                            controllerAccount: "",
                            password: loginPassword,
                            deviceId: loginResponse.deviceId,
                            savedDate: Date()
                        )
                        
                        if AccountStorageManager.shared.saveAccountInfo(savedAccountInfo) {
                            print("账号信息已保存到本地")
                        }
                    }
                }
                
            } catch let error as APIError {
                await MainActor.run {
                    loginStep = .failed
                    isLoading = false
                    
                    let errorMessage: String
                    switch error {
                    case .accountBanned(let reason):
                        errorMessage = "账号已被封禁\n原因：\(reason)"
                        print("❌ 账号被封禁: \(reason)")
                        
                    case .serverErrorWithMessage(let msg):
                        errorMessage = msg
                        // ⭐ 2026-08-18 修「本地存了旧账号 → 一直报账号不存在」：
                        //   本地 Keychain 里的账号在服务器已不存在（测试账号被清/换库），
                        //   而登录页优先用本地账号，永远轮不到按设备ID找回的正确账号。
                        //   清掉本地缓存 → 立即按设备ID重新找回，用户再点一次登录即可。
                        if msg.contains("账号不存在") {
                            _ = AccountStorageManager.shared.clearAccountInfo()
                            hasLocalAccount = false
                            accountRecovered = false
                            fullUsername = ""
                            username = ""
                            password = ""
                            fetchAccountByDevice()
                        }
                    default:
                        errorMessage = error.localizedDescription
                    }
                    
                    showAlert(message: errorMessage)
                }
            } catch {
                await MainActor.run {
                    loginStep = .failed
                    isLoading = false
                    showAlert(message: "登录失败：\(error.localizedDescription)")
                }
            }
        }
    }
    
    private func showAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
    
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
        // ⭐ §53.9 开通时间（「我的」页把"注册时间"整行换成「<等级>会员 + 开通时间」）
        if let activationTime = trialInfo.activationTime {
            UserDefaults.standard.set(activationTime, forKey: "activation_time")
        }
        if let qualityAccess = trialInfo.qualityAccess {
            UserDefaults.standard.set(qualityAccess, forKey: "quality_access")
        }
        
        // 🔥 日试用相关（新增）
        UserDefaults.standard.set(trialInfo.isDailyTrial ?? false, forKey: "is_daily_trial")
        if let activationRemaining = trialInfo.activationRemainingSeconds {
            UserDefaults.standard.set(activationRemaining, forKey: "activation_remaining_seconds")
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
        
        let isDailyTrialStr = (trialInfo.isDailyTrial ?? false) ? ", 日试用" : ""
        print("✅ 保存试用信息: trialRequired=\(trialInfo.trialRequired), activated=\(trialInfo.activated ?? false), level=\(trialInfo.activationLevelName ?? "无")\(isDailyTrialStr)")
    }
}

// 圆角扩展 - 支持指定角
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - ⭐ 2026-08-22 登录页动态背景（AI 重绘无水印星空光环图 + 代码动画）
//   原 cocologin.gif 39.4MB 且正中烧死「我的水印」白字（delogo 修补出白色拖影带，不可用），
//   改为：静态图 login_bg_static（150KB JPEG）缓慢呼吸缩放（Ken Burns）+ Canvas 星光闪烁层。
struct LoginAnimatedBackground: View {
    @State private var zoomIn = false
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image("login_bg_static")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(zoomIn ? 1.10 : 1.0)
                    .animation(.easeInOut(duration: 9).repeatForever(autoreverses: true), value: zoomIn)
                    .clipped()
                
                TwinkleStarsOverlay()
            }
        }
        .allowsHitTesting(false)
        .onAppear { zoomIn = true }
    }
}

/// 星光闪烁层：固定种子随机布 26 颗小星，按各自相位/速度用正弦波调透明度（20fps 足够，省电）
private struct TwinkleStarsOverlay: View {
    private struct Star {
        let x: CGFloat      // 0~1 相对坐标
        let y: CGFloat
        let radius: CGFloat
        let phase: Double
        let speed: Double
    }
    
    private static let stars: [Star] = {
        var seed: UInt64 = 20260822
        func next() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat(seed >> 33) / CGFloat(1 << 31)
        }
        return (0..<26).map { _ in
            Star(x: next(), y: next(),
                 radius: 1.2 + next() * 2.2,
                 phase: Double(next()) * 2 * .pi,
                 speed: 0.6 + Double(next()) * 1.6)
        }
    }()
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for star in Self.stars {
                    let alpha = 0.15 + 0.65 * (0.5 + 0.5 * sin(t * star.speed + star.phase))
                    let rect = CGRect(x: star.x * size.width, y: star.y * size.height,
                                      width: star.radius * 2, height: star.radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
                }
            }
        }
    }
}

#Preview {
    MonitorLoginView()
}
