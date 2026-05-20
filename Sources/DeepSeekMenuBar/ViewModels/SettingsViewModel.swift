import Foundation
import AppKit
import OSLog

final class SettingsViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.deepseek.menubar", category: "SettingsVM")

    private let keychain = KeychainService()
    private let launchAtLogin = LaunchAtLoginService()

    @Published var apiKey: String = ""
    @Published var isKeyVisible = false
    @Published var launchAtLoginEnabled = false
    @Published var successMessage: String?
    @Published var errorMessage: String?

    var refreshIntervalMinutes: Int {
        get { AppSettings.refreshIntervalMinutes }
        set { AppSettings.refreshIntervalMinutes = newValue }
    }

    var lowBalanceThreshold: Double {
        get { AppSettings.lowBalanceThreshold }
        set { AppSettings.lowBalanceThreshold = newValue }
    }

    var lowBalanceNotificationEnabled: Bool {
        get { AppSettings.lowBalanceNotificationEnabled }
        set { AppSettings.lowBalanceNotificationEnabled = newValue }
    }

    var perRequestNotificationEnabled: Bool {
        get { AppSettings.perRequestNotificationEnabled }
        set { AppSettings.perRequestNotificationEnabled = newValue }
    }

    var launchAtLoginStatus: String { launchAtLogin.statusDescription }

    let refreshIntervalOptions: [Int] = [5, 15, 30, 60]

    func onAppear() {
        apiKey = keychain.load() ?? ""
        launchAtLoginEnabled = launchAtLogin.isEnabled
    }

    func saveAPIKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            keychain.delete()
            apiKey = ""
            successMessage = "API Key 已删除"
        } else {
            apiKey = trimmed
            keychain.save(key: trimmed)
            successMessage = "API Key 已保存"
        }
    }

    func deleteAPIKey() {
        keychain.delete()
        apiKey = ""
        successMessage = "API Key 已删除"
    }

    func copyAPIKey(_ currentValue: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(currentValue, forType: .string)
        successMessage = "已复制到剪贴板"
    }

    func toggleLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin.setEnabled(enabled)
        launchAtLoginEnabled = launchAtLogin.isEnabled
    }
}
