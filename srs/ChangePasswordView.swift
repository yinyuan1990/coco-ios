//
//  ChangePasswordView.swift
//  srs
//
//  修改密码独立页面
//

import SwiftUI

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var oldPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var secondaryPassword: String = ""
    
    @State private var isChanging: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var isSuccess: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 图标
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                            .padding(.top, 30)
                        
                        // 提示文字
                        Text("请输入原密码和新密码")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        // 输入区域
                        VStack(spacing: 0) {
                            // 原密码
                            PasswordInputRow(
                                title: "原密码",
                                placeholder: "请输入原密码",
                                text: $oldPassword
                            )
                            
                            Divider()
                                .padding(.leading, 16)
                            
                            // 新密码
                            PasswordInputRow(
                                title: "新密码",
                                placeholder: "请输入新密码（至少6位）",
                                text: $newPassword
                            )
                            
                            Divider()
                                .padding(.leading, 16)
                            
                            // 确认新密码
                            PasswordInputRow(
                                title: "确认密码",
                                placeholder: "请再次输入新密码",
                                text: $confirmPassword
                            )
                            
                            Divider()
                                .padding(.leading, 16)
                            
                            // 二级密码
                            PasswordInputRow(
                                title: "二级密码",
                                placeholder: "请输入二级密码",
                                text: $secondaryPassword
                            )
                        }
                        .background(Color.white)
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                        
                        // 提交按钮
                        Button(action: {
                            handleChangePassword()
                        }) {
                            HStack {
                                if isChanging {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text(isChanging ? "修改中..." : "确认修改")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isChanging ? Color.gray : Color.blue)
                            .cornerRadius(12)
                        }
                        .disabled(isChanging)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("修改密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("确定") {
                if isSuccess {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - 修改密码逻辑
    private func handleChangePassword() {
        // 输入验证
        guard !oldPassword.isEmpty else {
            showError("请输入原密码")
            return
        }
        
        guard !newPassword.isEmpty else {
            showError("请输入新密码")
            return
        }
        
        guard newPassword.count >= 6 else {
            showError("新密码长度至少6位")
            return
        }
        
        guard newPassword == confirmPassword else {
            showError("两次输入的新密码不一致")
            return
        }
        
        guard oldPassword != newPassword else {
            showError("新密码不能与原密码相同")
            return
        }
        
        guard !secondaryPassword.isEmpty else {
            showError("请输入二级密码")
            return
        }
        
        // 开始修改
        isChanging = true
        
        Task {
            do {
                let _ = try await APIService.shared.changePassword(
                    oldPassword: oldPassword,
                    newPassword: newPassword,
                    secondaryPassword: secondaryPassword
                )
                
                await MainActor.run {
                    isChanging = false
                    isSuccess = true
                    alertTitle = "修改成功"
                    alertMessage = "密码已成功修改"
                    showAlert = true
                }
                
            } catch {
                await MainActor.run {
                    isChanging = false
                    
                    if let apiError = error as? APIError {
                        switch apiError {
                        case .serverErrorWithMessage(let message):
                            showError(message)
                        case .serverError(let statusCode):
                            showError("服务器错误（状态码：\(statusCode)）")
                        default:
                            showError("修改密码失败，请重试")
                        }
                    } else {
                        showError("网络错误，请检查网络连接")
                    }
                }
            }
        }
    }
    
    private func showError(_ message: String) {
        isSuccess = false
        alertTitle = "修改失败"
        alertMessage = message
        showAlert = true
    }
}

// MARK: - 密码输入行组件
struct PasswordInputRow: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .frame(width: 80, alignment: .leading)
            
            SecureField(placeholder, text: $text)
                .font(.system(size: 16))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - 预览
#Preview {
    ChangePasswordView()
}

