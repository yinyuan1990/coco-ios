//
//  UnbindView.swift
//  srs
//
//  解绑设备确认页面
//

import SwiftUI

struct UnbindView: View {
    @Environment(\.dismiss) private var dismiss
    
    let binding: APIService.BindingItem
    let onUnbindSuccess: () -> Void
    
    @State private var secondaryPassword: String = ""
    @State private var isUnbinding: Bool = false
    @State private var showResultAlert: Bool = false
    @State private var resultMessage: String = ""
    @State private var isSuccess: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // 设备信息卡片
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.1))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "desktopcomputer")
                                .font(.system(size: 36))
                                .foregroundColor(.red)
                        }
                        
                        VStack(spacing: 8) {
                            Text("确认解绑")
                                .font(.system(size: 20, weight: .semibold))
                            
                            // 显示设备名称
                            Text(displayName)
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                            
                            if let time = binding.createdAt {
                                Text("绑定时间: \(formatTime(time))")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.top, 32)
                    
                    // 警告提示
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        
                        Text("解绑后该控制端将无法远程控制此设备")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
                    
                    // 二级密码输入
                    VStack(alignment: .leading, spacing: 8) {
                        Text("二级密码")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        SecureField("请输入二级密码", text: $secondaryPassword)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // 按钮
                    VStack(spacing: 12) {
                        Button(action: performUnbind) {
                            HStack {
                                if isUnbinding {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("确认解绑")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(secondaryPassword.isEmpty ? Color.gray : Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(secondaryPassword.isEmpty || isUnbinding)
                        
                        Button("取消") {
                            dismiss()
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("解绑设备")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
            }
            .alert(isSuccess ? "解绑成功" : "解绑失败", isPresented: $showResultAlert) {
                Button("确定") {
                    if isSuccess {
                        onUnbindSuccess()
                        dismiss()
                    }
                }
            } message: {
                Text(resultMessage)
            }
        }
    }
    
    // MARK: - 显示名称
    
    private var displayName: String {
        if let nickname = binding.controlNickname, !nickname.isEmpty {
            return nickname
        }
        return maskUsername(binding.controlUsername)
    }
    
    // MARK: - 账号脱敏
    
    private func maskUsername(_ username: String) -> String {
        if username.count <= 4 {
            return username
        }
        let prefix = String(username.prefix(2))
        let suffix = String(username.suffix(2))
        return "\(prefix)**\(suffix)"
    }
    
    // MARK: - 格式化时间
    
    private func formatTime(_ isoTime: String) -> String {
        let inputFormatter = DateFormatter()
        
        inputFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        if let date = inputFormatter.date(from: isoTime) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            return outputFormatter.string(from: date)
        }
        
        inputFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = inputFormatter.date(from: isoTime) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            return outputFormatter.string(from: date)
        }
        
        return isoTime
    }
    
    // MARK: - 执行解绑
    
    private func performUnbind() {
        guard !secondaryPassword.isEmpty else { return }
        
        isUnbinding = true
        
        Task {
            do {
                let response = try await APIService.shared.unbindDevice(
                    bindingId: binding.bindingId,
                    secondaryPassword: secondaryPassword
                )
                
                await MainActor.run {
                    isUnbinding = false
                    isSuccess = true
                    resultMessage = response.message
                    showResultAlert = true
                }
                
                print("✅ 解绑成功: \(response.message)")
                
            } catch {
                await MainActor.run {
                    isUnbinding = false
                    isSuccess = false
                    
                    if let apiError = error as? APIError {
                        switch apiError {
                        case .serverErrorWithMessage(let msg):
                            resultMessage = msg
                        case .serverError(let code):
                            resultMessage = "服务器错误 (\(code))"
                        default:
                            resultMessage = error.localizedDescription
                        }
                    } else {
                        resultMessage = error.localizedDescription
                    }
                    
                    showResultAlert = true
                }
                
                print("❌ 解绑失败: \(error)")
            }
        }
    }
}

#Preview {
    UnbindView(
        binding: APIService.BindingItem(
            bindingId: 1,
            controlUsername: "testuser123",
            controlNickname: "测试用户",
            createdAt: "2025-12-19T10:30:00"
        ),
        onUnbindSuccess: {}
    )
}

