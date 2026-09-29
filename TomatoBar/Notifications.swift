import SwiftUI

/// A silent, persistent reminder independent of macOS notification permissions.
final class TBReminder {
    private var panel: NSPanel?
    func show(timer: TBTimer) {
        guard timer.state.needsAttention else { return }
        if panel == nil {
            let window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 310),
                                 styleMask: [.titled], backing: .buffered, defer: false)
            window.title = "番茄钟 · 时间到了"
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.hidesOnDeactivate = false
            window.isReleasedWhenClosed = false
            panel = window
        }
        let content = NSHostingView(rootView: ReminderView(timer: timer) { [weak self] in self?.dismiss() })
        panel?.contentView = content
        panel?.setContentSize(content.fittingSize)
        panel?.center()
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
        panel?.orderFrontRegardless()
    }
    func dismiss() { panel?.orderOut(nil) }
}

private struct ReminderView: View {
    @ObservedObject var timer: TBTimer
    let dismiss: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: timer.state.phase == .workFinished ? "checkmark.circle.fill" : "sun.max.fill")
                .font(.system(size: 44)).foregroundColor(.accentColor)
            Text(timer.phaseLabel).font(.system(size: 26, weight: .semibold))
            Text(timer.state.phase == .workFinished
                 ? "「\(timer.state.name)」已完成。\n站起来活动一下，让眼睛休息一会儿。"
                 : "休息结束了。\n准备好后，再开始下一轮专注。")
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Text("等待你确认后，才会开始下一段计时。")
                .font(.caption).foregroundColor(.secondary)
            HStack(spacing: 14) {
                Button("结束本组") {
                    timer.stop()
                    // stop() persists the newly idle state through change(). If that write
                    // failed the completed record is still memory-only, so keep the panel
                    // open with its red warning instead of dismissing into a bare menu-bar
                    // dot (P27). Clicking again after the disk recovers dismisses normally.
                    if timer.storageError == nil { dismiss() }
                }
                Button(timer.state.phase == .workFinished ? "开始休息 · \(timer.restMinutes) 分钟" : "开始下一轮") {
                    if timer.state.phase == .workFinished { timer.startRest() } else { timer.startWork() }
                    if !timer.state.needsAttention { dismiss() }
                }.buttonStyle(.borderedProminent)
            }
            if let error = timer.storageError {
                HStack(spacing: 10) {
                    Text(error).font(.caption).foregroundColor(.red)
                    Button(timer.storageRetryTitle) { timer.retryStorage() }.font(.caption)
                }
            }
        }.padding(30).frame(width: 420)
    }
}
