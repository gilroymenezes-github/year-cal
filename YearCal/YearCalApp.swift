import SwiftUI
import WidgetKit
import ServiceManagement
import AppKit

/// Menu bar app: a calendar icon in the menu bar that toggles a tall 2 × 7 panel
/// (Dec of the previous year → Jan of the next), pinned to the top-right of the screen.
@main
struct YearCalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // No windows; everything lives in the status item + panel.
        Settings { EmptyView() }
    }
}

// MARK: - Panel state

final class PanelModel: ObservableObject {
    @Published var now = Date()
    @Published var year = MonthPicker.currentYear()

    var currentYear: Int { MonthPicker.currentYear(now) }

    /// Called every time the panel opens: refresh "today" and go back to this year.
    func reset() {
        now = Date()
        year = currentYear
    }
}

// MARK: - App delegate: status item + pinned panel

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: NSPanel!
    private let model = PanelModel()
    private var outsideClickMonitor: Any?
    private var keyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // First launch: start at login by default (checkbox in the panel turns it off).
        let key = "didSetUpLoginItem"
        if !UserDefaults.standard.bool(forKey: key) {
            try? SMAppService.mainApp.register()
            UserDefaults.standard.set(true, forKey: key)
        }
        WidgetCenter.shared.reloadAllTimelines()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "YearCal")
            button.target = self
            button.action = #selector(togglePanel)
        }
        buildPanel()
    }

    private func buildPanel() {
        let root = PanelView(model: model, onQuit: { NSApp.terminate(nil) })
        let host = NSHostingView(rootView: root)
        let size = host.fittingSize

        let background = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 12
        background.layer?.masksToBounds = true

        host.frame = background.bounds
        host.autoresizingMask = [.width, .height]
        background.addSubview(host)

        panel = KeyablePanel(contentRect: background.frame,
                             styleMask: [.borderless, .nonactivatingPanel],
                             backing: .buffered,
                             defer: false)
        panel.contentView = background
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    }

    @objc private func togglePanel() {
        panel.isVisible ? hidePanel() : showPanel()
    }

    private func showPanel() {
        model.reset()

        // Pin to the top-right corner of the screen the menu bar icon is on.
        let screen = statusItem.button?.window?.screen ?? NSScreen.main ?? NSScreen.screens[0]
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let margin: CGFloat = 8
        panel.setFrameOrigin(NSPoint(x: visible.maxX - size.width - margin,
                                     y: visible.maxY - size.height - margin))

        panel.orderFrontRegardless()
        panel.makeKey()
        statusItem.button?.highlight(true)

        // Close when clicking anywhere outside (other apps / desktop).
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            self?.hidePanel()
        }
        // Close on Escape.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.hidePanel()
                return nil
            }
            return event
        }
    }

    private func hidePanel() {
        panel.orderOut(nil)
        statusItem.button?.highlight(false)
        if let m = outsideClickMonitor { NSEvent.removeMonitor(m); outsideClickMonitor = nil }
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }
}

/// Borderless panels can't become key by default; this lets buttons and Escape work.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

// MARK: - Panel content

struct PanelView: View {
    @ObservedObject var model: PanelModel
    let onQuit: () -> Void

    @State private var openAtLogin = SMAppService.mainApp.status == .enabled

    private let width: CGFloat = 300

    /// Tall, but never taller than the screen.
    private var gridHeight: CGFloat {
        let visible = NSScreen.main?.visibleFrame.height ?? 900
        return max(420, min(720, visible - 130))
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Button { model.year -= 1 } label: {
                    Image(systemName: "chevron.left").frame(width: 22, height: 22)
                }
                Text(String(model.year))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(model.year == model.currentYear ? Color.primary : Color.accentColor)
                    .frame(minWidth: 48)
                Button { model.year += 1 } label: {
                    Image(systemName: "chevron.right").frame(width: 22, height: 22)
                }
                Spacer()
                if model.year != model.currentYear {
                    Button("Today") { model.year = model.currentYear }
                        .font(.system(size: 12, weight: .medium))
                } else {
                    Text(model.now, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.borderless)

            MonthsGrid(months: MonthPicker.withBookends(model.year), columns: 2,
                       today: model.now, focusYear: model.year)
                .frame(width: width, height: gridHeight)

            Divider()

            HStack {
                Toggle("Open at login", isOn: Binding(
                    get: { openAtLogin },
                    set: { setOpenAtLogin($0) }
                ))
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
                Spacer()
                Button("Quit", action: onQuit)
                    .buttonStyle(.borderless)
                    .font(.system(size: 11))
            }
        }
        .padding(14)
        .frame(width: width + 28)
    }

    private func setOpenAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {}
        openAtLogin = SMAppService.mainApp.status == .enabled
    }
}
