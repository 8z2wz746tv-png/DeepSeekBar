import UserNotifications
import OSLog

struct NotificationService {
    private let logger = Logger(subsystem: "com.deepseek.menubar", category: "Notification")
    private var center: UNUserNotificationCenter { .current() }

    func requestPermission() async -> Bool {
        guard Bundle.main.bundleIdentifier != nil else {
            logger.warning("无法请求通知权限：应用未在 app bundle 中运行")
            return false
        }
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            logger.error("通知权限请求失败: \(error.localizedDescription)")
            return false
        }
    }

    func sendLowBalanceNotification(balance: Double, threshold: Double) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = "DeepSeek 余额不足"
        content.body = "当前余额 ¥\(String(format: "%.2f", balance))，低于阈值 ¥\(String(format: "%.2f", threshold))"
        content.sound = .default
        content.interruptionLevel = .active

        let request = UNNotificationRequest(
            identifier: "low-balance-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error {
                logger.error("发送低余额通知失败: \(error.localizedDescription)")
            }
        }
    }

    func sendUsageNotification(records: [UsageRecord]) {
        guard Bundle.main.bundleIdentifier != nil, !records.isEmpty else { return }

        for record in records {
            let content = UNMutableNotificationContent()
            let modelName = PricingService.modelDisplayName(record.model)
            let costStr = record.cost.map { String(format: "$%.4f", $0) } ?? "N/A"
            content.title = "DeepSeek 调用"
            content.body = "\(modelName) · \(costStr) · \(FormatUtils.tokens(record.totalTokens))"
            content.sound = nil
            content.interruptionLevel = .passive

            let request = UNNotificationRequest(
                identifier: "usage-\(record.id)",
                content: content,
                trigger: nil
            )

            center.add(request) { error in
                if let error {
                    self.logger.error("发送使用通知失败: \(error.localizedDescription)")
                }
            }
        }
    }
}
