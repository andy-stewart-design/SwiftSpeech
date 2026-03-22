import CoreGraphics
import Foundation

@MainActor
@Observable
class HotkeyManager {
    var isRecording = false

    var onKeyDown: (() -> Void)?
    var onKeyUp: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private let targetKeyCode: Int64 = 61 // Right Option

    func start() {
        print("HotkeyManager.start() called")
        guard eventTap == nil else { print("already running"); return }

        let mask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue)

        // We pass `self` as a raw pointer via userInfo — the C callback
        // has no other way to reach back into Swift context.
        // The closure must be a literal and capture nothing; all context
        // flows through the userInfo pointer.
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,       // .defaultTap = suppressing tap
            eventsOfInterest: mask,
            callback: { proxy, type, event, userInfo -> Unmanaged<CGEvent>? in
                guard let ptr = userInfo else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(ptr).takeUnretainedValue()
                return MainActor.assumeIsolated {
                    manager.handle(type: type, event: event)
                }
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
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    // Called from the C callback — runs on main thread (main run loop).
    // MainActor.assumeIsolated tells the Swift compiler we know this.
    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .flagsChanged else { return Unmanaged.passUnretained(event) }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == targetKeyCode else {
            return Unmanaged.passUnretained(event) // not our key — pass through
        }

        // Require Right Option + Command held together to start recording
        let rightOptionHeld = event.flags.contains(.maskAlternate) && event.flags.contains(.maskCommand)

        if rightOptionHeld && !isRecording {
            isRecording = true
            onKeyDown?()
            return nil // suppress
        } else if !rightOptionHeld && isRecording {
            isRecording = false
            onKeyUp?()
            return nil // suppress
        }

        return Unmanaged.passUnretained(event)
    }
}

