import AppKit
import SwiftUI

/// Shows a small "psst, lunch" panel under the menu bar icon at the chosen Oslo time on weekdays,
/// but only if someone is actually at the Mac right then. Missed nudges are dropped.
@MainActor
final class LunchNudge {
    static let enabledKey = "lunchNudgeEnabled"
    static let minuteOfDayKey = "lunchNudgeMinuteOfDay"
    static let defaultMinuteOfDay = 11 * 60
    static let choices = Array(stride(from: 10 * 60, through: 13 * 60, by: 15))

    private static let visibleFor: Duration = .seconds(20)
    private static let lateTolerance: TimeInterval = 60
    private static let idleLimit: TimeInterval = 5 * 60
    private static let oslo: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Oslo")!
        return calendar
    }()

    private let anchor: () -> NSRect?
    private let onOpen: () -> Void
    private var timer: DispatchSourceTimer?
    private var lastTarget: Date?
    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?
    private var scheduledMinuteOfDay: Int?

    init(anchor: @escaping () -> NSRect?, onOpen: @escaping () -> Void) {
        self.anchor = anchor
        self.onOpen = onOpen
        UserDefaults.standard.register(defaults: [Self.enabledKey: true, Self.minuteOfDayKey: Self.defaultMinuteOfDay])
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.scheduledMinuteOfDay != Self.minuteOfDay else { return }
                self.schedule()
            }
        }
        schedule()
    }

    static func format(_ minuteOfDay: Int) -> String {
        String(format: "%02d:%02d", minuteOfDay / 60, minuteOfDay % 60)
    }

    private static var minuteOfDay: Int {
        UserDefaults.standard.integer(forKey: minuteOfDayKey)
    }

    func show() {
        guard let anchor = anchor(), let screen = NSScreen.screens.first(where: { $0.frame.intersects(anchor) }) else { return }
        dismiss(animated: false)

        let host = NSHostingView(rootView: NudgeView { [weak self] in
            self?.dismiss(animated: true)
            self?.onOpen()
        })
        host.frame.size = host.fittingSize

        let background = NSVisualEffectView(frame: host.frame)
        background.material = .popover
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 14
        background.layer?.cornerCurve = .continuous
        background.layer?.masksToBounds = true
        background.addSubview(host)

        let visible = screen.visibleFrame
        let size = host.frame.size
        let x = min(max(anchor.midX - size.width / 2, visible.minX + 8), visible.maxX - size.width - 8)
        let frame = NSRect(x: x, y: visible.maxY - size.height - 8, width: size.width, height: size.height)

        let panel = NSPanel(contentRect: frame.offsetBy(dx: 0, dy: 8), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentView = background
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.invalidateShadow()
        self.panel = panel

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(frame, display: true)
        }

        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: Self.visibleFor)
            guard !Task.isCancelled else { return }
            self?.dismiss(animated: true)
        }
    }

    private func dismiss(animated: Bool) {
        dismissTask?.cancel()
        dismissTask = nil
        guard let panel else { return }
        self.panel = nil
        guard animated else {
            panel.close()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            panel.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated { panel.close() }
        }
    }

    private func schedule() {
        timer?.cancel()
        let minuteOfDay = Self.minuteOfDay
        scheduledMinuteOfDay = minuteOfDay
        let target = Self.nextLunch(after: max(.now, lastTarget ?? .distantPast), minuteOfDay: minuteOfDay)
        let timer = DispatchSource.makeTimerSource(flags: .strict, queue: .main) // strict so App Nap cannot coalesce it past the target time
        timer.schedule(wallDeadline: DispatchWallTime(timespec: timespec(tv_sec: Int(target.timeIntervalSince1970), tv_nsec: 0)))
        timer.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.fire(target: target) }
        }
        timer.resume()
        self.timer = timer
    }

    private func fire(target: Date) {
        lastTarget = target
        defer { schedule() }
        let onTime = Date.now.timeIntervalSince(target) < Self.lateTolerance
        guard onTime, UserDefaults.standard.bool(forKey: Self.enabledKey), Self.userIsPresent else { return }
        show()
    }

    private static func nextLunch(after date: Date, minuteOfDay: Int) -> Date {
        let time = DateComponents(hour: minuteOfDay / 60, minute: minuteOfDay % 60, second: 0)
        var candidate = date
        repeat {
            candidate = oslo.nextDate(after: candidate, matching: time, matchingPolicy: .nextTime)!
        } while oslo.isDateInWeekend(candidate)
        return candidate
    }

    private static var userIsPresent: Bool {
        let session = CGSessionCopyCurrentDictionary() as? [String: Any] ?? [:]
        let locked = session["CGSSessionScreenIsLocked"] as? Bool ?? false
        let onConsole = session[kCGSessionOnConsoleKey as String] as? Bool ?? true
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
        return !locked && onConsole && idle < idleLimit && CGDisplayIsAsleep(CGMainDisplayID()) == 0
    }
}

private struct NudgeView: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Text("🍽️").font(.title2)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Psst… det er lunsjtid")
                        .font(.headline)
                    Text("Klikk for å se dagens meny")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize()
    }
}
