import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    let onRefreshBalance: () -> Void

    @State private var tempAPIKey: String = ""
    @State private var tempRefreshInterval: Int = 15
    @State private var tempThreshold: Double = 10
    @State private var tempLowBalanceEnabled = false
    @State private var tempPerRequestEnabled = false

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("通用", systemImage: "gearshape") }

            accountTab
                .tabItem { Label("账户", systemImage: "key.fill") }

            notificationsTab
                .tabItem { Label("提醒", systemImage: "bell.fill") }
        }
        .frame(width: 420, height: 400)
        .onAppear {
            viewModel.onAppear()
            tempAPIKey = viewModel.apiKey
            tempRefreshInterval = viewModel.refreshIntervalMinutes
            tempThreshold = viewModel.lowBalanceThreshold
            tempLowBalanceEnabled = viewModel.lowBalanceNotificationEnabled
            tempPerRequestEnabled = viewModel.perRequestNotificationEnabled
        }
    }

    // MARK: - General tab

    private var generalTab: some View {
        Form {
            Section("启动项") {
                Toggle("开机自动启动", isOn: Binding(
                    get: { viewModel.launchAtLoginEnabled },
                    set: { viewModel.toggleLaunchAtLogin($0) }
                ))

                HStack {
                    Text("状态")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(viewModel.launchAtLoginStatus)
                        .foregroundColor(.secondary)
                }
                .font(.caption)
            }

            Section("余额刷新间隔") {
                Picker("刷新间隔", selection: $tempRefreshInterval) {
                    ForEach(viewModel.refreshIntervalOptions, id: \.self) { interval in
                        Text("\(interval) 分钟").tag(interval)
                    }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: tempRefreshInterval) { _, newValue in
                    viewModel.refreshIntervalMinutes = newValue
                }
            }

            if let success = viewModel.successMessage {
                statusText(success, color: .green)
            }
            if let error = viewModel.errorMessage {
                statusText(error, color: .red)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Account tab

    private var accountTab: some View {
        Form {
            Section("API Key") {
                HStack {
                    if viewModel.isKeyVisible {
                        TextField("sk-...", text: $tempAPIKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("sk-...", text: $tempAPIKey)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button(action: {
                        viewModel.isKeyVisible.toggle()
                    }) {
                        Image(systemName: viewModel.isKeyVisible ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                    .help(viewModel.isKeyVisible ? "隐藏" : "显示")
                }

                HStack {
                    Button("保存") {
                        viewModel.apiKey = tempAPIKey
                        viewModel.saveAPIKey()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button("复制") {
                        viewModel.copyAPIKey(tempAPIKey)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("删除", role: .destructive) {
                        tempAPIKey = ""
                        viewModel.apiKey = ""
                        viewModel.deleteAPIKey()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Section("操作") {
                Button("刷新余额") {
                    onRefreshBalance()
                }
            }

            if let success = viewModel.successMessage {
                statusText(success, color: .green)
            }
            if let error = viewModel.errorMessage {
                statusText(error, color: .red)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Notifications tab

    private var notificationsTab: some View {
        Form {
            Section("余额提醒") {
                Toggle("低余额通知", isOn: $tempLowBalanceEnabled)
                    .onChange(of: tempLowBalanceEnabled) { _, newValue in
                        viewModel.lowBalanceNotificationEnabled = newValue
                    }

                HStack {
                    Text("阈值")
                    TextField("CNY", value: $tempThreshold, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onChange(of: tempThreshold) { _, newValue in
                            viewModel.lowBalanceThreshold = newValue
                        }
                }
            }

            Section("使用通知") {
                Toggle("每次 API 调用通知", isOn: $tempPerRequestEnabled)
                    .onChange(of: tempPerRequestEnabled) { _, newValue in
                        viewModel.perRequestNotificationEnabled = newValue
                    }

                Button("申请通知权限") {
                    Task {
                        _ = await NotificationService().requestPermission()
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func statusText(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(color)
    }
}
