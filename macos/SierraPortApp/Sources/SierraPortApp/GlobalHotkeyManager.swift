import Foundation
import AppKit
import Carbon

// MARK: - Persisted Hotkey Model

struct HotkeyConfig: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32

    static let optionSpace = HotkeyConfig(keyCode: 49, carbonModifiers: UInt32(optionKey))
    static let controlSpace = HotkeyConfig(keyCode: 49, carbonModifiers: UInt32(controlKey))
    static let cmdShiftP = HotkeyConfig(keyCode: 35, carbonModifiers: UInt32(cmdKey | shiftKey))
    static let optionP = HotkeyConfig(keyCode: 35, carbonModifiers: UInt32(optionKey))

    static let presets: [(label: String, config: HotkeyConfig)] = [
        ("⌥ Space", .optionSpace),
        ("⌃ Space", .controlSpace),
        ("⌘ ⇧ P", .cmdShiftP),
        ("⌥ P", .optionP)
    ]

    var modifierSymbols: [String] {
        var out: [String] = []
        if (carbonModifiers & UInt32(controlKey)) != 0 { out.append("⌃") }
        if (carbonModifiers & UInt32(optionKey)) != 0 { out.append("⌥") }
        if (carbonModifiers & UInt32(shiftKey)) != 0 { out.append("⇧") }
        if (carbonModifiers & UInt32(cmdKey)) != 0 { out.append("⌘") }
        return out
    }

    var keySymbol: String {
        Self.keyCodeToDisplay(keyCode)
    }

    var keycaps: [String] {
        modifierSymbols + [keySymbol]
    }

    var displayString: String {
        keycaps.joined(separator: " ")
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }
        return mods
    }

    static func keyCodeToDisplay(_ code: UInt32) -> String {
        switch code {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 36: return "⏎"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return "Tab"
        case 49: return "Space"
        case 50: return "`"
        default: return "Key\(code)"
        }
    }
}

// MARK: - System-Wide macOS Global Hotkey Manager (Carbon RegisterEventHotKey)

@MainActor
final class GlobalHotkeyManager: ObservableObject {
    static let shared = GlobalHotkeyManager()

    private let storageKey = "sierraport_global_hotkey_v1"

    @Published var currentHotkey: HotkeyConfig? = nil
    @Published var isRegistered: Bool = false

    private var hotKeyRef: EventHotKeyRef? = nil
    private var eventHandlerRef: EventHandlerRef? = nil
    var onTrigger: (() -> Void)? = nil

    private init() {
        installCarbonHandler()
        if let saved = loadSavedHotkey() {
            register(hotkey: saved, persist: false)
        }
    }

    func loadSavedHotkey() -> HotkeyConfig? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let cfg = try? JSONDecoder().decode(HotkeyConfig.self, from: data) else {
            return nil
        }
        return cfg
    }

    func register(hotkey: HotkeyConfig, persist: Bool = true) {
        unregister()

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x5350484B) // 'SPHK'
        hotKeyID.id = 1

        var ref: EventHotKeyRef? = nil
        let status = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        if status == noErr, let ref {
            self.hotKeyRef = ref
            self.currentHotkey = hotkey
            self.isRegistered = true
            if persist, let data = try? JSONEncoder().encode(hotkey) {
                UserDefaults.standard.set(data, forKey: storageKey)
            }
        } else {
            self.isRegistered = false
        }
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        isRegistered = false
    }

    private func installCarbonHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { _, _, _ -> OSStatus in
            Task { @MainActor in
                GlobalHotkeyManager.shared.onTrigger?()
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
    }
}
