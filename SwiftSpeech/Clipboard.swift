import AppKit
import CoreGraphics

enum Clipboard {
    /// Writes `text` to the clipboard, simulates Cmd+V, then restores the previous clipboard contents.
    static func paste(_ text: String) {
        let pasteboard = NSPasteboard.general
        let previous = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        simulateCmdV()

        // Restore after a short delay to let the paste complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            pasteboard.clearContents()
            if let previous {
                pasteboard.setString(previous, forType: .string)
            }
        }
    }

    private static func simulateCmdV() {
        let source = CGEventSource(stateID: .hidSystemState)
        let vKey: CGKeyCode = 0x09

        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        down?.flags = .maskCommand

        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        up?.flags = .maskCommand

        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
