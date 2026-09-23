import AppKit
import Carbon
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let store = MenuStore()
    private var hotKeys: HotKeySettings!
    private var lunchNudge: LunchNudge!
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var refreshTimer: Timer?
    private var outsideClickMonitor: Any?
    private var keyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "fork.knife", accessibilityDescription: "Kantine")
            button.toolTip = "Kantine"
            button.target = self
            button.action = #selector(togglePopover)
        }

        hotKeys = HotKeySettings { [weak self] in self?.togglePopover() }
        lunchNudge = LunchNudge(anchor: { [weak self] in self?.statusItem.button?.window?.frame }) { [weak self] in
            self?.showPopover()
        }

        let host = NSHostingController(rootView: PopoverView(store: store, hotKeys: hotKeys))
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [store] _ in
            Task { @MainActor in await store.refreshIfStale() }
        }
        Task { await store.refreshIfStale() }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "kantinebar" {
            if url.host == "lunch" {
                lunchNudge.show()
                continue
            }
            let day = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "day" }?.value
            if let day { store.select(day) }
            showPopover()
        }
    }

    func popoverDidShow(_ notification: Notification) {
        // .transient only closes on outside clicks while we are the active app, which a hotkey open does not guarantee
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.popover.performClose(nil) }
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let keyCode = Int(event.keyCode)
            let hasModifiers = !event.modifierFlags.isDisjoint(with: [.command, .control, .option])
            let characters = event.charactersIgnoringModifiers
            let handled = MainActor.assumeIsolated {
                self?.handleKey(keyCode: keyCode, hasModifiers: hasModifiers, characters: characters) ?? false
            }
            return handled ? nil : event
        }
    }

    func popoverDidClose(_ notification: Notification) {
        for monitor in [outsideClickMonitor, keyMonitor].compactMap({ $0 }) {
            NSEvent.removeMonitor(monitor)
        }
        outsideClickMonitor = nil
        keyMonitor = nil
        hotKeys.cancelRecording()
    }

    private func handleKey(keyCode: Int, hasModifiers: Bool, characters: String?) -> Bool {
        guard !hotKeys.isRecording, !hasModifiers else { return false }
        switch keyCode {
        case kVK_LeftArrow:
            withAnimation(.snappy) { store.selectAdjacentDay(-1) }
        case kVK_RightArrow:
            withAnimation(.snappy) { store.selectAdjacentDay(1) }
        case kVK_Delete:
            guard store.openDish != nil else { return false }
            withAnimation(.snappy) { store.closeDish() }
        default:
            guard let number = characters.flatMap(Int.init), (1...9).contains(number) else { return false }
            withAnimation(.snappy) { store.openDish(at: number - 1) }
        }
        return true
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        Task { await store.refreshIfStale() }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
        NSApp.activate()
        let window = popover.contentViewController?.view.window
        window?.makeKey()
        window?.makeFirstResponder(nil)
    }
}
