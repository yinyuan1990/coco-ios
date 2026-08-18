//
//  DeviceIdInfoView.swift
//  srs
//
//  显示设备ID信息（从登录页空白区域点击进入）
//  ⭐ 2026-08-14 aihj：界面风格对齐登录页（淡蓝渐变背景、图标标签+灰底圆角框、蓝色圆角按钮）
//

import SwiftUI

struct DeviceIdInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let deviceId = DeviceIDManager.shared.getDeviceID()
    private let bundleId = Bundle.main.bundleIdentifier ?? "未知"
    
    @State private var copied = false
    
    var body: some View {
        ZStack {
            // 与登录页一致的淡蓝渐变背景
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.white]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部关闭按钮（与登录页同款）
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
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
                
                VStack(spacing: 20) {
                    // 标题区
                    VStack(spacing: 12) {
                        Image(systemName: "iphone.badge.checkmark")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text("设备信息")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .padding(.bottom, 10)
                    
                    // 设备ID（登录页表单同款：图标标签 + 灰底圆角框）
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "number")
                                .foregroundColor(.gray)
                                .frame(width: 20)
                            Text("设备ID")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        
                        Text(deviceId)
                            .font(.system(size: 15, weight: .medium, design: .monospaced))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    // Bundle ID
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "app")
                                .foregroundColor(.gray)
                                .frame(width: 20)
                            Text("Bundle ID")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        
                        Text(bundleId)
                            .font(.system(size: 15, weight: .medium, design: .monospaced))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    // 系统信息
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "gearshape")
                                .foregroundColor(.gray)
                                .frame(width: 20)
                            Text("系统")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        
                        Text("iOS \(UIDevice.current.systemVersion) · \(UIDevice.current.name)")
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    // 复制按钮（登录页同款：蓝色圆角、通栏）
                    Button(action: {
                        UIPasteboard.general.string = deviceId
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copied = false
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 14))
                            Text(copied ? "已复制" : "复制设备ID")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(copied ? Color.green : Color.blue)
                        .cornerRadius(12)
                    }
                    .padding(.top, 10)
                }
                .padding(.horizontal, 30)
                
                Spacer()
                Spacer()
            }
        }
    }
}

#Preview {
    DeviceIdInfoView()
}
