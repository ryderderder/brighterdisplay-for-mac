import Foundation

struct Gamma: Equatable {
    let red: [Float]
    let green: [Float]
    let blue: [Float]
    var valid: Bool {
        red.count >= 2 && red.count == green.count && red.count == blue.count &&
        (red + green + blue).allSatisfy { $0.isFinite && $0 >= 0 }
    }
    func scaled(_ gain: Float) -> Gamma {
        Gamma(red: red.map { $0 * gain }, green: green.map { $0 * gain }, blue: blue.map { $0 * gain })
    }
    var clippedToSDR: Gamma {
        Gamma(red: red.map { min(1, $0) }, green: green.map { min(1, $0) }, blue: blue.map { min(1, $0) })
    }
    // A plateau below the last sample may be a previous clipped boost. Refuse
    // to adopt it; do not erase another app's table to manufacture a baseline.
    var hasClippedPlateau: Bool {
        [red, green, blue].contains { channel in
            channel.count > 8 && channel[channel.count - 8] >= 0.9999
        }
    }
    func matches(_ other: Gamma, tolerance: Float = 0.002) -> Bool {
        red.count == other.red.count && green.count == other.green.count && blue.count == other.blue.count &&
        zip(red + green + blue, other.red + other.green + other.blue).allSatisfy { abs($0 - $1) <= tolerance }
    }
}

protocol GammaDevice {
    func read() throws -> Gamma
    func write(_ value: Gamma) throws
}
enum LiftError: Error, CustomStringConvertible {
    case unavailable(String)
    var description: String { if case .unavailable(let s) = self { return s }; return "Unavailable" }
}

/// Owns exactly one display. Every update derives from an immutable baseline.
final class GammaSession {
    let device: GammaDevice
    let baseline: Gamma
    private(set) var last: Gamma
    private(set) var active = true
    private(set) var readbackIsClipped = false
    init(device: GammaDevice) throws {
        self.device = device
        let value = try device.read()
        guard value.valid, !value.hasClippedPlateau, (value.red + value.green + value.blue).allSatisfy({ $0 <= 1.002 }) else { throw LiftError.unavailable("Invalid or already boosted color table; disable other gamma utilities") }
        baseline = value; last = value
    }
    func apply(gain: Float) throws {
        guard active, gain.isFinite, gain >= 1, gain <= 64 else { throw LiftError.unavailable("Invalid gain or inactive session") }
        guard try device.read().matches(last) else {
            active = false
            throw LiftError.unavailable("Another display utility changed the color table; boost stopped")
        }
        let target = baseline.scaled(gain)
        do {
            try device.write(target)
            let actual = try device.read()
            let exact = actual.matches(target)
            let clipped = actual.matches(target.clippedToSDR)
            guard exact || clipped else { throw LiftError.unavailable("Display color-table read-back differs from both supported representations") }
            // Read-back verifies the transaction, not optical output. macOS can
            // return a clipped representation, observed on this test machine.
            readbackIsClipped = !exact && clipped
            last = actual
        } catch {
            // A failed/clamped write can leave a partial table. Roll back this transaction.
            do {
                try device.write(baseline)
                guard try device.read().matches(baseline) else { throw LiftError.unavailable("Rollback read-back failed") }
                active = false
            } catch let rollbackError {
                last = (try? device.read()) ?? target
                throw LiftError.unavailable("Boost failed and rollback needs retry: \(rollbackError)")
            }
            throw error
        }
    }
    func restore() throws {
        guard active else { return }
        // Retain ownership after a transient read/write error so Reset can retry.
        // Never overwrite a table another utility has installed.
        guard try device.read().matches(last) else { active = false; return }
        try device.write(baseline)
        guard try device.read().matches(baseline) else { throw LiftError.unavailable("Color-table restoration could not be verified") }
        active = false
    }
}

func boundedGain(level: Double, headroom: Double) -> Float {
    guard level.isFinite, headroom.isFinite else { return 1 }
    return Float(1 + min(1, max(0, level)) * (min(64, max(1, headroom)) - 1))
}
