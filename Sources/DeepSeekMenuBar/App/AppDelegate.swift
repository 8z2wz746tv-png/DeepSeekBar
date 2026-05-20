import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?
    private let dashboardVM = DashboardViewModel()
    private lazy var settingsVM = SettingsViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppSettings.registerDefaults()
        setupStatusItem()
        setupPopover()
        dashboardVM.onAppear()
    }

    // MARK: - Status bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            updateStatusIcon(button: button)
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func updateStatusIcon(button: NSStatusBarButton) {
        // Prefer .icns for reliable template rendering at menu bar size (multiple resolutions)
        let icon: NSImage? = {
            if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
               let image = NSImage(contentsOf: url) {
                return image
            }
            if let url = Bundle.main.url(forResource: "favicon", withExtension: "svg")
                ?? Bundle.module.url(forResource: "favicon", withExtension: "svg"),
               let image = NSImage(contentsOf: url) {
                return image
            }
            return NSImage(systemSymbolName: "dollarsign.circle", accessibilityDescription: nil)
        }()
        icon?.size = NSSize(width: 18, height: 18)
        icon?.isTemplate = true
        button.image = icon
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent

        if event?.type == .rightMouseUp {
            showContextMenu(sender)
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            // 面板打开时缓存超过 15 分钟则自动刷新
            if let last = dashboardVM.balanceStore.lastRefresh, Date().timeIntervalSince(last) > 900 {
                dashboardVM.refreshBalance()
            } else if dashboardVM.balanceStore.lastRefresh == nil {
                dashboardVM.refreshBalance()
            }
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "打开设置", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 DeepSeekBar", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: AppTheme.panelWidth, height: AppTheme.panelHeight)
        popover.behavior = .transient
        popover.animates = true

        let dashboard = DashboardView(viewModel: dashboardVM) { [weak self] in
            self?.popover.performClose(nil)
            self?.openSettings()
        }

        popover.contentViewController = NSHostingController(rootView: dashboard)
    }

    // MARK: - Settings window

    @objc private func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(viewModel: settingsVM) { [weak self] in
            self?.dashboardVM.refreshBalance()
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 420),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "DeepSeekBar 设置"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
