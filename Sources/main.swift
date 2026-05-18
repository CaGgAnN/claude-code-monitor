import AppKit
import Foundation

struct UsageData {
    var sessionPct: Double = 0
    var weeklyPct: Double = 0
    var sessionResetSecs: Int = 0
}

func getToken() -> String? {
    let task = Process()
    task.launchPath = "/usr/bin/security"
    task.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = Pipe()
    try? task.run()
    task.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
          let json = try? JSONSerialization.jsonObject(with: raw.data(using: .utf8)!) as? [String: Any] else { return nil }
    let inner = json["claudeAiOauth"] as? [String: Any] ?? json
    return inner["accessToken"] as? String
}

func fetchUsage(token: String, completion: @escaping (UsageData) -> Void) {
    var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = #"{"model":"claude-haiku-4-5","max_tokens":1,"messages":[{"role":"user","content":"hi"}]}"#.data(using: .utf8)
    URLSession.shared.dataTask(with: request) { _, response, _ in
        var usage = UsageData()
        if let http = response as? HTTPURLResponse {
            let h = http.allHeaderFields
            if let s = h["anthropic-ratelimit-unified-5h-utilization"] as? String { usage.sessionPct = (Double(s) ?? 0) * 100 }
            if let s = h["anthropic-ratelimit-unified-7d-utilization"] as? String { usage.weeklyPct = (Double(s) ?? 0) * 100 }
            if let s = h["anthropic-ratelimit-unified-5h-reset"] as? String {
                usage.sessionResetSecs = max(0, (Int(s) ?? 0) - Int(Date().timeIntervalSince1970))
            }
        }
        DispatchQueue.main.async { completion(usage) }
    }.resume()
}

class DonutView: NSView {
    var percentage: Double = 0 { didSet { needsDisplay = true } }
    var ringColor: NSColor = .white

    override func draw(_ dirtyRect: NSRect) {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius: CGFloat = bounds.width / 2 - 3.5

        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: -270, clockwise: true)
        NSColor.white.withAlphaComponent(0.07).setStroke()
        track.lineWidth = 3.5
        track.stroke()

        if percentage > 0 {
            let end = 90 - (360 * percentage)
            let prog = NSBezierPath()
            prog.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: end, clockwise: true)
            ringColor.setStroke()
            prog.lineWidth = 3.5
            prog.lineCapStyle = .round
            prog.stroke()
        }

        let pct = "\(Int((percentage * 100).rounded()))%"
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .bold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.65),
            .paragraphStyle: para
        ]
        let str = NSAttributedString(string: pct, attributes: attrs)
        let sz = str.size()
        str.draw(at: CGPoint(x: center.x - sz.width/2, y: center.y - sz.height/2))
    }
}

class PopoverVC: NSViewController {
    var sessionDonut = DonutView()
    var weeklyDonut = DonutView()
    var sessionLbl = NSTextField(labelWithString: "Loading...")
    var nextLbl = NSTextField(labelWithString: "Next session: —")
    var weeklyLbl = NSTextField(labelWithString: "Week: —")
    var resetSecs = 0
    var lastFetch = Date()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 92))

        let blur = NSVisualEffectView(frame: view.bounds)
        blur.material = .popover
        blur.blendingMode = .behindWindow
        blur.state = .active
        view.addSubview(blur)

        sessionDonut.frame = NSRect(x: 14, y: 21, width: 50, height: 50)
        sessionDonut.ringColor = NSColor.white.withAlphaComponent(0.55)
        view.addSubview(sessionDonut)

        let curLbl = label("CURRENT", size: 7)
        curLbl.frame = NSRect(x: 14, y: 8, width: 50, height: 10)
        curLbl.alignment = .center
        view.addSubview(curLbl)

        let sep1 = NSBox(frame: NSRect(x: 72, y: 16, width: 1, height: 58))
        sep1.boxType = .separator
        view.addSubview(sep1)

        weeklyDonut.frame = NSRect(x: 82, y: 21, width: 50, height: 50)
        weeklyDonut.ringColor = NSColor.white.withAlphaComponent(0.32)
        view.addSubview(weeklyDonut)

        let wkLbl = label("WEEKLY", size: 7)
        wkLbl.frame = NSRect(x: 82, y: 8, width: 50, height: 10)
        wkLbl.alignment = .center
        view.addSubview(wkLbl)

        let sep2 = NSBox(frame: NSRect(x: 140, y: 16, width: 1, height: 58))
        sep2.boxType = .separator
        view.addSubview(sep2)

        let title = label("Claude Code", size: 13)
        title.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        title.textColor = NSColor.white.withAlphaComponent(0.8)
        title.frame = NSRect(x: 150, y: 68, width: 140, height: 16)
        view.addSubview(title)

        sessionLbl.frame = NSRect(x: 150, y: 52, width: 140, height: 14)
        sessionLbl.font = NSFont.systemFont(ofSize: 10.5)
        sessionLbl.textColor = NSColor.white.withAlphaComponent(0.3)
        view.addSubview(sessionLbl)

        nextLbl.frame = NSRect(x: 150, y: 36, width: 140, height: 14)
        nextLbl.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        nextLbl.textColor = NSColor.white.withAlphaComponent(0.5)
        view.addSubview(nextLbl)

        weeklyLbl.frame = NSRect(x: 150, y: 22, width: 140, height: 14)
        weeklyLbl.font = NSFont.systemFont(ofSize: 10)
        weeklyLbl.textColor = NSColor.white.withAlphaComponent(0.2)
        view.addSubview(weeklyLbl)

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
    }

    func label(_ s: String, size: CGFloat) -> NSTextField {
        let f = NSTextField(labelWithString: s)
        f.font = NSFont.systemFont(ofSize: size, weight: .semibold)
        f.textColor = NSColor.white.withAlphaComponent(0.22)
        return f
    }

    func update(_ u: UsageData) {
        sessionDonut.percentage = u.sessionPct / 100
        weeklyDonut.percentage = ceil(u.weeklyPct) / 100
        sessionLbl.stringValue = "\(Int(u.sessionPct.rounded()))% used"
        weeklyLbl.stringValue = "Week: \(Int(ceil(u.weeklyPct)))% used"
        resetSecs = u.sessionResetSecs
        lastFetch = Date()
    }

    func tick() {
        let remaining = max(0, resetSecs - Int(Date().timeIntervalSince(lastFetch)))
        nextLbl.stringValue = String(format: "Next session: %dh %02dm", remaining/3600, (remaining%3600)/60)
    }
}


func makeRobotIcon(size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
        let s = size
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(x: s*2/16, y: s*4/14, width: s*12/16, height: s*9/14)).fill()
        NSBezierPath(rect: NSRect(x: 0, y: s*4/14, width: s*2/16, height: s*5/14)).fill()
        NSBezierPath(rect: NSRect(x: s*14/16, y: s*4/14, width: s*2/16, height: s*5/14)).fill()
        NSBezierPath(rect: NSRect(x: s*4/16, y: 0, width: s*2/16, height: s*4/14)).fill()
        NSBezierPath(rect: NSRect(x: s*10/16, y: 0, width: s*2/16, height: s*4/14)).fill()
        NSGraphicsContext.current?.compositingOperation = .clear
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(x: s*5/16, y: s*6/14, width: s*2/16, height: s*3/14)).fill()
        NSBezierPath(rect: NSRect(x: s*9/16, y: s*6/14, width: s*2/16, height: s*3/14)).fill()
        NSGraphicsContext.current?.compositingOperation = .sourceOver
        return true
    }
    return img
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusItem: NSStatusItem!
    var panel: NSPanel?
    let vc = PopoverVC()
    var token: String?

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)
        token = getToken()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            btn.image = makeRobotIcon(size: 16)
            btn.image?.isTemplate = true
            btn.title = "  --%"
            btn.imagePosition = .imageLeft
            btn.action = #selector(toggle)
            btn.sendAction(on: [.leftMouseUp])
            btn.target = self
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit Claude Monitor", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = nil

        // Sag tik icin
        NSEvent.addLocalMonitorForEvents(matching: .rightMouseUp) { [weak self] event in
            if let btn = self?.statusItem.button, btn.window == event.window {
                self?.statusItem.menu = menu
                self?.statusItem.button?.performClick(nil)
                self?.statusItem.menu = nil
            }
            return event
        }

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 92),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.level = .popUpMenu
        p.collectionBehavior = [.canJoinAllSpaces, .transient]
        p.contentViewController = vc
        p.delegate = self
        p.hasShadow = true
        self.panel = p
        // Corner radius
        if let cv = p.contentView {
            cv.wantsLayer = true
            cv.layer?.cornerRadius = 13
            cv.layer?.masksToBounds = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.refresh() }
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.refresh() }
    }

    func refresh() {
        guard let token else { return }
        fetchUsage(token: token) { [weak self] data in
            self?.vc.update(data)
            let pct = Int(data.sessionPct.rounded())
            self?.statusItem.button?.title = "  \(pct)%"
        }
    }

    @objc func toggle() {
        guard let panel = panel, let btn = statusItem.button else { return }
        if panel.isVisible {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.15
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().alphaValue = 0
            }) {
                panel.orderOut(nil)
                panel.alphaValue = 1
            }
        } else {
            let btnFrame = btn.window?.convertToScreen(btn.frame) ?? .zero
            let x = btnFrame.midX - 150
            let y = btnFrame.minY - 92 - 4
            panel.setFrameOrigin(NSPoint(x: x, y: y))
            panel.alphaValue = 0
            panel.makeKeyAndOrderFront(nil)
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.2
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            })
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        panel?.orderOut(nil)
    }
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
