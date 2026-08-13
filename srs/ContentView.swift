import SwiftUI
import WebRTC
import MediaPlayer
import AVFoundation

// MARK: - 隐藏 Home Indicator 的 Modifier（iOS 16+）
struct HideHomeIndicatorModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .persistentSystemOverlays(.hidden)
        } else {
            content
        }
    }
}

// MARK: - 音量键监听管理器
class VolumeButtonManager: NSObject, ObservableObject {
    private var volumeView: MPVolumeView?
    private var volumeSlider: UISlider?
    private var volumeChangeHandler: (() -> Void)?
    private var isRestoringVolume: Bool = false
    private var lastTriggerTime: Date = Date.distantPast
    private var lastVolume: Float = 0.5
    
    private let targetVolume: Float = 0.5
    
    func startMonitoring(onVolumeChange: @escaping () -> Void) {
        self.volumeChangeHandler = onVolumeChange
        
        print("🔊 [VolumeButtonManager] 开始初始化音量监听...")
        
        // 1️⃣ 设置音频会话
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
            lastVolume = audioSession.outputVolume
            print("✅ 音频会话设置成功，当前音量: \(lastVolume)")
        } catch {
            print("❌ 音频会话设置失败: \(error)")
}

        // 2️⃣ 创建隐藏的 MPVolumeView（必须添加到视图层级才能工作）
        volumeView = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
        volumeView?.showsRouteButton = false
        volumeView?.showsVolumeSlider = true  // 🔥 必须显示slider才能监听
        
        if let keyWindow = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows
            .first(where: { $0.isKeyWindow }) {
            keyWindow.addSubview(volumeView!)
            print("✅ MPVolumeView 已添加到窗口")
        } else {
            print("❌ 无法获取 keyWindow")
        }
        
        // 3️⃣ 延迟获取 slider 引用
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, let volumeView = self.volumeView else { return }
            
            // 递归查找 slider
            self.volumeSlider = self.findSlider(in: volumeView)
            if self.volumeSlider != nil {
                print("✅ 音量slider获取成功")
            } else {
                print("⚠️ 音量slider获取失败")
            }
            
            // 初始化到中间值（确保音量键可以双向触发）
            let currentVolume = AVAudioSession.sharedInstance().outputVolume
            print("🔊 初始音量: \(currentVolume)")
            if currentVolume < 0.1 || currentVolume > 0.9 {
                print("🔊 音量过于极端，重置到中间值")
                self.setVolumeInternal(self.targetVolume)
            }
        }
        
        // 4️⃣ 使用 NotificationCenter 监听系统音量变化（更可靠）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(volumeDidChange(_:)),
            name: NSNotification.Name("AVSystemController_SystemVolumeDidChangeNotification"),
            object: nil
        )
        
        // 5️⃣ 同时使用 KVO 作为备选方案
        audioSession.addObserver(self, forKeyPath: "outputVolume", options: [.new, .old], context: nil)
        
        print("✅ 音量键监听已启动（NotificationCenter + KVO 双保险）")
                    }
    
    @objc private func volumeDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reason = userInfo["AVSystemController_AudioVolumeChangeReasonNotificationParameter"] as? String,
              reason == "ExplicitVolumeChange" else {
            // 忽略非用户主动调节的音量变化
            return
        }
        
        guard let newVolume = userInfo["AVSystemController_AudioVolumeNotificationParameter"] as? Float else {
            return
        }
        
        handleVolumeChange(oldVolume: lastVolume, newVolume: newVolume, source: "NotificationCenter")
    }
    
    private func handleVolumeChange(oldVolume: Float, newVolume: Float, source: String) {
        // 如果正在恢复音量，忽略
        if isRestoringVolume {
            print("🔊 [\(source)] 忽略：正在恢复音量中...")
            return
        }
        
        // 防抖：距离上次触发不到 0.3 秒，忽略
        let now = Date()
        if now.timeIntervalSince(lastTriggerTime) < 0.3 {
            print("🔊 [\(source)] 忽略：防抖中...")
            return
        }
        
        let diff = abs(newVolume - oldVolume)
        if diff > 0.01 {
            lastTriggerTime = now
            lastVolume = newVolume
            
            print("🔊🔊🔊 [\(source)] 音量键触发: \(oldVolume) -> \(newVolume), diff=\(diff)")
            
            // 触发回调
            DispatchQueue.main.async {
                self.volumeChangeHandler?()
            }
            
            // 恢复到中间值
            isRestoringVolume = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                guard let self = self else { return }
                self.setVolumeInternal(self.targetVolume)
                self.lastVolume = self.targetVolume
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self.isRestoringVolume = false
                    print("🔊 [恢复完成] 音量已重置到: \(self.targetVolume)")
                }
            }
        }
    }
    
    private func findSlider(in view: UIView) -> UISlider? {
        for subview in view.subviews {
            if let slider = subview as? UISlider {
                return slider
            }
            if let slider = findSlider(in: subview) {
                return slider
            }
        }
        return nil
    }
    
    private func setVolumeInternal(_ volume: Float) {
        if let slider = volumeSlider {
            DispatchQueue.main.async {
                slider.value = volume
                print("🔊 [内部] 通过slider设置音量: \(volume)")
        }
        } else {
            // 备选方案
            MPVolumeView.setVolume(volume)
                            }
    }
    
    func stopMonitoring() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("AVSystemController_SystemVolumeDidChangeNotification"), object: nil)
        AVAudioSession.sharedInstance().removeObserver(self, forKeyPath: "outputVolume")
        volumeView?.removeFromSuperview()
        volumeView = nil
        volumeSlider = nil
        print("✅ 音量键监听已停止")
        }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "outputVolume" {
            guard let newVolume = change?[NSKeyValueChangeKey.newKey] as? Float else { return }
            let oldVolume = change?[NSKeyValueChangeKey.oldKey] as? Float ?? lastVolume
            
            handleVolumeChange(oldVolume: oldVolume, newVolume: newVolume, source: "KVO")
        }
    }
}

extension MPVolumeView {
    static func setVolume(_ volume: Float) {
        // 🔥 使用更可靠的方式设置音量
        let volumeView = MPVolumeView(frame: .zero)
        
        // 方法1：直接查找 slider
        if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
            DispatchQueue.main.async {
                slider.value = volume
                print("🔊 [setVolume] 通过slider设置音量: \(volume)")
                            }
            return
        }
        
        // 方法2：使用私有API（备选方案）
        // 注意：这是私有API，App Store 审核可能会拒绝，但本地测试有效
        let selector = NSSelectorFromString("setVolume:")
        if volumeView.responds(to: selector) {
            volumeView.perform(selector, with: volume)
            print("🔊 [setVolume] 通过私有API设置音量: \(volume)")
        } else {
            print("⚠️ [setVolume] 无法设置音量（slider和私有API都失败）")
        }
    }
}

// MARK: - 小组件：底部控制面板（只保留切换镜头和清晰度）
struct ControlPanelView: View {
    @ObservedObject var rtc: WebRTCManager
    
    // 档位名称（简短）
    private func profileName(_ p: LadderProfile) -> String {
        switch p {
        case .p4k: return "4K"
        case .ultra: return "超清"
        case .high: return "高清"
        case .standard: return "标清"
        }
    }

    var body: some View {
        // ✅ 横屏模式：水平排列
        HStack(spacing: 16) {
            // 前/后摄像头切换
            Button(action: { rtc.toggleCamera() }) {
                VStack(spacing: 2) {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(size: 18))
                    Text("切换")
                        .font(.system(size: 9))
                }
                        .foregroundColor(.white)
                }
            .frame(width: 50, height: 50)
                .background(Color.black.opacity(0.6))
                .clipShape(Circle())
                
            // 档位切换（清晰度）
            HStack(spacing: 6) {
                ForEach([LadderProfile.standard, .high, .ultra, .p4k], id: \.self) { profile in
                    Button(action: {
                        rtc.applyProfile(profile)
                    }) {
                        Text(profileName(profile))
                            .font(.system(size: 10, weight: rtc.currentProfile == profile ? .bold : .regular))
                            .foregroundColor(rtc.currentProfile == profile ? .yellow : .white)
                            .frame(width: 40, height: 30)
                            .background(rtc.currentProfile == profile ? Color.blue.opacity(0.8) : Color.black.opacity(0.6))
                            .cornerRadius(6)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .background(Color.clear)  // 🔥 确保没有默认白色背景
    }
}

// MARK: - 主视图
struct ContentView: View {
    @StateObject var rtc = WebRTCManager()
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase  // ✅ App 生命周期

    // UI
    @State private var showControls: Bool = true
    @State private var isBlackout: Bool = false
    @State private var savedBrightness: CGFloat? = nil
    
    // 🔥 滑动黑屏：滑动5次触发
    @State private var swipeCount: Int = 0
    @State private var lastSwipeTime: Date = Date()
    
    // 导航到个人中心
    @State private var showingProfile: Bool = false

    // ✅ 自动推流状态
    @State private var isCameraReady = false
    @State private var isWebSocketConnected = false
    @State private var hasAutoPublished = false  // 防止重复推流
    @State private var autoPublishRetryCount = 0  // 自动推流重试次数
    
    // ✅ 音量键监听
    @StateObject private var volumeButtonManager = VolumeButtonManager()
    
    // ✅ 休眠/唤醒防抖
    @State private var isSleepWakeInProgress: Bool = false
    
    // ✅ 自动推流防抖（防止多次调用startPublish导致SRS返回400错误）
    @State private var isAutoPublishInProgress: Bool = false

    // 🔥 试用结束弹框
    @State private var showTrialEndAlert: Bool = false
    @State private var trialEndMessage: String = ""
    @State private var isTrialEnded: Bool = false
    
    // 🔥 激活页面
    @State private var showingActivation: Bool = false
    
    // 🔥 防止重复弹框（TryDisconnect 每秒都会收到）
    // 记录已弹框的阶段号，只有新阶段结束时才弹框
    @State private var lastShownStageEnded: Int = 0


    // 档位名称（简短）
    var body: some View {
        ZStack {
            // 🔥 底层黑色背景，确保没有白边
            Color.black
                .ignoresSafeArea(.all)
            
            // 预览
            WebRTCPreview(view: rtc.localView)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) { showControls.toggle() }
                }

            // 左上角"我的"按钮 + 方向状态显示
            if showControls {
                VStack {
                    HStack {
                        Button(action: {
                            showingProfile = true
                        }) {
                            VStack(spacing: 1) {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 16))
                                Text("我的")
                                    .font(.system(size: 8))
                            }
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(.top, 35)
                        .padding(.leading, 12)
                        
                        Spacer()
                    }
                    Spacer()
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }

            // 底部控制面板（横屏模式 - 水平排列，和最长边平行）
            if showControls {
                VStack(spacing: 0) {  // 🔥 spacing: 0 消除可能的白线
                    Spacer()
                    ControlPanelView(rtc: rtc)
                        .padding(.bottom, 20)
                        .background(Color.clear)  // 🔥 确保背景透明
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // 黑幕层
            if isBlackout {
                Color.black.ignoresSafeArea().allowsHitTesting(false)
            }
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // 🔥 确保填满整个屏幕
        .background(Color.black.ignoresSafeArea(.all))     // 🔥 黑色背景忽略所有安全区域
        .ignoresSafeArea(.all)                             // 🔥 ZStack 本身也忽略安全区域
        .modifier(HideHomeIndicatorModifier())             // 🔥 隐藏 Home Indicator（iOS 16+）
        .onAppear {
            print("\n========================================")
            print("🚀🚀🚀 ContentView.onAppear 开始执行")
            print("========================================")
            
            // 📊 诊断：检查初始状态
            print("📊 初始状态检查：")
            print("   - scenePhase: \(scenePhase)")
            print("   - streamKey: \(rtc.streamKey.isEmpty ? "❌空(\(rtc.streamKey.count)字符)" : "✅已设置(\(rtc.streamKey))")")
            print("   - isPublishing: \(rtc.isPublishing ? "⚠️是" : "✅否")")
            print("   - isCameraSleeping: \(rtc.isCameraSleeping ? "⚠️是" : "✅否")")
            print("   - isCameraReady: \(isCameraReady ? "✅是" : "❌否")")
            print("   - isWebSocketConnected: \(isWebSocketConnected ? "✅是" : "❌否")")
            print("   - hasAutoPublished: \(hasAutoPublished ? "⚠️是" : "✅否")")
            
            // 🔥 关键修复：确保休眠状态为 false（防止残留状态导致不自动推流）
            if rtc.isCameraSleeping {
                print("⚠️ 发现休眠状态为 true，强制重置为 false")
                // 直接唤醒（这会重置 isCameraSleeping = false）
                rtc.wakeCamera()
            }
            
            // 🔥 关键修复：主动清理旧状态，确保干净的初始化
            if rtc.isPublishing {
                print("⚠️ 发现推流状态为 true，先停止推流清理状态")
                rtc.stopPublish()
            }
            
            // ✅ 重置自动推流标志（杀死进程后重启需要重新自动推流）
            hasAutoPublished = false
            isCameraReady = false
            autoPublishRetryCount = 0  // 重置重试次数
            lastShownStageEnded = 0    // 🔥 重置弹框阶段标志，确保每次进入都能弹框
            print("🔄 已重置 hasAutoPublished=false, isCameraReady=false, autoPublishRetryCount=0, lastShownStageEnded=0")
            
            // 🔥 立即检查试用状态 - 如果登录时已经是试用结束，立即弹框引导激活
            let trialRequired = UserDefaults.standard.bool(forKey: "trial_required")
            let trialEnded = UserDefaults.standard.bool(forKey: "trial_ended")
            let activated = UserDefaults.standard.bool(forKey: "activated")
            print("🔍 onAppear 试用状态检查: trialRequired=\(trialRequired), activated=\(activated), trialEnded=\(trialEnded)")

            // 🔥 记录是否试用已结束（用于后续判断是否跳过摄像头启动）
            let isTrialExpired = trialRequired && !activated && trialEnded
            
            if isTrialExpired {
                print("⏱️ 登录时已试用结束，稍后弹框引导激活")
                // 断开 WebSocket（如果已连接）
                WebSocketManager.shared.disconnect()
            }
            
            // ✅ 主动加载 streamKey（防止杀进程后丢失）
            if let permanentToken = UserDefaults.standard.string(forKey: "permanent_token"), !permanentToken.isEmpty {
                rtc.updateStreamKey(permanentToken)
                print("✅ onAppear: 主动加载 streamKey = \(permanentToken)")
            } else {
                print("❌ onAppear: 未找到 permanent_token！")
            }
            
            // 🔥 已改为使用带时间戳的唯一流名，不再需要删除旧流
            // 每次推流都使用新的流名（基础流名 + 时间戳），避免冲突
            
            // ✅ 横屏锁定：强制横屏方向
            AppDelegate.orientationLock = .landscapeRight
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
            
            // 防止屏幕自动锁屏
            UIApplication.shared.isIdleTimerDisabled = true
            
            print("🎬 ContentView.onAppear: 横屏锁定完成")
            
            // 🔥 如果试用已结束，跳过摄像头启动和推流，直接弹框引导激活
            if isTrialExpired {
                print("⏱️ 试用已结束，跳过摄像头启动，弹框引导激活")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.lastShownStageEnded = 6
                    self.trialEndMessage = "今日试用次数已用完"
                    self.isTrialEnded = true
                    self.showTrialEndAlert = true
                }
                // 注册通知监听器（用于处理激活后的状态）
                setupAutoPublishing()
                return
            }
            
            // ✅ 延迟启动摄像头，确保设备已完全旋转到横屏
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("🎬 [0.5秒后] 开始初始化摄像头...")
                rtc.startPreviewIfNeeded()  // ✅ 使用配置的档位
            }
            
            // ✅ 事件驱动自动推流：监听摄像头预览和WebSocket连接状态
            print("🔧 开始注册自动推流事件监听器...")
            setupAutoPublishing()
            
            // 🔥 检查 WebSocket 连接状态并主动重连（杀死进程后可能需要重连）
            if WebSocketManager.shared.isConnected {
                print("📡 WebSocket 已连接，标记 isWebSocketConnected=true")
                isWebSocketConnected = true
            } else {
                print("⚠️ WebSocket 未连接，尝试重连...")
                isWebSocketConnected = false
                
                // 🔥 主动重连 WebSocket
                if let deviceId = UserDefaults.standard.string(forKey: "device_id"), !deviceId.isEmpty {
                    print("🔄 正在重连 WebSocket，deviceId=\(deviceId)")
                    WebSocketManager.shared.connect(deviceId: deviceId)
                } else {
                    print("❌ 未找到 device_id，无法重连 WebSocket")
                }
            }
            
            // ✅ 延迟检查一次（确保初始化时 streamKey 和摄像头都已加载）
            // 这个延迟检查作为兜底机制，如果事件驱动的推流没有触发，这里会再尝试一次
            // 延迟 3.5 秒，给事件驱动推流和重试机制足够的时间
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                print("🔍 [3.5秒后] 兜底检查自动推流条件...")
                if !self.rtc.isPublishing && !self.hasAutoPublished {
                    print("   -> 事件驱动推流未成功，执行兜底推流")
                    self.tryAutoPublish()
                } else if self.rtc.isPublishing {
                    print("   -> ✅ 已在推流中，无需兜底")
                } else {
                    print("   -> 已尝试过自动推流，无需重复")
                }
            }
            
            print("========================================")
            print("✅ ContentView.onAppear 执行完毕")
            print("========================================\n")
            
            // 监听退出登录通知
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("StopPublishBeforeLogout"),
                object: nil,
                queue: .main
            ) { _ in
                print("⏹️ 收到退出登录通知，停止推流")
                if rtc.isPublishing {
                    rtc.stopPublish()
                }
            }
            
            // 🔥 监听扫码前释放摄像头通知（触发睡眠，完全释放摄像头资源）
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ReleaseCameraForScanner"),
                object: nil,
                queue: .main
            ) { _ in
                print("📷 收到扫码释放摄像头通知，触发睡眠")
                if !rtc.isCameraSleeping {
                    rtc.sleepCamera()
                }
            }
            
            // ✅ 启动音量键监听
            volumeButtonManager.startMonitoring { [weak rtc] in
                guard let rtc = rtc else { return }
                DispatchQueue.main.async {
                    // 🔥 防抖：如果正在执行休眠/唤醒操作，忽略新的请求
                    if self.isSleepWakeInProgress {
                        print("🔊 音量键：操作进行中，忽略")
                        return
                    }
                    
                    self.isSleepWakeInProgress = true
                    
                    if rtc.isCameraSleeping {
                        print("🔊 音量键：唤醒摄像头")
                        rtc.wakeCamera()
                    } else {
                        print("🔊 音量键：休眠摄像头")
                        rtc.sleepCamera()
                    }
                    
                    // 🔥 0.5秒后解除防抖锁定
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.isSleepWakeInProgress = false
                    }
                }
            }
        }
        .onDisappear {
            // ✅ 离开推流页：恢复所有方向 + 回到竖屏
            AppDelegate.orientationLock = .all
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
            
            // 恢复自动锁屏
            UIApplication.shared.isIdleTimerDisabled = false

            // 移除所有通知观察者
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("StopPublishBeforeLogout"), object: nil)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ReleaseCameraForScanner"), object: nil)
            NotificationCenter.default.removeObserver(self, name: .cameraPreviewReady, object: nil)
            NotificationCenter.default.removeObserver(self, name: .publishFailed, object: nil)
            NotificationCenter.default.removeObserver(self, name: .webSocketConnectionStateChanged, object: nil)
            NotificationCenter.default.removeObserver(self, name: .resetPublishRequested, object: nil)
            NotificationCenter.default.removeObserver(self, name: .cameraSleepRequested, object: nil)
            NotificationCenter.default.removeObserver(self, name: .tryDisconnectRequested, object: nil)  // 🔥 试用断开
            
            // ✅ 停止音量键监听
            volumeButtonManager.stopMonitoring()
        }
        .simultaneousGesture(
            // 🔥 滑动5次切换黑屏/亮屏
            DragGesture(minimumDistance: 50)
                .onEnded { _ in
                    let now = Date()
                    // 如果距离上次滑动超过2秒，重置计数
                    if now.timeIntervalSince(lastSwipeTime) > 2.0 {
                        swipeCount = 0
                    }
                    lastSwipeTime = now
                    swipeCount += 1
                    
                    // 达到5次滑动，切换黑屏状态
                    if swipeCount >= 5 {
                        swipeCount = 0
                withAnimation(.easeInOut(duration: 0.2)) {
                    isBlackout.toggle()
                    if isBlackout { showControls = false }
                }
                if isBlackout {
                    savedBrightness = UIScreen.main.brightness
                    UIScreen.main.brightness = 0.05
                } else if let b = savedBrightness {
                    UIScreen.main.brightness = b
                    savedBrightness = nil
                        }
                }
            }
        )
        .fullScreenCover(isPresented: $showingProfile, onDismiss: {
            // ✅ 从个人中心返回推流页，恢复横屏锁定
            AppDelegate.orientationLock = .landscapeRight
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
            print("ℹ️ 从个人中心返回到推流页面，恢复横屏锁定")
        }) {
            ProfileView()
                .environmentObject(appState)
                .onAppear {
                    // ✅ 打开个人中心时，允许竖屏
                    AppDelegate.orientationLock = .all
                    UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
                    UIViewController.attemptRotationToDeviceOrientation()
                }
        }
        // 🔥 试用结束 - 直接退出应用
        .onChange(of: showTrialEndAlert) { newValue in
            if newValue {
                print("⏱️ 试用结束，直接退出应用")
                // 停止推流
                if rtc.isPublishing {
                    rtc.stopPublish()
                }
                // 断开 WebSocket
                WebSocketManager.shared.disconnect()
                // 延迟一点退出，确保清理完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    exit(0)
                }
            }
        }
        // 🔥 激活页面
        .sheet(isPresented: $showingActivation, onDismiss: {
            // 🔥 关闭激活页面后，恢复横屏锁定
            print("📱 激活页面关闭，恢复横屏锁定")
            AppDelegate.orientationLock = .landscapeRight
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
        }) {
            ActivationView(onActivationSuccess: {
                // 🔥 激活成功后，返回登录界面重新登录
                print("✅ 激活成功，返回登录界面")
                lastShownStageEnded = 0  // 重置弹框阶段标志
                hasAutoPublished = false
                
                // 推流已经停止了，WebSocket也已经断开了
                // 清理token，导航回登录页
                UserDefaults.standard.set("", forKey: "jwt_token")
                UserDefaults.standard.set("", forKey: "permanent_token")
                
                // 🔥 恢复竖屏（登录页面是竖屏）
                AppDelegate.orientationLock = .portrait
                UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
                UIViewController.attemptRotationToDeviceOrientation()
                
                // 导航回登录页
                appState.navigateToMonitorLogin()
            })
        }
        // ✅ 监听 App 生命周期（iOS 15+ 兼容写法）
        .onChange(of: scenePhase) { newPhase in
            handleScenePhaseChange(to: newPhase)
        }
    }
    
    // MARK: - 事件驱动自动推流
    private func setupAutoPublishing() {
        print("🔧 setupAutoPublishing: 开始注册通知观察者...")
        
        // 监听摄像头预览就绪
        NotificationCenter.default.addObserver(
            forName: .cameraPreviewReady,
            object: nil,
            queue: .main
        ) { _ in
            print("\n📸📸📸 收到摄像头预览就绪通知")
            self.isCameraReady = true
            print("   -> 已设置 isCameraReady=true")
            // 🔥 延迟0.5秒后再尝试推流，确保 localVideoTrack 真正创建完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("   -> [0.5秒后] 尝试自动推流...")
                self.tryAutoPublish()
            }
        }
        print("   ✅ 已注册 cameraPreviewReady 监听器")
        
        // 🔥 监听推流失败通知
        NotificationCenter.default.addObserver(
            forName: .publishFailed,
            object: nil,
            queue: .main
        ) { notification in
            // 🔥 解除防抖锁，允许重试
            self.isAutoPublishInProgress = false
            
            if let reason = notification.userInfo?["reason"] as? String {
                print("\n❌❌❌ 收到推流失败通知：\(reason)")
                print("   -> 当前重试次数：\(self.autoPublishRetryCount)")
                
                // 🔥 重试机制：只重试1次（code=400时足够）
                if self.autoPublishRetryCount < 1 {
                    self.autoPublishRetryCount += 1
                    
                    // 🔥 SRS 会自动清理旧流，无需手动删除
                    // 每次推流都用新的 streamKey（带时间戳），不会冲突
                    
                    // 延迟2秒重试（给SRS清理时间）
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        print("\n🔄🔄🔄 [第\(self.autoPublishRetryCount)次重试] 2秒后，开始重试推流...")
                        
                        // 🔥 先清理旧状态，确保干净
                        if self.rtc.isPublishing {
                            print("⚠️ 重试前发现推流状态为 true，先清理")
                            self.rtc.stopPublish()
                            // 等待0.5秒让清理完成
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.hasAutoPublished = false
                                self.rtc.startPublish()
                            }
                        } else {
                            // 重置 hasAutoPublished，允许再次推流
                            self.hasAutoPublished = false
                            // 再次尝试推流（会生成新的 streamKey）
                            self.rtc.startPublish()
                        }
                    }
                } else {
                    // 重试次数用尽
                    print("   -> ❌ 已重试1次，放弃自动推流")
                }
            }
        }
        print("   ✅ 已注册 publishFailed 监听器")
        
        // 监听WebSocket连接状态
        NotificationCenter.default.addObserver(
            forName: .webSocketConnectionStateChanged,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let stateRaw = userInfo["connectionState"] as? String,
               stateRaw == "connected" {
                print("\n🌐🌐🌐 收到WebSocket连接成功通知")
                self.isWebSocketConnected = true
                print("   -> 已设置 isWebSocketConnected=true")
                self.tryAutoPublish()
            } else {
                print("\n⚠️ 收到WebSocket断开通知")
                self.isWebSocketConnected = false
                print("   -> 已设置 isWebSocketConnected=false")
            }
        }
        print("   ✅ 已注册 webSocketConnectionStateChanged 监听器")
        
        // 🔥 监听重置推流请求（从后端服务器发来的RESET_PUBLISH消息）
        NotificationCenter.default.addObserver(
            forName: .resetPublishRequested,
            object: nil,
            queue: .main
        ) { notification in
            print("\n🔄🔄🔄 收到重置推流请求通知")
            
            let deviceId = notification.userInfo?["deviceId"] as? String ?? ""
            let timestamp = notification.userInfo?["timestamp"] as? Int64 ?? 0
            
            print("   - deviceId: \(deviceId)")
            print("   - timestamp: \(timestamp)")
            print("   - 当前推流状态: \(self.rtc.isPublishing ? "正在推流" : "未推流")")
            
            if self.rtc.isPublishing {
                // 正在推流：先停止，再重新推流
                print("   -> 正在推流中，先停止推流...")
                self.rtc.stopPublish()
                
                // 等待0.5秒确保完全停止后再重新推流
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("   -> 重新开始推流...")
                    self.rtc.startPublish()
                }
            } else {
                // 未推流：直接开始推流
                print("   -> 当前未推流，直接开始推流...")
                self.rtc.startPublish()
            }
        }
        print("   ✅ 已注册 resetPublishRequested 监听器")
        
        // 🔥 监听省电模式（摄像头休眠/唤醒）请求（从后端服务器发来的RESET_SHENGDIANG消息）
        NotificationCenter.default.addObserver(
            forName: .cameraSleepRequested,
            object: nil,
            queue: .main
        ) { notification in
            print("\n💤💤💤 收到省电模式请求通知")
            
            let deviceId = notification.userInfo?["deviceId"] as? String ?? ""
            let timestamp = notification.userInfo?["timestamp"] as? Int64 ?? 0
            let reason = notification.userInfo?["reason"] as? String ?? ""
            
            print("   - deviceId: \(deviceId)")
            print("   - timestamp: \(timestamp)")
            print("   - reason: \(reason)")
            print("   - 当前休眠状态: \(self.rtc.isCameraSleeping ? "休眠中" : "运行中")")
            
            // 根据当前状态切换到相反状态（不显示Toast）
            if self.rtc.isCameraSleeping {
                print("   -> 当前休眠中，执行唤醒操作...")
                
                // 🔥 唤醒前检查试用状态
                let trialRequired = UserDefaults.standard.bool(forKey: "trial_required")
                let trialEnded = UserDefaults.standard.bool(forKey: "trial_ended")
                let activated = UserDefaults.standard.bool(forKey: "activated")

                if trialRequired && !activated && trialEnded {
                    print("   ⏱️ 试用已结束，无法唤醒推流")

                    // 断开 WebSocket
                    WebSocketManager.shared.disconnect()

                    // 防止重复弹框
                    if self.lastShownStageEnded < 6 {
                        self.lastShownStageEnded = 6
                        self.trialEndMessage = "今日试用次数已用完"
                        self.isTrialEnded = true
                        self.showTrialEndAlert = true
                        print("   -> 弹框引导激活")
                    }
                    return
                }
                
                self.rtc.wakeCamera()
            } else {
                print("   -> 当前运行中，执行休眠操作...")
                self.rtc.sleepCamera()
            }
        }
        print("   ✅ 已注册 cameraSleepRequested 监听器")
        
        // 🔥 监听试用断开请求（从后端服务器发来的TryDisconnect消息，每秒都会收到）
        NotificationCenter.default.addObserver(
            forName: .tryDisconnectRequested,
            object: nil,
            queue: .main
        ) { notification in
            let shouldDisconnect = notification.userInfo?["shouldDisconnect"] as? Bool ?? false
            let trialEnded = notification.userInfo?["trialEnded"] as? Bool ?? false
            let stageJustEnded = notification.userInfo?["stageJustEnded"] as? Int ?? 0
            let message = notification.userInfo?["message"] as? String ?? "试用时间已到"

            // 只在需要断开时处理
            if shouldDisconnect {
                print("\n⏱️⏱️⏱️ 收到试用断开请求通知 - 需要断开")
                print("   - shouldDisconnect: \(shouldDisconnect)")
                print("   - trialEnded: \(trialEnded)")
                print("   - stageJustEnded: \(stageJustEnded)")
                print("   - lastShownStageEnded: \(self.lastShownStageEnded)")
                print("   - message: \(message)")

                // 🔥 停止推流
                if self.rtc.isPublishing {
                    print("   -> 停止推流...")
                    self.rtc.stopPublish()
                }

                // 🔥 断开 WebSocket
                print("   -> 断开 WebSocket...")
                WebSocketManager.shared.disconnect()

                // 🔥 防止重复弹框：只有当新阶段结束时才弹框
                let shouldShowAlert = (stageJustEnded > 0 && stageJustEnded > self.lastShownStageEnded) ||
                                      (trialEnded && self.lastShownStageEnded < 6)

                if shouldShowAlert {
                    self.lastShownStageEnded = stageJustEnded > 0 ? stageJustEnded : 6
                    self.trialEndMessage = message
                    self.isTrialEnded = trialEnded
                    self.showTrialEndAlert = true
                    print("   -> 显示引导激活弹框 (阶段 \(self.lastShownStageEnded))")
                } else {
                    print("   -> 已弹框过阶段 \(self.lastShownStageEnded)，跳过")
                }
            }
        }
        print("   ✅ 已注册 tryDisconnectRequested 监听器")
        
        print("🔧 setupAutoPublishing: 通知观察者注册完成\n")
    }
    
    private func tryAutoPublish() {
        // 🔥 检查试用状态 - 如果需要试用限制且试用已结束，则弹框引导激活
        let trialRequired = UserDefaults.standard.bool(forKey: "trial_required")
        let trialEnded = UserDefaults.standard.bool(forKey: "trial_ended")
        let activated = UserDefaults.standard.bool(forKey: "activated")

        if trialRequired && !activated && trialEnded {
            print("⏱️ 试用已结束，无法推流")

            // 断开 WebSocket
            WebSocketManager.shared.disconnect()

            // 防止重复弹框
            if lastShownStageEnded < 6 {
                lastShownStageEnded = 6
                trialEndMessage = "今日试用次数已用完"
                isTrialEnded = true
                showTrialEndAlert = true
                print("   -> 弹框引导激活")
            }
            return
        }
        
        // 🔥 如果摄像头处于休眠状态，不执行自动推流
        if rtc.isCameraSleeping {
            print("💤 摄像头处于休眠状态，跳过自动推流")
            return
        }
        
        // 🔥 防抖：如果正在执行自动推流，忽略重复调用（防止SRS返回400错误）
        if isAutoPublishInProgress {
            print("🔒 自动推流正在进行中，忽略重复调用")
            return
        }
        
        print("🔍 检查自动推流条件...")
        print("   - baseStreamKey: \(rtc.baseStreamKey.isEmpty ? "❌空" : "✅已设置(\(rtc.baseStreamKey))")")
        print("   - 摄像头: \(isCameraReady ? "✅就绪" : "❌未就绪")")
        print("   - WebSocket: \(isWebSocketConnected ? "✅已连接" : "❌未连接")")
        print("   - 推流中: \(rtc.isPublishing ? "⚠️是" : "✅否")")
        print("   - 已自动推流: \(hasAutoPublished ? "⚠️是" : "✅否")")
        
        // ✅ 检查 baseStreamKey 是否准备好（streamKey 会在 startPublish 时动态生成）
        guard !rtc.baseStreamKey.isEmpty else {
            print("⏳ baseStreamKey 未加载，0.5秒后重试...")
            // 延迟重试
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.tryAutoPublish()
            }
            return
        }
        
        // ✅ 所有条件都满足 + 未推流 + 未自动推流过，则自动开始推流
        guard isCameraReady,
              isWebSocketConnected,
              !rtc.isPublishing,
              !hasAutoPublished else {
            print("⏳ 条件未满足，等待...")
            
            if rtc.isPublishing {
                print("   -> 已经在推流中，无需再次推流")
            } else if hasAutoPublished {
                print("   -> 已自动推流过（或正在重试中），忽略此次调用")
            }
            return
        }
        
        // 🔥 设置防抖锁，防止重复调用startPublish导致SRS 400错误
        isAutoPublishInProgress = true
        
        print("✅✅✅ 所有条件满足，准备自动推流！")
        
        // 🔥 如果这是首次尝试（不是重试），重置重试计数器
        // 重试时的 startPublish 调用不会走到这里，所以不会重置计数器
        if autoPublishRetryCount == 0 {
            print("   -> 这是首次自动推流尝试")
        } else {
            print("   -> 这是第\(autoPublishRetryCount)次重试")
        }
        
        // 🔥 先不设置 hasAutoPublished，等推流真正开始后再设置
        // 如果 startPublish 立即失败（capturer 或 localVideoTrack 为 nil），会触发 publishFailed 通知
        rtc.startPublish()
        
        // 🔥 延迟 1.0 秒后检查推流是否成功启动（给 setRemoteDescription 足够时间）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("🔍 [1.0秒后] 检查推流状态：isPublishing = \(self.rtc.isPublishing)")
            if self.rtc.isPublishing {
                // 推流成功启动，设置标志防止重复推流
                self.hasAutoPublished = true
                self.isAutoPublishInProgress = false  // 🔥 解除防抖锁
                print("✅ 推流已成功启动，设置 hasAutoPublished=true")
            } else {
                // 推流未启动，可能失败了
                print("⚠️ 推流未能启动（isPublishing=false），可能失败或还在处理中")
                // 再等 0.5 秒检查一次
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isAutoPublishInProgress = false  // 🔥 解除防抖锁
                    if self.rtc.isPublishing {
                        self.hasAutoPublished = true
                        print("✅ [延迟检查] 推流已成功启动")
                    } else {
                        print("❌ [延迟检查] 推流确实失败了")
                    }
                }
            }
        }
    }
    
    // MARK: - App 生命周期处理
    private func handleScenePhaseChange(to newPhase: ScenePhase) {
        print("\n========================================")
        print("🔄 ScenePhase 变化: \(newPhase)")
        print("========================================")
        
        switch newPhase {
        case .background:
            print("🌙 App 进入后台，清理资源...")
            handleAppEnterBackground()
            
        case .inactive:
            print("⏸️ App 进入非活跃状态（可能是通知栏下拉、接电话等）")
            // 可选：暂停推流（如接电话、通知栏下拉等）
            
        case .active:
            print("☀️ App 回到前台（或首次启动），恢复资源...")
            handleAppBecomeActive()
            
        @unknown default:
            print("⚠️ 未知的 ScenePhase 状态")
            break
        }
        print("========================================\n")
    }
    
    private func handleAppEnterBackground() {
        // ✅ 如果摄像头在休眠状态，不需要额外处理（已经停止采集）
        if rtc.isCameraSleeping {
            print("💤 摄像头已休眠，进入后台无需额外处理")
            return
        }
        
        // 1. 停止推流
        if rtc.isPublishing {
            print("⏹️ 停止推流...")
            rtc.stopPublish()
        }
        
        // 2. 停止摄像头预览（释放摄像头资源）
        print("📸 暂停摄像头...")
        // WebRTC 会自动管理，但标记状态
        isCameraReady = false
        
        // 3. WebSocket 保持连接（可选：如果想省电可以断开）
        // WebSocketManager.shared.disconnect()
    }
    
    private func handleAppBecomeActive() {
        print("☀️ handleAppBecomeActive: 开始处理...")
        
        // ✅ 如果摄像头在休眠状态，不自动恢复推流（不显示Toast）
        if rtc.isCameraSleeping {
            print("💤 摄像头处于休眠状态，保持休眠不自动恢复")
            return
        }
        
        // 重置状态
        hasAutoPublished = false
        autoPublishRetryCount = 0  // 重置重试次数
        print("   🔄 已重置 hasAutoPublished=false, autoPublishRetryCount=0")
        
        // 0. 重新加载 streamKey（防止 token 过期或变化）
        if let permanentToken = UserDefaults.standard.string(forKey: "permanent_token"), !permanentToken.isEmpty {
            rtc.updateStreamKey(permanentToken)
            print("   ✅ 回到前台，重新加载 streamKey = \(permanentToken)")
        } else {
            print("   ❌ 回到前台，未找到 permanent_token")
        }
        
        // 1. 检查 WebSocket 连接状态
        if !WebSocketManager.shared.isConnected {
            print("   🔄 WebSocket 未连接，尝试重连...")
            if let deviceId = UserDefaults.standard.string(forKey: "device_id") {
                WebSocketManager.shared.connect(deviceId: deviceId)
                isWebSocketConnected = false
                print("   -> 标记 isWebSocketConnected=false，等待连接通知")
            } else {
                print("   ❌ 未找到 device_id，无法重连 WebSocket")
            }
        } else {
            print("   ✅ WebSocket 已连接")
            isWebSocketConnected = true
            print("   -> 标记 isWebSocketConnected=true")
        }
        
        // 2. 检查摄像头状态
        // 如果摄像头已初始化，重新启动采集
        if rtc.capturer != nil {
            print("   📸 摄像头已初始化，0.5秒后重新启动采集...")
            // 重新触发采集（recapture 会重新初始化摄像头）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let preset = rtc.currentLadder[rtc.currentProfile] {
                    print("   📸 [0.5秒后] 重新采集: \(preset.width)x\(preset.height) @\(preset.fps)fps")
                    rtc.recapture(width: preset.width, height: preset.height, fps: preset.fps)
                } else {
                    print("   ⚠️ [0.5秒后] 未找到当前档位配置，无法重新采集")
                }
            }
        } else {
            print("   ⚠️ 摄像头未初始化（capturer=nil），需要重新启动预览")
            isCameraReady = false
        }
        
        // 3. 等待事件通知自动推流（通过 tryAutoPublish）
        print("   ⏳ 等待条件满足后自动推流...")
        print("☀️ handleAppBecomeActive: 处理完毕\n")
    }
}

// SwiftUI预览
#Preview {
    ContentView()
}
