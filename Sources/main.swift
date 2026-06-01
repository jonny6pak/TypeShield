import Foundation
import CoreGraphics

// MARK: - CLI options
struct Options {
    var blockMs: Double = 300
    var graceMs: Double = 30
    var allowScroll: Bool = false
    var freezeCursor: Bool = false
    var lockCursor: Bool = false
    var verbose: Bool = false
}

func parseOptions() -> Options {
    var o = Options()
    var it = CommandLine.arguments.dropFirst().makeIterator()
    while let a = it.next() {
        switch a {
        case "--block-ms":
            if let v = it.next(), let d = Double(v) { o.blockMs = d }
        case "--grace-ms":
            if let v = it.next(), let d = Double(v) { o.graceMs = d }
        case "--allow-scroll":
            o.allowScroll = true
        case "--freeze-cursor":
            o.freezeCursor = true
        case "--lock-cursor":
            o.lockCursor = true
        case "--verbose", "-v":
            o.verbose = true
        case "--help", "-h":
            print("""
            TypeShield — block mouse/trackpad for a short window after typing

            Usage:
              typeshield [--block-ms N] [--grace-ms N] [--allow-scroll] [--freeze-cursor] [--lock-cursor] [--verbose]

            Options:
              --block-ms N       total block window after key press (default \(Int(o.blockMs)) ms)
              --grace-ms N       strict grace window right after key press (default \(Int(o.graceMs)) ms)
              --allow-scroll     allow scroll events during block window (default: block scroll)
              --freeze-cursor    temporarily disassociate mouse movement from cursor position during suppression
              --lock-cursor      actively pin the cursor to its pre-typing position during suppression
              --verbose, -v      log basic events
              --help, -h         show this help
            """)
            exit(0)
        case "--version":
            print("TypeShield 1.0.5")
            exit(0)
        default:
            break
        }
    }
    return o
}

let opts = parseOptions()
if opts.verbose {
    fputs("TypeShield starting (block=\(Int(opts.blockMs))ms, grace=\(Int(opts.graceMs))ms, allowScroll=\(opts.allowScroll), freezeCursor=\(opts.freezeCursor), lockCursor=\(opts.lockCursor))\n", stderr)
    fputs("Grant Input Monitoring: System Settings → Privacy & Security → Input Monitoring\n", stderr)
}

// MARK: - Timing state
final class State {
    private let q = DispatchQueue(label: "typeshield.state")
    private var _lastKey: CFAbsoluteTime = CFAbsoluteTimeGetCurrent() - 100
    private var _cursorFrozen: Bool = false
    private var _cursorLocked: Bool = false
    private var _lockedCursorPosition: CGPoint?

    func markKeyNow() {
        let now = CFAbsoluteTimeGetCurrent()
        q.sync { self._lastKey = now }
    }

    func shouldBlockPointer(now: CFAbsoluteTime, blockMs: Double, graceMs: Double) -> Bool {
        var last: CFAbsoluteTime = 0
        q.sync { last = _lastKey }
        let dt = now - last
        if dt < 0 { return false }
        if dt <= graceMs / 1000.0 { return true }
        return dt < blockMs / 1000.0
    }

    func currentBlockExpiresAt(blockMs: Double) -> CFAbsoluteTime {
        var last: CFAbsoluteTime = 0
        q.sync { last = _lastKey }
        return last + (blockMs / 1000.0)
    }

    func isCursorFrozen() -> Bool {
        var frozen = false
        q.sync { frozen = _cursorFrozen }
        return frozen
    }

    func setCursorFrozen(_ frozen: Bool) {
        q.sync { _cursorFrozen = frozen }
    }

    func isCursorLocked() -> Bool {
        var locked = false
        q.sync { locked = _cursorLocked }
        return locked
    }

    func lockedCursorPosition() -> CGPoint? {
        var p: CGPoint?
        q.sync { p = _lockedCursorPosition }
        return p
    }

    func lockCursor(at point: CGPoint) {
        q.sync {
            if !_cursorLocked {
                _lockedCursorPosition = point
                _cursorLocked = true
            }
        }
    }

    func unlockCursor() {
        q.sync {
            _lockedCursorPosition = nil
            _cursorLocked = false
        }
    }
}

let state = State()

// MARK: - Cursor helpers
func currentCursorPosition() -> CGPoint? {
    return CGEvent(source: nil)?.location
}

func freezeCursorIfNeeded() {
    guard opts.freezeCursor else { return }
    if !state.isCursorFrozen() {
        CGAssociateMouseAndMouseCursorPosition(boolean_t(0))
        state.setCursorFrozen(true)
        if opts.verbose { fputs("[cursor] frozen\n", stderr) }
    }
}

func unfreezeCursorIfNeeded() {
    guard opts.freezeCursor else { return }
    if state.isCursorFrozen() {
        CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
        state.setCursorFrozen(false)
        if opts.verbose { fputs("[cursor] unfrozen\n", stderr) }
    }
}

func lockCursorIfNeeded() {
    guard opts.lockCursor else { return }
    if !state.isCursorLocked(), let p = currentCursorPosition() {
        state.lockCursor(at: p)
        CGWarpMouseCursorPosition(p)
        if opts.verbose {
            fputs(String(format: "[cursor] locked %.1f,%.1f\n", p.x, p.y), stderr)
        }
    }
}

func unlockCursorIfNeeded() {
    guard opts.lockCursor else { return }
    if state.isCursorLocked() {
        state.unlockCursor()
        if opts.verbose { fputs("[cursor] unlocked\n", stderr) }
    }
}

func pinCursorIfNeeded() {
    guard opts.lockCursor else { return }
    if let p = state.lockedCursorPosition() {
        CGWarpMouseCursorPosition(p)
    }
}

func beginSuppressionCursorControls() {
    freezeCursorIfNeeded()
    lockCursorIfNeeded()
    pinCursorIfNeeded()
}

func endSuppressionCursorControls() {
    unfreezeCursorIfNeeded()
    unlockCursorIfNeeded()
}

// MARK: - Event masks
let keyboardMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

var pointerMask: CGEventMask = 0
let pointerTypes: [CGEventType] = [
    .leftMouseDown, .leftMouseUp,
    .rightMouseDown, .rightMouseUp,
    .otherMouseDown, .otherMouseUp,
    .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged
]
for t in pointerTypes { pointerMask |= (1 << t.rawValue) }
if !opts.allowScroll { pointerMask |= (1 << CGEventType.scrollWheel.rawValue) }

// MARK: - Global tap refs so callbacks/watchdog can re-enable taps
var kbTapRef: CFMachPort?
var ptTapRef: CFMachPort?

// MARK: - Event callbacks
let kbCallback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let kb = kbTapRef {
            CGEvent.tapEnable(tap: kb, enable: true)
            if opts.verbose { fputs("[kb] re-enabled tap\n", stderr) }
        }
        return Unmanaged.passUnretained(event)
    }

    if type == .keyDown {
        state.markKeyNow()
        beginSuppressionCursorControls()
        if opts.verbose {
            let k = event.getIntegerValueField(.keyboardEventKeycode)
            fputs("[key] \(k)\n", stderr)
        }
    }

    return Unmanaged.passUnretained(event)
}

let ptCallback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let pt = ptTapRef {
            CGEvent.tapEnable(tap: pt, enable: true)
            if opts.verbose { fputs("[ptr] re-enabled tap\n", stderr) }
        }
        return Unmanaged.passUnretained(event)
    }

    let now = CFAbsoluteTimeGetCurrent()
    if state.shouldBlockPointer(now: now, blockMs: opts.blockMs, graceMs: opts.graceMs) {
        beginSuppressionCursorControls()
        pinCursorIfNeeded()
        if opts.verbose { fputs("[block] \(type.rawValue)\n", stderr) }
        return nil
    }

    if opts.verbose, type == .scrollWheel {
        fputs("[pass] scroll\n", stderr)
    }
    return Unmanaged.passUnretained(event)
}

// MARK: - Create taps
// Both taps use HID level to avoid a race where pointer HID events arrive before
// keyboard session events update the timestamp.
guard let kbTap = CGEvent.tapCreate(tap: .cghidEventTap,
                                    place: .headInsertEventTap,
                                    options: .defaultTap,
                                    eventsOfInterest: keyboardMask,
                                    callback: kbCallback,
                                    userInfo: nil) else {
    fputs("TypeShield: failed to create keyboard tap. Grant Input Monitoring in System Settings → Privacy & Security.\n", stderr)
    exit(1)
}
kbTapRef = kbTap

guard let ptTap = CGEvent.tapCreate(tap: .cghidEventTap,
                                    place: .headInsertEventTap,
                                    options: .defaultTap,
                                    eventsOfInterest: pointerMask,
                                    callback: ptCallback,
                                    userInfo: nil) else {
    fputs("TypeShield: failed to create pointer tap. Grant Input Monitoring in System Settings → Privacy & Security.\n", stderr)
    exit(1)
}
ptTapRef = ptTap

let kbSrc = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, kbTap, 0)
let ptSrc = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, ptTap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), kbSrc, .commonModes)
CFRunLoopAddSource(CFRunLoopGetCurrent(), ptSrc, .commonModes)
CGEvent.tapEnable(tap: kbTap, enable: true)
CGEvent.tapEnable(tap: ptTap, enable: true)

// MARK: - Cursor control release/pin timer
// Runs frequently while locked/frozen. It pins the cursor during suppression
// and releases both freeze/lock after the block window expires.
let cursorTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInteractive))
cursorTimer.schedule(deadline: .now() + 0.01, repeating: 0.01)
cursorTimer.setEventHandler {
    if opts.freezeCursor || opts.lockCursor {
        let now = CFAbsoluteTimeGetCurrent()
        let expires = state.currentBlockExpiresAt(blockMs: opts.blockMs)
        if now < expires {
            pinCursorIfNeeded()
        } else {
            endSuppressionCursorControls()
        }
    }
}
cursorTimer.resume()

// MARK: - Watchdog
// Only re-enable taps if macOS has disabled them.
let watchdog = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
watchdog.schedule(deadline: .now() + 3, repeating: 3)
watchdog.setEventHandler {
    if let kb = kbTapRef, !CGEvent.tapIsEnabled(tap: kb) {
        CGEvent.tapEnable(tap: kb, enable: true)
    }
    if let pt = ptTapRef, !CGEvent.tapIsEnabled(tap: pt) {
        CGEvent.tapEnable(tap: pt, enable: true)
    }
}
watchdog.resume()

// MARK: - Shutdown
func cleanExit(_ code: Int32) -> Never {
    endSuppressionCursorControls()
    if let kb = kbTapRef {
        CGEvent.tapEnable(tap: kb, enable: false)
        CFMachPortInvalidate(kb)
    }
    if let pt = ptTapRef {
        CGEvent.tapEnable(tap: pt, enable: false)
        CFMachPortInvalidate(pt)
    }
    exit(code)
}

signal(SIGINT) { _ in
    fputs("\nTypeShield: exiting…\n", stderr)
    cleanExit(0)
}
signal(SIGTERM) { _ in cleanExit(0) }

CFRunLoopRun()
