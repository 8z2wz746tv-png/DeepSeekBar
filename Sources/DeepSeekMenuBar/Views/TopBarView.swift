import SwiftUI

struct TopBarView: View {
    let onRefresh: () -> Void
    let onSettings: () -> Void
    let isRefreshing: Bool
    let progress: String

    var body: some View {
        HStack(spacing: 10) {
            if let logo = logoImage {
                Image(nsImage: logo)
                    .resizable()
                    .frame(width: 20, height: 20)
            }

            Link("DeepSeekBar", destination: URL(string: "https://deepseek.com")!)
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            if !progress.isEmpty {
                Text(progress)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.body)
                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
            }
            .buttonStyle(.plain)
            .disabled(isRefreshing)

            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.body)
            }
            .buttonStyle(.plain)
        }
    }

    private var logoImage: NSImage? {
        let url = Bundle.main.url(forResource: "favicon", withExtension: "svg")
            ?? Bundle.module.url(forResource: "favicon", withExtension: "svg")
        if let url {
            return NSImage(contentsOf: url)
        }
        return NSImage(systemSymbolName: "dollarsign.circle.fill", accessibilityDescription: nil)
    }
}
