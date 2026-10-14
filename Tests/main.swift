import Foundation

final class Fake: GammaDevice {
    var table = Gamma(red: [0, 0.5, 1], green: [0, 0.4, 1], blue: [0, 0.3, 1])
    var clamp = false
    var writes = 0
    func read() throws -> Gamma { table }
    func write(_ value: Gamma) throws { writes += 1; table = clamp ? Gamma(red: value.red.map { min(1, $0) }, green: value.green.map { min(1, $0) }, blue: value.blue.map { min(1, $0) }) : value }
}
var checks = 0
func expect(_ result: @autoclosure () -> Bool, _ name: String) { checks += 1; if !result() { fatalError("FAIL: \(name)") } }
let d = Fake(), baseline = d.table
let s = try GammaSession(device: d)
try s.apply(gain: 1.5); expect(d.table == baseline.scaled(1.5), "gain")
try s.apply(gain: 1.25); expect(d.table == baseline.scaled(1.25), "never compound")
try s.restore(); expect(d.table == baseline, "exact restore")
let count = d.writes; try s.restore(); expect(count == d.writes, "idempotent restore")
let other = Fake(); let conflict = try GammaSession(device: other)
try conflict.apply(gain: 1.4); other.table = baseline.scaled(0.8)
do { try conflict.apply(gain: 1.5); fatalError("Conflict accepted") } catch {}
try conflict.restore(); expect(other.table == baseline.scaled(0.8), "do not overwrite another utility")
let clamp = Fake(); clamp.clamp = true; let clampedSession = try GammaSession(device: clamp)
try clampedSession.apply(gain: 1.5)
expect(clampedSession.readbackIsClipped, "recognize observed clipped getter representation")
expect(clamp.table == baseline.scaled(1.5).clippedToSDR, "validate entire clipped table")
try clampedSession.restore()
expect(clamp.table == baseline, "restore clipped representation exactly")
expect(boundedGain(level: 1, headroom: 16) == 16, "use reported headroom")
expect(boundedGain(level: 1, headroom: 1) == 1, "no headroom")
expect(boundedGain(level: .nan, headroom: 2) == 1, "nonfinite input")
expect(boundedGain(level: -1, headroom: 2) == 1, "lower clamp")
expect(boundedGain(level: 0.5, headroom: 1.5) == 1.25, "relative interpolation")
print("PASS: \(checks) safety assertions")

let boosted = Fake(); boosted.table = baseline.scaled(1.1)
do { _ = try GammaSession(device: boosted); fatalError("Adopted boosted baseline") } catch {}
print("PASS: rejects already boosted baseline")

final class IgnoringDevice: GammaDevice {
    func read() throws -> Gamma { baseline }
    func write(_ value: Gamma) throws {}
}
let ignoring = try GammaSession(device: IgnoringDevice())
do { try ignoring.apply(gain: 1.3); fatalError("Ignored write accepted") } catch {}
expect(!ignoring.active, "ignored write fails closed")
let plateau = Gamma(red: [0,0.1,0.2,1,1,1,1,1,1,1,1,1], green: [0,0.1,0.2,1,1,1,1,1,1,1,1,1], blue: [0,0.1,0.2,1,1,1,1,1,1,1,1,1])
expect(plateau.hasClippedPlateau, "detect previously clipped boost")
print("PASS: complete safety suite \(checks) assertions plus boosted baseline rejection")

final class TransientRestoreDevice: GammaDevice {
    var table = baseline
    var failWrite = false
    func read() throws -> Gamma { table }
    func write(_ value: Gamma) throws {
        if failWrite { throw LiftError.unavailable("Injected temporary write failure") }
        table = value
    }
}
let retryDevice = TransientRestoreDevice()
let retrySession = try GammaSession(device: retryDevice)
try retrySession.apply(gain: 1.4)
retryDevice.failWrite = true
do { try retrySession.restore(); fatalError("Expected transient reset failure") } catch {}
expect(retrySession.active, "retain ownership for reset retry")
retryDevice.failWrite = false
try retrySession.restore()
expect(retryDevice.table == baseline && !retrySession.active, "retry restores original baseline")
print("PASS: final safety suite \(checks) assertions plus rejection scenarios")

// A single brightness coordinate, including rapid commands while EDR warms up.
var range = BrightnessRange(maximum: 2)
expect(range.position(hardware: 0.5) == 0.5, "launch adopts normal hardware level")
expect(range.step(up: true, hardware: 0.9375) == 1, "last normal step reaches boundary")
expect(range.extended == 0, "normal maximum has no gamma extension")
expect(range.step(up: true, hardware: 1) == 1.0625, "next up enters extended without toggle")
for _ in 0..<3 { _ = range.step(up: true, hardware: 1) }
expect(range.extended == 0.25, "repeats accumulate while renderer is pending")
for _ in 0..<4 { _ = range.step(up: false, hardware: 1) }
expect(range.extended == 0 && range.position(hardware: 1) == 1, "down traverses extended to normal")
expect(range.step(up: false, hardware: 1) == 0.9375, "next down lowers hardware")
range.select(1.03125)
expect(range.step(up: false, hardware: 1) == 0.96875, "step crossing boundary keeps remainder")
range.reset()
expect(range.step(up: true, fine: true, hardware: 1) == 1.015625, "fine brightness increment")
range.select(2)
expect(range.step(up: true, hardware: 1) == 2, "extended maximum clamps")
range.reset()
expect(range.step(up: false, hardware: 0) == 0, "normal minimum clamps")
range.select(1.5); range.reset()
expect(range.extended == 0 && range.step(up: true, hardware: 1) == 1.0625, "reset does not require enabling keys again")
range.reset()
expect(range.position(hardware: 0.375) == 0.375, "normal hardware changes are adopted")
range.select(.nan)
expect(range.extended == 0, "invalid range input fails normal")

let keyUp = BrightnessKeyEvent(type: 14, subtype: 8, data1: (2 << 16) | (0x0a << 8))
expect(keyUp?.direction == .up && keyUp?.isDown == true, "brightness up decoding")
let release = BrightnessKeyEvent(type: 14, subtype: 8, data1: (3 << 16) | (0x0b << 8))
expect(release?.direction == .down && release?.isDown == false, "brightness release decoding")
expect(BrightnessKeyEvent(type: 14, subtype: 8, data1: (0 << 16) | (0x0a << 8)) == nil, "volume event passes through")
expect(BrightnessKeyEvent(type: 10, subtype: 8, data1: (2 << 16) | (0x0a << 8)) == nil, "ordinary key event passes through")
expect(BrightnessKeyEvent(type: 14, subtype: 7, data1: (2 << 16) | (0x0a << 8)) == nil, "other system event passes through")
expect(BrightnessKeyEvent(type: 14, subtype: 8, data1: (2 << 16) | (0x0c << 8)) == nil, "unknown brightness state passes through")

var suspension = BrightnessSuspension()
expect(!suspension.isSuspended, "initial lifecycle is ready")
suspension.set(.locked, active: true); suspension.set(.sleep, active: true)
suspension.set(.sleep, active: false)
expect(suspension.isSuspended, "wake does not rearm while still locked")
suspension.set(.locked, active: false)
expect(!suspension.isSuspended, "unlock rearms when other reasons cleared")
suspension.set(.displaySleep, active: true); suspension.set(.sessionInactive, active: true)
suspension.set(.displaySleep, active: false)
expect(suspension.isSuspended, "screen wake waits for active session")
suspension.set(.sessionInactive, active: false)
expect(!suspension.isSuspended, "active session rearms")
print("PASS: \(checks) total assertions, including continuous range, filtering, and lifecycle gates")

// The saved ceiling bounds both the requested state and the actual gamma gain.
expect(XDRMaximum.sanitized(nil) == 1.5, "conservative default when no saved cap exists")
expect(XDRMaximum.sanitized(.nan) == 1.5, "corrupt saved cap is rejected")
expect(XDRMaximum.sanitized(0) == 1.5, "invalid saved cap is rejected")
expect(XDRMaximum.sanitized(1.25) == 1.25, "existing valid cap is preserved")
expect(XDRMaximum.sanitized(100) == 16, "cap sanity bound")
var capped = BrightnessRange(maximum: 1.5)
for _ in 0..<100 { _ = capped.step(up: true, hardware: 1) }
expect(capped.position(hardware: 1) == 1.5, "held up cannot accumulate above cap")
expect(capped.step(up: false, hardware: 1) == 1.4375, "down responds immediately after saturation")
capped.select(1.5); capped.setMaximum(1.25)
expect(capped.position(hardware: 1) == 1.25, "lowering cap immediately clamps active request")
capped.setMaximum(2)
expect(capped.position(hardware: 1) == 1.25, "raising cap never increases existing brightness")
capped.setMaximum(1)
expect(capped.extended == 0, "one-times cap removes extended request")
expect(capped.step(up: true, hardware: 1) == 1, "one-times cap stays in normal range")
expect(capped.step(up: false, hardware: 1) == 0.9375, "down works with one-times cap")
capped.setMaximum(1.1); capped.select(1.1)
expect(abs(capped.step(up: false, hardware: 1) - 1.0375) < 0.00001, "non-step-aligned cap decrements normally")
expect(abs(capped.step(up: false, hardware: 1) - 0.975) < 0.00001, "non-step-aligned cap crosses into hardware")
expect(XDRMaximum.output(requested: 3, maximum: 1.5, headroom: 4) == 1.5, "renderer independently enforces cap")
expect(XDRMaximum.output(requested: 1.5, maximum: 2, headroom: 1.25) == 1.25, "renderer respects reduced headroom")
expect(XDRMaximum.output(requested: 1.25, maximum: 2, headroom: 4) == 1.25, "more headroom does not amplify the requested gain")
expect(XDRMaximum.output(requested: .nan, maximum: 1.5, headroom: 4) == 1, "invalid rendering request returns normal")

let downPress = BrightnessKeyEvent(type: 14, subtype: 8, data1: (3 << 16) | (0x0a << 8))!
let downRelease = BrightnessKeyEvent(type: 14, subtype: 8, data1: (3 << 16) | (0x0b << 8))!
let repeatUp = BrightnessKeyEvent(type: 14, subtype: 8, data1: (2 << 16) | (0x0a << 8) | 1)!
expect(repeatUp.isDown && repeatUp.isRepeat, "autorepeat bit preserves brightness command")
var routing = BrightnessKeyRouting()
expect(routing.route(downPress) == .forward, "inactive service leaves native brightness alone")
routing.start()
let token = routing.generation
expect(routing.route(downRelease) == .forward, "never swallow an unowned release")
expect(routing.route(downPress) == .command(token), "brightness press dispatches exactly once")
expect(routing.route(downRelease) == .swallow, "swallow paired release")
expect(routing.route(downRelease) == .forward, "unpaired repeated release forwards")
expect(routing.route(repeatUp) == .command(token), "repeat dispatches through same capped controller")
expect(routing.current(token), "queued command valid while enabled")
routing.stop()
expect(!routing.current(token), "reset or timeout cancels already queued repeats")
routing.start()
expect(!routing.current(token), "rearmed tap never replays previous generation")
expect(routing.route(downPress) == .command(routing.generation), "new down commands work after rearm")
print("PASS: \(checks) total assertions including cap enforcement, repeats and event routing")
