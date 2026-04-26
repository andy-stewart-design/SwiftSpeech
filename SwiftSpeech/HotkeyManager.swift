import CoreGraphics
import Foundation

@MainActor
@Observable
class HotkeyManager {
    var isRecording  = false
    var isCapturing  = false  // true while the user is pressing a new hotkey

    var onKeyDown: (() -> Void)?
    var onKeyUp:   (() -> Void)?

    // Persisted hotkey — defaults to Cmd + Right Option
    var keyCode: Int64 = Int64(UserDefaults.standard.integer(forKey: "hotkey.keyCode").nonZero ?? 61) {
        didSet { UserDefaults.standard.set(Int(keyCode), forKey: "hotkey.keyCode") }
    }
    var requiredFlags: CGEventFlags = {
        if let raw = UserDefaults.standard.object(forKey: "hotkey.flags") as? UInt64 {
            return CGEventFlags(rawValue: raw)
        }
        return [.maskAlternate, .maskCommand]
    }() {
        didSet { UserDefaults.standard.set(requiredFlags.rawValue, forKey: "hotkey.flags") }
    }

    // Human-readable string e.g. "⌘Right ⌥"
    var displayString: String {
        let ownFlag = ownModifierFlag(for: keyCode) ?? []
        let extra   = requiredFlags.subtracting(ownFlag)
        var parts: [String] = []
        if extra.contains(.maskControl)   { parts.append("⌃") }
        if extra.contains(.maskCommand)   { parts.append("⌘") }
        if extra.contains(.maskAlternate) { parts.append("⌥") }
        if extra.contains(.maskShift)     { parts.append("⇧") }
        parts.append(keyName(for: keyCode))
        return parts.joined()
    }

    private var eventTap:       CFMachPort?
    private var runLoopSource:  CFRunLoopSource?
    private var pendingKeyCode: Int64 = 0
    private var pendingFlags:   CGEventFlags = []

    func start() {
        print("HotkeyManager.start() called")
        guard eventTap == nil else { print("already running"); return }

        let mask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo -> Unmanaged<CGEvent>? in
                guard let ptr = userInfo else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(ptr).takeUnretainedValue()
                return MainActor.assumeIsolated { manager.handle(type: type, event: event) }
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap = eventTap else {
            print("CGEvent.tapCreate failed — Accessibility permission missing?")
            return
        }
        print("event tap created successfully")

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
        eventTap      = nil
        runLoopSource = nil
    }

    func startCapturing() {
        pendingKeyCode = 0
        pendingFlags   = []
        isCapturing    = true
    }

    // MARK: - Private

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .flagsChanged else { return Unmanaged.passUnretained(event) }

        let eventKeyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let relevantMask: CGEventFlags = [.maskAlternate, .maskCommand, .maskShift, .maskControl]
        let activeFlags  = event.flags.intersection(relevantMask)

        // Capture mode: accumulate keys as they're pressed, commit when all released
        if isCapturing {
            if activeFlags.isSuperset(of: pendingFlags) {
                // More keys added — update the pending combo
                pendingKeyCode = eventKeyCode
                pendingFlags   = activeFlags
            } else if activeFlags.isEmpty, !pendingFlags.isEmpty {
                // All keys released — commit the full combination
                keyCode       = pendingKeyCode
                requiredFlags = pendingFlags
                pendingKeyCode = 0
                pendingFlags   = []
                isCapturing   = false
            }
            return nil
        }

        // Normal hotkey detection
        guard eventKeyCode == keyCode else { return Unmanaged.passUnretained(event) }

        if activeFlags == requiredFlags, !isRecording {
            isRecording = true
            onKeyDown?()
            return nil
        } else if isRecording, !activeFlags.isSuperset(of: requiredFlags) {
            isRecording = false
            onKeyUp?()
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    private func keyName(for code: Int64) -> String {
        switch code {
        case 54: return "Right ⌘"
        case 55: return "Left ⌘"
        case 56: return "Left ⇧"
        case 57: return "Caps Lock"
        case 58: return "Left ⌥"
        case 59: return "Left ⌃"
        case 60: return "Right ⇧"
        case 61: return "Right ⌥"
        case 62: return "Right ⌃"
        case 63: return "Fn"
        default: return "Key \(code)"
        }
    }

    private func ownModifierFlag(for code: Int64) -> CGEventFlags? {
        switch code {
        case 54, 55: return .maskCommand
        case 56, 60: return .maskShift
        case 58, 61: return .maskAlternate
        case 59, 62: return .maskControl
        default:     return nil
        }
    }
}

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
