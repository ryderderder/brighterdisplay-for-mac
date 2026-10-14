import AppKit
import ApplicationServices
import Darwin

/// Optional private API adapter. Failure always leaves the system keys alone.
final class BrightnessAdapter {
    typealias Get = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    typealias Set = @convention(c) (UInt32, Float) -> Int32
    private let handle: UnsafeMutableRawPointer
    private let getter: Get
    private let setter: Set
    init?() {
        guard let h = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY | RTLD_LOCAL) else { return nil }
        guard let g = dlsym(h, "DisplayServicesGetBrightness"), let s = dlsym(h, "DisplayServicesSetBrightness") else { dlclose(h); return nil }
        handle = h; getter = unsafeBitCast(g, to: Get.self); setter = unsafeBitCast(s, to: Set.self)
    }
    deinit { dlclose(handle) }
    func read(_ id: UInt32) -> Float? {
        var value: Float = 0
        return getter(id, &value) == 0 && value.isFinite && (0...1).contains(value) ? value : nil
    }
    func write(_ id: UInt32, _ value: Float) -> Bool {
        guard (0...1).contains(value), setter(id, value) == 0, let actual = read(id) else { return false }
        return abs(actual - value) < 0.02
    }
}
/// A narrow system-defined-event tap. The callback only filters and queues;
/// Metal, gamma and brightness writes happen on the main application thread.
final class BrightnessKeys {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var runLoop: CFRunLoop?
    private var thread: Thread?
    private let lock = NSLock()
    private var routing = BrightnessKeyRouting()
    private var counts = BrightnessKeyDiagnostics()
    var action: ((Bool, Bool) -> Void)?
    var failure: (() -> Void)?
    var isRunning: Bool { tap != nil }
    var isEnabled: Bool { tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }
    var diagnostics: BrightnessKeyDiagnostics { lock.lock(); defer { lock.unlock() }; return counts }

    func start() -> Bool {
        if isRunning { return isEnabled }
        guard AXIsProcessTrusted() else { return false }
        let callback: CGEventTapCallBack = { _, type, event, info in
            guard let info else { return Unmanaged.passUnretained(event) }
            let owner = Unmanaged<BrightnessKeys>.fromOpaque(info).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                owner.lock.lock()
                owner.routing.stop(); owner.counts.tapFailures += 1
                let token = owner.routing.generation
                owner.lock.unlock()
                DispatchQueue.main.async { [weak owner] in
                    guard let owner else { return }
                    owner.lock.lock(); let stillFailed = owner.routing.generation == token; owner.lock.unlock()
                    if stillFailed { owner.failure?() }
                }
                return Unmanaged.passUnretained(event)
            }
            guard type.rawValue == 14 else { return Unmanaged.passUnretained(event) }
            owner.lock.lock(); owner.counts.systemEvents += 1; owner.lock.unlock()
            guard let ns = NSEvent(cgEvent: event),
                  let key = BrightnessKeyEvent(type: type.rawValue, subtype: Int(ns.subtype.rawValue), data1: ns.data1) else {
                return Unmanaged.passUnretained(event)
            }
            owner.lock.lock()
            if key.isDown {
                if key.direction == .up { owner.counts.up += 1 } else { owner.counts.down += 1 }
                if key.isRepeat { owner.counts.repeats += 1 }
            } else { owner.counts.releases += 1 }
            owner.counts.last = "\(key.direction == .up ? "up" : "down") \(key.isDown ? (key.isRepeat ? "repeat" : "press") : "release")"
            let decision = owner.routing.route(key)
            if decision == .forward { owner.counts.forwardedBrightness += 1 } else { owner.counts.swallowed += 1 }
            owner.lock.unlock()
            switch decision {
            case .forward: return Unmanaged.passUnretained(event)
            case .swallow: return nil
            case .command(let token):
                let fine = ns.modifierFlags.contains([.option, .shift])
                DispatchQueue.main.async { [weak owner] in
                    guard let owner else { return }
                    owner.lock.lock()
                    let valid = owner.routing.current(token)
                    if valid { owner.counts.delivered += 1 } else { owner.counts.cancelled += 1 }
                    owner.lock.unlock()
                    if valid { owner.action?(key.direction == .up, fine) }
                }
                return nil
            }
        }
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: CGEventMask(1 << 14), callback: callback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque()),
              let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0) else { return false }
        tap = port; self.source = source
        lock.lock(); routing.start(); let token = routing.generation; lock.unlock()
        let ready = DispatchSemaphore(value: 0)
        let worker = Thread { [weak self] in
            guard let self else { ready.signal(); return }
            let loop = CFRunLoopGetCurrent()
            self.lock.lock()
            guard self.routing.current(token) else { self.lock.unlock(); ready.signal(); return }
            self.runLoop = loop; self.lock.unlock()
            CFRunLoopAddSource(loop, source, .commonModes); ready.signal()
            while self.current(token) { CFRunLoopRunInMode(.defaultMode, 0.25, false) }
            CFRunLoopRemoveSource(loop, source, .commonModes)
        }
        worker.name = "BrighterDisplay for Mac brightness keys"; worker.qualityOfService = .userInteractive
        thread = worker; worker.start()
        guard ready.wait(timeout: .now() + 2) == .success else { stop(); return false }
        CGEvent.tapEnable(tap: port, enable: true)
        guard isEnabled else { stop(); return false }
        return true
    }
    private func current(_ token: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }; return routing.current(token)
    }
    // Invalidate queued commands without disabling the service (Reset/cap edit).
    func discardPendingCommands() {
        // A new generation also needs a new worker, so stop and let the app rearm.
        stop()
    }
    func stop() {
        lock.lock(); routing.stop(); let loop = runLoop; runLoop = nil; lock.unlock()
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let loop { CFRunLoopStop(loop) }
        tap = nil; source = nil; thread = nil
    }
    deinit { stop() }
}
