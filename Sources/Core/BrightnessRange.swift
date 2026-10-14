import Foundation

struct XDRMaximum {
    static let defaultGain = 1.5
    static let upperBound = 16.0
    static let preferenceKey = "xdrMaximumGain"
    static func sanitized(_ value: Double?) -> Double {
        guard let value, value.isFinite, value >= 1 else { return defaultGain }
        return min(upperBound, value)
    }
    static func output(requested: Double, maximum: Double, headroom: Double) -> Float {
        guard requested.isFinite, maximum.isFinite, headroom.isFinite else { return 1 }
        return Float(max(1, min(requested, sanitized(maximum), max(1, headroom))))
    }
}

/// 0...1 is normal hardware brightness; above 1 is requested relative gain.
/// The saved maximum bounds the control itself, not just the rendered output.
struct BrightnessRange {
    private(set) var extended: Double = 0
    private(set) var maximum: Double
    init(maximum: Double = XDRMaximum.defaultGain) { self.maximum = XDRMaximum.sanitized(maximum) }

    func position(hardware: Double) -> Double {
        extended > 0 ? 1 + extended : Self.clamp(hardware, upper: 1)
    }
    mutating func step(up: Bool, fine: Bool = false, hardware: Double) -> Double {
        let increment = fine ? 1.0 / 64 : 1.0 / 16
        return select(position(hardware: hardware) + (up ? increment : -increment))
    }
    @discardableResult mutating func select(_ position: Double) -> Double {
        let value = Self.clamp(position, upper: maximum)
        extended = max(0, value - 1)
        return value
    }
    mutating func setMaximum(_ value: Double) {
        maximum = XDRMaximum.sanitized(value)
        // Lowering the cap immediately lowers the request. Raising it never
        // changes brightness or restores a previously clamped request.
        extended = min(extended, maximum - 1)
    }
    mutating func reset() { extended = 0 }
    private static func clamp(_ value: Double, upper: Double) -> Double {
        value.isFinite ? min(upper, max(0, value)) : 0
    }
}

enum BrightnessDirection { case up, down }

struct BrightnessKeyEvent {
    let direction: BrightnessDirection
    let isDown: Bool
    let isRepeat: Bool
    let code: Int
    init?(type: UInt32, subtype: Int, data1: Int) {
        guard type == 14, subtype == 8 else { return nil }
        let code = (data1 >> 16) & 0xffff
        let state = (data1 >> 8) & 0xff
        guard (code == 2 || code == 3), (state == 0x0a || state == 0x0b) else { return nil }
        self.code = code; direction = code == 2 ? .up : .down
        isDown = state == 0x0a; isRepeat = (data1 & 1) != 0
    }
}

/// In-memory counts for brightness-key diagnosis only. No key text or event log.
struct BrightnessKeyDiagnostics {
    var systemEvents = 0
    var up = 0
    var down = 0
    var repeats = 0
    var releases = 0
    var swallowed = 0
    var forwardedBrightness = 0
    var delivered = 0
    var cancelled = 0
    var tapFailures = 0
    var last = "none"
}

/// Owns down/up pairs and invalidates commands queued before reset/suspension.
struct BrightnessKeyRouting {
    private(set) var generation = 0
    private(set) var accepting = false
    private var consumed = Set<Int>()
    enum Decision: Equatable { case forward, swallow, command(Int) }
    mutating func start() { generation += 1; accepting = true; consumed.removeAll() }
    mutating func stop() { generation += 1; accepting = false; consumed.removeAll() }
    func current(_ token: Int) -> Bool { accepting && generation == token }
    mutating func route(_ key: BrightnessKeyEvent) -> Decision {
        guard accepting else { return .forward }
        if !key.isDown { return consumed.remove(key.code) != nil ? .swallow : .forward }
        consumed.insert(key.code)
        return .command(generation)
    }
}

struct BrightnessSuspension {
    enum Reason: Hashable { case sleep, displaySleep, sessionInactive, locked }
    private var reasons = Set<Reason>()
    var isSuspended: Bool { !reasons.isEmpty }
    mutating func set(_ reason: Reason, active: Bool) {
        if active { reasons.insert(reason) } else { reasons.remove(reason) }
    }
}
