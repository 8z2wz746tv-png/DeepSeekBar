import SwiftUI

struct SetupGuideView: View {
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.fill")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)

            Text("欢迎使用 DeepSeekBar")
                .font(.title3)
                .fontWeight(.semibold)

            Text("请先配置您的 DeepSeek API Key，以开始查看账户余额和使用统计。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("打开设置") {
                onOpenSettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
