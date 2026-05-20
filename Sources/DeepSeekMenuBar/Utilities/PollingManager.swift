import Foundation
import Combine

final class PollingManager: @unchecked Sendable {
    private var balanceCancellable: AnyCancellable?
    private var syncCancellable: AnyCancellable?
    private var notificationCancellable: AnyCancellable?

    func runBalanceRefresh(interval: TimeInterval, action: @escaping @Sendable () async -> Void) {
        balanceCancellable?.cancel()
        balanceCancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { @Sendable _ in
                Task { await action() }
            }

        Task { await action() }
    }

    func runCCSwitchSync(interval: TimeInterval = 120, action: @escaping @Sendable () async -> Void) {
        syncCancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { @Sendable _ in
                Task { await action() }
            }

        Task { await action() }
    }

    func runNotificationPoll(interval: TimeInterval = 3, action: @escaping @Sendable () async -> Void) {
        notificationCancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { @Sendable _ in
                Task { await action() }
            }

        Task { await action() }
    }

    func stopAll() {
        balanceCancellable?.cancel()
        syncCancellable?.cancel()
        notificationCancellable?.cancel()
    }
}
