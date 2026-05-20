import ServiceManagement
import OSLog

struct LaunchAtLoginService {
    private let logger = Logger(subsystem: "com.deepseek.menubar", category: "LaunchAtLogin")

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            logger.error("登录项设置失败: \(error.localizedDescription)")
        }
    }

    var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled: return "已启用"
        case .notRegistered: return "未启用"
        case .notFound: return "未找到"
        case .requiresApproval: return "需授权"
        @unknown default: return "未知"
        }
    }
}
