import AppKit
import Carbon
import Observation

struct Shortcut: Codable, Equatable {
    let keyCode: Int
    let modifiers: Int
    let display: String

    static let standard = Shortcut(keyCode: kVK_ANSI_K, modifiers: shiftKey | cmdKey, display: "⇧⌘K")
}

/// Owns the open-popup hotkey: persistence, recording a new one, and keeping it registered.
@MainActor
@Observable
final class HotKeySettings {
    private(set) var shortcut: Shortcut?
    private(set) var isRecording = false
    private(set) var recordingHint: String?

    @ObservationIgnored private var hotKey: GlobalHotKey?
    @ObservationIgnored private var monitor: Any?
    @ObservationIgnored private let onPress: () -> Void
    @ObservationIgnored private let defaults = UserDefaults.standard
    private static let storageKey = "openShortcut"
    private static let disabledKey = "openShortcutDisabled"

    init(onPress: @escaping () -> Void) {
        self.onPress = onPress
        if !defaults.bool(forKey: Self.disabledKey) {
            let saved = defaults.data(forKey: Self.storageKey).flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) }
            shortcut = saved ?? .standard
        }
        if let shortcut, !register(shortcut) {
            self.shortcut = nil
        }
    }

    func startRecording() {
        hotKey?.unregister()
        hotKey = nil
        recordingHint = nil
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let keyCode = Int(event.keyCode)
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let key = Self.keyName(keyCode: keyCode, characters: event.characters(byApplyingModifiers: []))
            MainActor.assumeIsolated { self?.record(keyCode: keyCode, flags: flags, key: key) }
            return nil
        }
    }

    func cancelRecording() {
        guard isRecording else { return }
        stopRecording()
        if let shortcut, !register(shortcut) {
            self.shortcut = nil
        }
    }

    func clear() {
        hotKey?.unregister()
        hotKey = nil
        shortcut = nil
        defaults.set(true, forKey: Self.disabledKey)
    }

    private func record(keyCode: Int, flags: NSEvent.ModifierFlags, key: String) {
        if keyCode == kVK_Escape {
            cancelRecording()
            return
        }
        guard !flags.isDisjoint(with: [.command, .control, .option]) else {
            recordingHint = "Bruk ⌘, ⌃ eller ⌥"
            return
        }
        let candidate = Shortcut(keyCode: keyCode, modifiers: Self.carbonModifiers(flags), display: Self.symbols(flags) + key)
        guard register(candidate) else {
            recordingHint = "\(candidate.display) er opptatt"
            return
        }
        stopRecording()
        shortcut = candidate
        defaults.set(try? JSONEncoder().encode(candidate), forKey: Self.storageKey)
        defaults.set(false, forKey: Self.disabledKey)
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
        recordingHint = nil
    }

    private func register(_ shortcut: Shortcut) -> Bool {
        hotKey?.unregister()
        hotKey = GlobalHotKey.register(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers, action: onPress)
        return hotKey != nil
    }

    private static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> Int {
        var modifiers = 0
        if flags.contains(.command) { modifiers |= cmdKey }
        if flags.contains(.shift) { modifiers |= shiftKey }
        if flags.contains(.option) { modifiers |= optionKey }
        if flags.contains(.control) { modifiers |= controlKey }
        return modifiers
    }

    private static func symbols(_ flags: NSEvent.ModifierFlags) -> String {
        [(NSEvent.ModifierFlags.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
            .filter { flags.contains($0.0) }
            .map(\.1)
            .joined()
    }

    private nonisolated static let specialKeys: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    private nonisolated static func keyName(keyCode: Int, characters: String?) -> String {
        specialKeys[keyCode] ?? (characters ?? "?").uppercased()
    }
}
