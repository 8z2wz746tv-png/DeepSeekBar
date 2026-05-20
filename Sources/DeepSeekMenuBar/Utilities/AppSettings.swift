import Foundation

enum AppSettings {
    static var refreshIntervalMinutes: Int {
        get { UserDefaults.standard.integer(forKey: "refresh_interval").nonzeroOr(15) }
        set { UserDefaults.standard.set(newValue, forKey: "refresh_interval") }
    }

    static var lowBalanceThreshold: Double {
        get {
            let val = UserDefaults.standard.double(forKey: "balance_threshold")
            return val > 0 ? val : 10
        }
        set { UserDefaults.standard.set(newValue, forKey: "balance_threshold") }
    }

    static var lowBalanceNotificationEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "low_balance_enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "low_balance_enabled") }
    }

    static var perRequestNotificationEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "per_request_enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "per_request_enabled") }
    }

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            "refresh_interval": 15,
            "balance_threshold": 10.0,
            "low_balance_enabled": false,
            "per_request_enabled": false
        ])
    }
}

private extension Int {
    func nonzeroOr(_ fallback: Int) -> Int { self > 0 ? self : fallback }
}
