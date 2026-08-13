//
//  BindingListView.swift
//  srs
//
//  已绑定控制端列表视图
//

import SwiftUI

struct BindingListView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var bindings: [APIService.BindingItem] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    
    // 解绑相关状态（使用 item 绑定确保数据同步）
    @State private var selectedBinding: APIService.BindingItem?
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景色
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    // 加载中
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("加载中...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else if let error = errorMessage {
                    // 错误状态
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text("加载失败")
                            .font(.headline)
                        
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("重试") {
                            Task {
                                await loadBindings()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if bindings.isEmpty {
                    // 空状态
                    VStack(spacing: 16) {
                        Image(systemName: "link.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("暂无绑定")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("请先扫描控制端二维码进行绑定")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    // 绑定列表
                    List {
                        Section {
                            ForEach(bindings) { binding in
                                BindingRowView(binding: binding) {
                                    selectedBinding = binding  // 🔥 直接设置，sheet(item:) 会自动显示
                                }
                            }
                        } header: {
                            Text("已绑定的控制端")
                        } footer: {
                            Text("共 \(bindings.count) 个绑定")
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable {
                        await loadBindings()
                    }
                }
            }
            .navigationTitle("已绑定列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !isLoading {
                        Button(action: {
                            Task {
                                await loadBindings()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            // 🔥 解绑页面（使用 sheet(item:) 确保数据同步，避免白屏）
            .sheet(item: $selectedBinding) { binding in
                UnbindView(binding: binding) {
                    // 解绑成功后从列表中移除
                    bindings.removeAll { $0.bindingId == binding.bindingId }
                    selectedBinding = nil
                }
            }
        }
        .task {
            await loadBindings()
        }
    }
    
    // MARK: - 加载绑定列表
    
    private func loadBindings() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let response = try await APIService.shared.getBindingList()
            
            await MainActor.run {
                bindings = response.bindings
                isLoading = false
            }
            
            print("✅ 成功加载 \(response.count) 个绑定")
            
        } catch {
            await MainActor.run {
                isLoading = false
                
                if let apiError = error as? APIError {
                    switch apiError {
                    case .serverErrorWithMessage(let msg):
                        errorMessage = msg
                    case .serverError(let code):
                        errorMessage = "服务器错误 (\(code))"
                    default:
                        errorMessage = error.localizedDescription
                    }
                } else {
                    errorMessage = error.localizedDescription
                }
            }
            
            print("❌ 加载绑定列表失败: \(error)")
        }
    }
    
}

// MARK: - 绑定行视图

struct BindingRowView: View {
    let binding: APIService.BindingItem
    let onUnbind: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 18))
                    .foregroundColor(.green)
            }
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    // 🔥 优先显示昵称，没有昵称则显示脱敏账号
                    if let nickname = binding.controlNickname, !nickname.isEmpty {
                        Text(nickname)
                            .font(.system(size: 16, weight: .medium))
                    } else {
                        Text(maskUsername(binding.controlUsername))
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                
                if let time = binding.createdAt {
                    Text("绑定时间: \(formatTime(time))")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 解绑按钮
            Button(action: onUnbind) {
                Text("解绑")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
    
    // 🔥 账号脱敏：前2位 + ** + 后2位，小于等于4位直接显示
    private func maskUsername(_ username: String) -> String {
        if username.count <= 4 {
            return username
        }
        let prefix = String(username.prefix(2))
        let suffix = String(username.suffix(2))
        return "\(prefix)**\(suffix)"
    }
    
    // 格式化时间
    private func formatTime(_ isoTime: String) -> String {
        // ISO格式可能带微秒: 2025-11-25T20:38:17.197671
        let inputFormatter = DateFormatter()
        
        // 尝试带微秒的格式
        inputFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        if let date = inputFormatter.date(from: isoTime) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            return outputFormatter.string(from: date)
        }
        
        // 尝试不带微秒的格式
        inputFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = inputFormatter.date(from: isoTime) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            return outputFormatter.string(from: date)
        }
        
        return isoTime
    }
}

// MARK: - Preview

#Preview {
    BindingListView()
}

