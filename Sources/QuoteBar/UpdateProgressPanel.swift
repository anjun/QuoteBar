import AppKit

@MainActor
final class UpdateProgressPanel {
    private let panel: NSPanel
    private let bar: NSProgressIndicator
    private let status: NSTextField
    private let percent: NSTextField

    init(version: String) {
        let width: CGFloat = 340
        let height: CGFloat = 118
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        panel.title = "正在更新到 \(version)"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        status = NSTextField(labelWithString: "正在下载安装包")
        status.font = .systemFont(ofSize: 13)
        status.textColor = .secondaryLabelColor
        status.translatesAutoresizingMaskIntoConstraints = false

        percent = NSTextField(labelWithString: "0%")
        percent.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        percent.alignment = .right
        percent.translatesAutoresizingMaskIntoConstraints = false

        bar = NSProgressIndicator()
        bar.style = .bar
        bar.isIndeterminate = false
        bar.minValue = 0
        bar.maxValue = 1
        bar.doubleValue = 0
        bar.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        content.addSubview(status)
        content.addSubview(percent)
        content.addSubview(bar)
        panel.contentView = content

        NSLayoutConstraint.activate([
            status.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            status.topAnchor.constraint(equalTo: content.topAnchor, constant: 22),
            percent.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            percent.centerYAnchor.constraint(equalTo: status.centerYAnchor),
            percent.leadingAnchor.constraint(greaterThanOrEqualTo: status.trailingAnchor, constant: 8),
            bar.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            bar.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            bar.topAnchor.constraint(equalTo: status.bottomAnchor, constant: 14),
            bar.heightAnchor.constraint(equalToConstant: 14),
        ])
    }

    func show() {
        if let frame = NSScreen.main?.visibleFrame {
            let size = panel.frame.size
            panel.setFrameOrigin(NSPoint(
                x: frame.midX - size.width / 2,
                y: frame.midY - size.height / 2
            ))
        }
        panel.makeKeyAndOrderFront(nil)
    }

    func update(fraction: Double, status text: String) {
        status.stringValue = text
        bar.isIndeterminate = false
        bar.doubleValue = fraction
        percent.stringValue = "\(Int((fraction * 100).rounded()))%"
    }

    func markInstalling() {
        status.stringValue = "正在安装，即将重启"
        bar.isIndeterminate = true
        bar.startAnimation(nil)
        percent.stringValue = ""
    }

    func close() {
        bar.stopAnimation(nil)
        panel.orderOut(nil)
    }
}
