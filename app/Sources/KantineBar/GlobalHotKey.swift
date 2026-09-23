import Carbon

/// A system-wide keyboard shortcut. Needs no Accessibility permission.
@MainActor
final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void

    /// Returns nil when the combination is already taken by another app.
    static func register(keyCode: Int, modifiers: Int, action: @escaping () -> Void) -> GlobalHotKey? {
        let hotKey = GlobalHotKey(action: action)
        return hotKey.register(keyCode: keyCode, modifiers: modifiers) ? hotKey : nil
    }

    private init(action: @escaping () -> Void) {
        self.action = action
    }

    private func register(keyCode: Int, modifiers: Int) -> Bool {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                MainActor.assumeIsolated { hotKey.action() }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(modifiers),
            EventHotKeyID(signature: OSType(0x4B42_4152), id: 1),
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr { unregister() }
        return status == noErr
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        hotKeyRef = nil
        handlerRef = nil
    }
}
