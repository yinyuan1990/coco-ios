import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingProfile: Bool = false

    var body: some View {
        NavigationView {
        // 保持你现有的UI结构，只修改导航部分
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.white]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                Text("首页")
                    .font(.system(size: 24))
                    .font(.largeTitle)
                    .foregroundColor(.primary)
                    .padding(.top, 20)
                
                // 温馨提示卡片 - 保持原有代码
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.orange)
                            .font(.title2)
                        Text("温馨提示")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Text("要使用我们的产品，您需要一台手机和一台PC配合，手机作为监控端采集画面，PC端进行观看和管理。")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                }
                .padding(20)
                .background(Color.white)
                .cornerRadius(15)
                .shadow(color: .gray.opacity(0.2), radius: 8, x: 0, y: 4)
                .padding(.horizontal, 20)
                
                // 按钮区域
                VStack(spacing: 20) {
                    // 监控端按钮
                    Button(action: {
                        appState.navigateToMonitorLogin()
                    }) {
                        HStack {
                            Image("monitor_icon")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 60, height: 60)
                                .background(Color.green.opacity(0.1))
                                .clipShape(Circle())
                            
                            Text("监控端")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(15)
                        .shadow(color: .gray.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
        .navigationTitle("幻境2")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingProfile = true
                }) {
                    HStack(spacing: 4) {
                        Text("我的")
                            .font(.system(size: 15))
                        Image(systemName: "gearshape")
                            .font(.system(size: 16))
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView()
                .environmentObject(appState)
        }
        } // NavigationView
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}
