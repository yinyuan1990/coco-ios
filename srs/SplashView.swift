import SwiftUI

// MARK: - Splash 启动页（显示 Ai Logo，1秒后跳转登录）
struct SplashView: View {
    @EnvironmentObject var appState: AppState
    
    // 动画状态
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var glowOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // 背景渐变 - 科技感深色
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.1, green: 0.1, blue: 0.25),
                    Color(red: 0.05, green: 0.08, blue: 0.2)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // 背景装饰 - 网格线条
            GeometryReader { geometry in
                Canvas { context, size in
                    // 绘制网格线
                    for i in stride(from: 0, to: size.width, by: 40) {
                        var path = Path()
                        path.move(to: CGPoint(x: i, y: 0))
                        path.addLine(to: CGPoint(x: i, y: size.height))
                        context.stroke(path, with: .color(.white.opacity(0.03)), lineWidth: 0.5)
                    }
                    for i in stride(from: 0, to: size.height, by: 40) {
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: i))
                        path.addLine(to: CGPoint(x: size.width, y: i))
                        context.stroke(path, with: .color(.white.opacity(0.03)), lineWidth: 0.5)
                    }
                }
            }
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Spacer()

                // App 图标
                ZStack {
                    // 外发光
                    Image(systemName: "sparkles")
                        .font(.system(size: 80, weight: .bold))
                        .foregroundColor(.cyan.opacity(0.3))
                        .blur(radius: 20)
                        .opacity(glowOpacity)

                    // 内发光
                    Image(systemName: "sparkles")
                        .font(.system(size: 80, weight: .bold))
                        .foregroundColor(.cyan.opacity(0.5))
                        .blur(radius: 8)
                        .opacity(glowOpacity)

                    // 主图标
                    Image(systemName: "sparkles")
                        .font(.system(size: 80, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.cyan,
                                    Color.blue,
                                    Color.purple.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .cyan.opacity(0.5), radius: 10, x: 0, y: 0)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                // App 名称
                Text("幻境2")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(logoOpacity)
                    .padding(.top, 10)

                Spacer()

                // 底部版权
                Text("© 2026 幻境2")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.bottom, 30)
                    .opacity(logoOpacity)
            }
        }
        .onAppear {
            // 入场动画
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            
            // 发光动画稍晚一点
            withAnimation(.easeIn(duration: 0.8).delay(0.2)) {
                glowOpacity = 1.0
            }
            
            // 1秒后跳转到登录页
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    appState.navigateToLogin()
                }
            }
        }
    }
}

#Preview {
    SplashView()
        .environmentObject(AppState())
}

