import Foundation
import CoreGraphics

// MARK: - CLI options
struct Options {
    var blockMs: Double = 300      // total block window after a key press
    var graceMs: Double = 30       // immediate, stricter block window
    var allowScroll: Bool = false  // default blocks scroll; --allow-scroll to allow
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
        case "--verbose", "-v":
            o.verbose = true
        case "--help", "-h":
            print("""
            TypeShield — block mouse/trackpad for a short window after typing

            Usage:
              typeshield [--block-ms N] [--grace-ms N] [--allow-scroll] [--verbose]

            Options:
              --block-ms N     total block window after key press (default \(Int(o.blockMs)) ms)
              --grace-ms N     strict grace window right after key press (default \(Int(o.graceMs)) ms)
              --allow-scroll   allow scroll events during block window (default: block scroll)
              --verbose, -v    log basic events
              --help, -h       show this help
            """)
            exit(0)
        case "--version":
            print("TypeShield 1.0.0")
            exit(0)
        default:
            break
        }
    }
    return o
}

let opts = parseOptions()
if opts.verbose {
    fputs("TypeShield starting (block=\(Int(opts.blockMs))ms, grace=\(Int(opts.graceMs))ms, allowScroll=\(opts.allowScroll))\n", stderr)
    fputs("Grant Input Monitoring: System Settings → Privacy & Security → Input Monitoring\n", stderr)
}

// MARK: - Timing state
final class State {
    private let q = DispatchQueue(label: "typeshield.state")
    private var _lastKey: CFAbsoluteTime = CFAbsoluteTimeGetCurrent() - 100

    func markKeyNow() {
        q.async { self._lastKey = CFAbsoluteTimeGetCurrent() }
    }

    func shouldBlockPointer(now: CFAbsoluteTime, blockMs: Double, graceMs: Double) -> Bool {
        var last: CFAbsoluteTime = 0
        q.sync { last = _lastKey }
        let dt = now - last
        if dt < 0 { return false }
        if dt <= graceMs / 1000.0 { return true }
        return dt < blockMs / 1000.0
    }
}

let state = State()

// MARK: - Event masks
let keyboardMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
var pointerMask: CGEventMask = 0
let pointerTypes: [CGEventType] = [
    .leftMouseDown, .leftMouseUp,
    .rightMouseDown, .rightMouseUp,
    .otherMouseDown, .otherMouseUp,
    .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged
]
for t in pointerTypes { pointerMask |= (1 << t.rawValue) }
if !opts.allowScroll { pointerMask |= (1 << CGEventType.scrollWheel.rawValue) }

// MARK: - Taps
let kbCallback: CGEventTapCallBack = { _, type, event, _ in
    if type == .keyDown || type == .flagsChanged {
        state.markKeyNow()
        if opts.verbose {
            let k = event.getIntegerValueField(.keyboardEventKeycode)
            fputs("[key] \(k)\n", stderr)
        }
    }
    return Unmanaged.passRetained(event)
}

let ptCallback: CGEventTapCallBack = { _, type, event, _ in
    let now = CFAbsoluteTimeGetCurrent()
    if state.shouldBlockPointer(now: now, blockMs: opts.blockMs, graceMs: opts.graceMs) {
        if opts.verbose {
            fputs("[block] \(type.rawValue)\n", stderr)
        }
        return nil
    } else {
        if opts.verbose, type == .scrollWheel {
            fputs("[pass] scroll\n", stderr)
        }
        return Unmanaged.passRetained(event)
    }
}

guard let kbTap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                    place: .headInsertEventTap,
                                    options: .defaultTap,
                                    eventsOfInterest: keyboardMask,
                                    callback: kbCallback,
                                    userInfo: nil) else {
    fputs("TypeShield: failed to create keyboard tap. Grant Input Monitoring in System Settings → Privacy & Security.\n", stderr)
    exit(1)
}

guard let ptTap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                    place: .headInsertEventTap,
                                    options: .defaultTap,
                                    eventsOfInterest: pointerMask,
                                    callback: ptCallback,
                                    userInfo: nil) else {
    fputs("TypeShield: failed to create pointer tap. Grant Input Monitoring in System Settings → Privacy & Security.\n", stderr)
    exit(1)
}

let kbSrc = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, kbTap, 0)
let ptSrc = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, ptTap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), kbSrc, .commonModes)
CFRunLoopAddSource(CFRunLoopGetCurrent(), ptSrc, .commonModes)
CGEvent.tapEnable(tap: kbTap, enable: true)
CGEvent.tapEnable(tap: ptTap, enable: true)

signal(SIGINT) { _ in
    fputs("\nTypeShield: exiting…\n", stderr)
    CGEvent.tapEnable(tap: kbTap, enable: false)
    CGEvent.tapEnable(tap: ptTap, enable: false)
    CFMachPortInvalidate(kbTap)
    CFMachPortInvalidate(ptTap)
    exit(0)
}
signal(SIGTERM) { _ in raise(SIGINT) }

CFRunLoopRun()
