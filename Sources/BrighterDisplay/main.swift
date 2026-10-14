import AppKit
import ApplicationServices
import Darwin

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var status: NSStatusItem!
    let menu = NSMenu()
    let detail = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    let keysItem = NSMenuItem(title: "Set up brightness keys…", action: #selector(showSettings), keyEquivalent: "")
    let pauseItem = NSMenuItem(title: "Pause brightness keys", action: #selector(togglePause), keyEquivalent: "")
    let slider = NSSlider(value: 1, minValue: 0, maxValue: 2, target: nil, action: nil)
    let keys = BrightnessKeys()
    let brightness = BrightnessAdapter()
    var range = BrightnessRange()
    var suspension = BrightnessSuspension()
    var session: GammaSession?
    var surface: EDRSurface?
    var displayID: UInt32?
    var warmingUntil: Date?
    var recoveryNeeded = false
    var paused = false
    var backendError: String?
    var keyboardError: String?
    var message = "Normal brightness"
    var hardware: Double = 1
    var wasTrusted = AXIsProcessTrusted()
    var topology = ""
    var lastRender = Date.distantPast
    var timer: Timer?
    var observers: [NSObjectProtocol] = []
    var signals: [DispatchSourceSignal] = []
    var settingsWindow: NSWindow?
    var settingsStatus: NSTextField?
    var permissionStatus: NSTextField?
    var permissionButton: NSButton?
    var settingsSlider: NSSlider?
    var capField: NSTextField?
    var capStepper: NSStepper?
    var normalMarker: NSTextField?
    var endMarker: NSTextField?
    var diagnosticsLabel: NSTextField?
    var appliedKeys = 0
    var rejectedKeys = 0
    var lastRequestedGain: Float = 1
    var smokeMode: Bool { CommandLine.arguments.contains("--smoke-test") }
    var extendedActive: Bool { session != nil || range.extended > 0 }
    var thermallyLimited: Bool { [.serious, .critical].contains(ProcessInfo.processInfo.thermalState) }
    var target: NSScreen? { NSScreen.screens.first(where: { $0.eligible }) }
    func topologyKey() -> String { NSScreen.screens.map { "\($0.displayID):\($0.frame):\($0.backingScaleFactor):\($0.eligible)" }.sorted().joined(separator: "|") }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--permission-status") {
            print("accessibilityTrusted=\(AXIsProcessTrusted()) brightnessAdapter=\(brightness != nil)")
            Darwin.exit(0)
        }
        if let id = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: id).contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            print("BrighterDisplay for Mac already running; refusing a second display controller")
            Darwin.exit(0)
        }
        let savedCap = UserDefaults.standard.object(forKey: XDRMaximum.preferenceKey) as? Double
        range.setMaximum(XDRMaximum.sanitized(savedCap))
        NSApp.setActivationPolicy(.accessory)
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.toolTip = "BrighterDisplay for Mac — brightness keys, normal through extended"
        status.menu = menu; menu.delegate = self
        topology = topologyKey()
        if let state = CGSessionCopyCurrentDictionary() as? [String: Any], state["CGSSessionScreenIsLocked"] as? Bool == true {
            suspension.set(.locked, active: true)
        }
        buildMenu()
        observeLifecycle()
        keys.action = { [weak self] up, fine in
            guard let self else { return }
            if self.adjustBrightness(up: up, fine: fine) { self.appliedKeys += 1 } else { self.rejectedKeys += 1 }
            self.refresh()
        }
        keys.failure = { [weak self] in
            guard let self else { return }
            self.keys.stop()
            self.keyboardError = "Brightness-key interception stopped. Use Normal / Reset to retry."
            _ = self.restoreNormal("Normal — keyboard service stopped")
            self.refresh()
        }
        if let value = target.flatMap({ brightness?.read($0.displayID) }) { hardware = Double(value) }
        reconcileKeyboard()
        refresh()
        if smokeMode { runSmoke(); return }
        timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer!, forMode: .common)
        // Setup explains the one OS permission. It never turns on extended output.
        if !AXIsProcessTrusted() || CommandLine.arguments.contains("--show-controls") || CommandLine.arguments.contains("--show-settings") { showSettings() }
    }

    func buildMenu() {
        menu.addItem(NSMenuItem(title: "BrighterDisplay for Mac 0.3.1 — Preview", action: nil, keyEquivalent: ""))
        menu.addItem(detail)
        slider.target = self; slider.action = #selector(menuLevelChanged); slider.isContinuous = true
        slider.setAccessibilityLabel("Brightness — normal through extended")
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 60))
        let label = NSTextField(labelWithString: "Brightness         Normal → Extended")
        label.font = .systemFont(ofSize: 11); label.frame = NSRect(x: 16, y: 35, width: 250, height: 16)
        slider.frame = NSRect(x: 14, y: 6, width: 250, height: 25)
        view.addSubview(label); view.addSubview(slider)
        let item = NSMenuItem(); item.view = view; menu.addItem(item)
        menu.addItem(.separator())
        keysItem.target = self; menu.addItem(keysItem)
        pauseItem.target = self; menu.addItem(pauseItem)
        let reset = NSMenuItem(title: "Normal / Reset", action: #selector(reset), keyEquivalent: "0"); reset.target = self; menu.addItem(reset)
        menu.addItem(.separator())
        let about = NSMenuItem(title: "About & tradeoffs…", action: #selector(about), keyEquivalent: ""); about.target = self; menu.addItem(about)
        let quit = NSMenuItem(title: "Quit BrighterDisplay for Mac", action: #selector(quit), keyEquivalent: "q"); quit.target = self; menu.addItem(quit)
    }

    func observeLifecycle() {
        let nc = NSWorkspace.shared.notificationCenter
        let workspaceEvents: [(Notification.Name, BrightnessSuspension.Reason, Bool)] = [
            (NSWorkspace.willSleepNotification, .sleep, true), (NSWorkspace.didWakeNotification, .sleep, false),
            (NSWorkspace.screensDidSleepNotification, .displaySleep, true), (NSWorkspace.screensDidWakeNotification, .displaySleep, false),
            (NSWorkspace.sessionDidResignActiveNotification, .sessionInactive, true), (NSWorkspace.sessionDidBecomeActiveNotification, .sessionInactive, false)
        ]
        for (name, reason, active) in workspaceEvents {
            observers.append(nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.setSuspended(reason, active: active) })
        }
        observers.append(nc.addObserver(forName: NSWorkspace.willPowerOffNotification, object: nil, queue: .main) { [weak self] _ in self?.setSuspended(.sleep, active: true) })
        for (name, active) in [("com.apple.screenIsLocked", true), ("com.apple.screenIsUnlocked", false)] {
            observers.append(DistributedNotificationCenter.default().addObserver(forName: NSNotification.Name(name), object: nil, queue: .main) { [weak self] _ in self?.setSuspended(.locked, active: active) })
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            let next = self.topologyKey()
            if next != self.topology {
                self.keys.stop(); _ = self.restoreNormal("Normal — display configuration changed")
                self.topology = next; self.reconcileKeyboard(); self.refresh()
            }
        })
        for code in [SIGTERM, SIGINT, SIGHUP] {
            signal(code, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: code, queue: .main)
            source.setEventHandler { NSApp.terminate(nil) }; source.resume(); signals.append(source)
        }
    }

    func setSuspended(_ reason: BrightnessSuspension.Reason, active: Bool) {
        suspension.set(reason, active: active)
        if suspension.isSuspended { keys.stop(); _ = restoreNormal("Normal — session suspended") }
        // Resume key handling, never the previous extended brightness.
        reconcileKeyboard(); refresh()
    }

    func reconcileKeyboard() {
        guard !smokeMode else { return }
        guard !paused, !suspension.isSuspended, !thermallyLimited, !recoveryNeeded,
              backendError == nil, keyboardError == nil, AXIsProcessTrusted(),
              let target, let brightness, let value = brightness.read(target.displayID) else { keys.stop(); return }
        if keys.isRunning && keys.isEnabled { return }
        if keys.isRunning {
            keys.stop(); keyboardError = "Brightness-key tap was disabled. Use Normal / Reset to retry."
            _ = restoreNormal("Normal — keyboard service stopped")
            return
        }
        guard brightness.write(target.displayID, value), keys.start() else {
            keys.stop(); keyboardError = "Brightness-key capability check failed. Use Normal / Reset to retry."
            _ = restoreNormal("Normal — keyboard service unavailable")
            return
        }
    }

    func tick() {
        let trusted = AXIsProcessTrusted()
        if wasTrusted && !trusted { keys.stop(); _ = restoreNormal("Normal — Accessibility access was removed") }
        wasTrusted = trusted
        if suspension.isSuspended || thermallyLimited || target == nil {
            keys.stop()
            if extendedActive { _ = restoreNormal("Normal — display or thermal limit") }
            reconcileKeyboard(); refresh(); return
        }
        if let target, let value = brightness?.read(target.displayID) {
            hardware = Double(value)
            if extendedActive && value < 0.99 { _ = restoreNormal("Normal — macOS brightness changed") }
        } else {
            keys.stop()
            if extendedActive { failBackend("Hardware brightness is unavailable") }
        }
        if session != nil && !recoveryNeeded { updateExtended() }
        reconcileKeyboard(); refresh()
    }

    /// Called by both the key transport and bounded integration tests. Tests do
    /// not synthesize key events or bypass the event tap's Accessibility gate.
    @discardableResult func adjustBrightness(up: Bool, fine: Bool = false) -> Bool {
        guard !paused, !suspension.isSuspended, !thermallyLimited, !recoveryNeeded,
              backendError == nil, keyboardError == nil,
              let target, let actual = brightness?.read(target.displayID) else { return false }
        hardware = Double(actual)
        if extendedActive && actual < 0.99 { _ = restoreNormal("Normal — macOS brightness changed") }
        let next = range.step(up: up, fine: fine, hardware: hardware)
        applyPosition(next)
        return backendError == nil && keyboardError == nil && !recoveryNeeded
    }

    func applyPosition(_ position: Double) {
        guard !paused, !suspension.isSuspended, !thermallyLimited, !recoveryNeeded,
              backendError == nil, keyboardError == nil,
              let target, let brightness, let actual = brightness.read(target.displayID) else { refresh(); return }
        let value = range.select(position)
        if value <= 1 {
            guard restoreNormal("Normal brightness") else { return }
            if abs(Double(actual) - value) > 0.001 && !brightness.write(target.displayID, Float(value)) {
                failBackend("Hardware brightness adjustment failed"); return
            }
            hardware = value
        } else {
            if actual < 0.99 && !brightness.write(target.displayID, 1) { failBackend("Cannot reach normal maximum brightness"); return }
            hardware = 1
            if session == nil {
                do {
                    displayID = target.displayID
                    session = try GammaSession(device: DisplayGamma(id: target.displayID))
                    surface = try EDRSurface(screen: target)
                    lastRender = Date()
                    warmingUntil = Date().addingTimeInterval(2)
                    message = "Preparing extended brightness…"
                } catch { failBackend(String(describing: error)) }
            } else if warmingUntil == nil { updateExtended() }
        }
        refresh()
    }

    func updateExtended() {
        guard !recoveryNeeded, let session, let id = displayID,
              let screen = NSScreen.screens.first(where: { $0.displayID == id }), screen.eligible,
              !suspension.isSuspended, !thermallyLimited, range.extended > 0 else {
            if extendedActive && !recoveryNeeded { _ = restoreNormal("Normal — display or thermal limit") }
            return
        }
        let headroom = screen.maximumExtendedDynamicRangeColorComponentValue
        // Give the EDR surface one short warm-up before interpreting its changing
        // headroom. Repeats accumulate in the capped range during this interval.
        if let deadline = warmingUntil, Date() < deadline.addingTimeInterval(-1.5) { return }
        if headroom <= 1.01 {
            if let deadline = warmingUntil, Date() < deadline { return }
            _ = restoreNormal("Normal — no available XDR headroom"); return
        }
        warmingUntil = nil
        do {
            if Date().timeIntervalSince(lastRender) >= 5 { try surface?.draw(); lastRender = Date() }
            let gain = XDRMaximum.output(requested: 1 + range.extended, maximum: range.maximum, headroom: headroom)
            range.select(Double(gain))
            try session.apply(gain: gain)
            lastRequestedGain = gain
            message = String(format: "Extended · %.2f× request · %.2f× cap", gain, range.maximum)
        } catch { failBackend(String(describing: error)) }
    }

    @discardableResult func restoreNormal(_ reason: String) -> Bool {
        warmingUntil = nil; range.reset(); lastRequestedGain = 1
        do {
            try session?.restore(); session = nil; displayID = nil; recoveryNeeded = false
        } catch {
            recoveryNeeded = true; keys.stop()
            backendError = "Reset failed: \(error). Use Normal / Reset to retry."
        }
        surface = nil
        message = recoveryNeeded ? (backendError ?? "Reset needs retry") : reason
        refresh()
        return !recoveryNeeded
    }

    func failBackend(_ reason: String) {
        keys.stop(); backendError = reason + ". Use Normal / Reset to retry."
        _ = restoreNormal("Normal — adjustment stopped")
        refresh()
    }

    @objc func reset() {
        keys.discardPendingCommands()
        if restoreNormal("Normal — restored") { backendError = nil; keyboardError = nil }
        reconcileKeyboard(); refresh()
    }
    @objc func togglePause() {
        paused.toggle()
        if paused { keys.stop(); _ = restoreNormal("Normal — brightness keys paused") }
        reconcileKeyboard(); refresh()
    }
    @objc func menuLevelChanged() { applyPosition(slider.doubleValue) }
    @objc func settingsLevelChanged(_ sender: NSSlider) { applyPosition(sender.doubleValue) }
    func menuWillOpen(_ menu: NSMenu) { tick() }

    func refresh() {
        let trusted = AXIsProcessTrusted()
        let condition: String
        if let backendError { condition = backendError }
        else if let keyboardError { condition = keyboardError }
        else if paused { condition = "Brightness keys paused" }
        else if suspension.isSuspended { condition = "Waiting for wake or unlock" }
        else if thermallyLimited { condition = "Waiting for thermal headroom" }
        else if target == nil { condition = "No supported built-in XDR display" }
        else if !trusted { condition = "Access missing or out of date. If BrighterDisplay for Mac is already on, remove and re-add this installed build." }
        else if keys.isRunning { condition = "Brightness keys ready · normal through extended" }
        else { condition = "Brightness-key service unavailable" }
        detail.title = extendedActive && !recoveryNeeded ? message : condition
        settingsStatus?.stringValue = extendedActive ? message : "Normal brightness"
        permissionStatus?.stringValue = condition
        permissionButton?.isEnabled = !trusted
        permissionButton?.title = trusted ? "Control access approved" : "Open Control Access Settings…"
        keysItem.title = trusted ? "Keyboard settings…" : "Set up brightness keys…"
        pauseItem.state = paused ? .on : .off
        let position = range.position(hardware: hardware)
        slider.maxValue = range.maximum; settingsSlider?.maxValue = range.maximum
        slider.doubleValue = position; settingsSlider?.doubleValue = position
        capStepper?.doubleValue = range.maximum
        if settingsWindow?.firstResponder !== capField?.currentEditor() { capField?.stringValue = String(format: "%.2f", range.maximum) }
        normalMarker?.isHidden = range.maximum < 1.25
        normalMarker?.frame.origin.x = min(320, max(22, 22 + 436 / range.maximum - 75))
        endMarker?.stringValue = range.maximum <= 1 ? "Normal maximum" : String(format: "%.2f× cap", range.maximum)
        let counts = keys.diagnostics
        diagnosticsLabel?.stringValue = "Access: \(trusted ? "approved" : "not approved") · tap: \(keys.isEnabled ? "enabled" : "off") · v0.3.1\nBrightness up \(counts.up) · down \(counts.down) · repeats \(counts.repeats) · releases \(counts.releases)\nSwallowed \(counts.swallowed) · forwarded \(counts.forwardedBrightness) · applied \(appliedKeys) · rejected \(rejectedKeys)\nSystem events \(counts.systemEvents) · cancelled \(counts.cancelled) · tap failures \(counts.tapFailures) · last: \(counts.last)"
        let enabled = !paused && !suspension.isSuspended && !thermallyLimited && !recoveryNeeded && backendError == nil && keyboardError == nil && target != nil && brightness != nil
        slider.isEnabled = enabled; settingsSlider?.isEnabled = enabled
        status?.button?.image = NSImage(systemSymbolName: extendedActive ? "sun.max.fill" : "sun.max", accessibilityDescription: "BrighterDisplay for Mac")
    }

    @objc func capEdited(_ sender: NSControl) {
        let value: Double?
        if sender === capStepper { value = capStepper?.doubleValue }
        else { value = Double(capField?.stringValue ?? "") }
        guard let value, value.isFinite, (1...XDRMaximum.upperBound).contains(value) else {
            capField?.stringValue = String(format: "%.2f", range.maximum)
            return
        }
        guard value != range.maximum else { return }
        keys.discardPendingCommands()
        range.setMaximum(value)
        UserDefaults.standard.set(range.maximum, forKey: XDRMaximum.preferenceKey)
        if session != nil {
            if range.extended == 0 { _ = restoreNormal("Normal — maximum is 1.00×") }
            else if warmingUntil == nil { updateExtended() }
        }
        capField?.stringValue = String(format: "%.2f", range.maximum)
        reconcileKeyboard(); refresh()
    }

    @objc func showSettings() {
        if let settingsWindow { settingsWindow.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); refresh(); return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 530), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "BrighterDisplay for Mac — Settings"; window.isReleasedWhenClosed = false
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 530)); window.contentView = content
        func text(_ value: String, _ y: Double, _ height: Double, _ size: Double) -> NSTextField {
            let label = NSTextField(wrappingLabelWithString: value); label.font = .systemFont(ofSize: size)
            label.frame = NSRect(x: 22, y: y, width: 436, height: height); content.addSubview(label); return label
        }
        _ = text("Brightness keys. One continuous range.", 484, 28, 20)
        _ = text("Use Brightness Up and Down as usual. Above normal maximum, the keys continue into XDR up to your saved cap. Lowering brightness returns through the normal range.", 415, 60, 13)
        permissionStatus = text("", 356, 50, 12)
        let permission = NSButton(title: "Open Control Access Settings…", target: self, action: #selector(openAccessibility))
        permission.bezelStyle = .rounded; permission.frame = NSRect(x: 18, y: 319, width: 275, height: 32); content.addSubview(permission); permissionButton = permission
        settingsStatus = text("Normal brightness", 286, 24, 13)
        let level = NSSlider(value: range.position(hardware: hardware), minValue: 0, maxValue: range.maximum, target: self, action: #selector(settingsLevelChanged(_:)))
        level.frame = NSRect(x: 22, y: 253, width: 436, height: 25); level.isContinuous = true
        level.setAccessibilityLabel("Brightness — normal through capped XDR"); content.addSubview(level); settingsSlider = level
        let dim = text("Dim", 233, 18, 10); dim.frame.size.width = 80
        let normal = text("Normal maximum", 233, 18, 10); normal.frame.size.width = 150; normal.alignment = .center; normalMarker = normal
        let end = text("", 233, 18, 10); end.frame = NSRect(x: 360, y: 233, width: 98, height: 18); end.alignment = .right; endMarker = end
        let capName = text("XDR maximum", 195, 22, 13); capName.frame.size.width = 140
        let field = NSTextField(string: String(format: "%.2f", range.maximum))
        field.frame = NSRect(x: 165, y: 193, width: 75, height: 25)
        field.cell?.sendsActionOnEndEditing = true
        field.target = self; field.action = #selector(capEdited(_:)); field.setAccessibilityLabel("XDR maximum relative gain")
        content.addSubview(field); capField = field
        let stepper = NSStepper(frame: NSRect(x: 246, y: 191, width: 22, height: 28))
        stepper.minValue = 1; stepper.maxValue = XDRMaximum.upperBound; stepper.increment = 0.25
        stepper.doubleValue = range.maximum; stepper.target = self; stepper.action = #selector(capEdited(_:))
        stepper.setAccessibilityLabel("Adjust XDR maximum"); content.addSubview(stepper); capStepper = stepper
        let units = text("× requested gain", 195, 22, 12); units.frame = NSRect(x: 280, y: 195, width: 178, height: 22)
        _ = text("Saved across launches. Range: 1.00–16.00×, limited by available headroom. This is a relative request, not measured nits.", 148, 38, 11)
        let reset = NSButton(title: "Normal / Reset", target: self, action: #selector(reset)); reset.bezelStyle = .rounded
        reset.frame = NSRect(x: 18, y: 103, width: 140, height: 32); content.addSubview(reset)
        let risks = text("Extended output can add heat and battery drain, and clip HDR. Reset for color-critical work.", 94, 43, 10)
        risks.frame = NSRect(x: 171, y: 94, width: 287, height: 43)
        diagnosticsLabel = text("", 12, 76, 10)
        settingsWindow = window; window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); refresh()
    }

    @objc func openAccessibility() {
        // Only this user-invoked button requests the OS prompt. The owner grants
        // access in System Settings; the heartbeat notices and arms automatically.
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") { NSWorkspace.shared.open(url) }
    }
    @objc func about() {
        let alert = NSAlert(); alert.messageText = "BrighterDisplay for Mac — free, open-source preview"
        alert.informativeText = "Your brightness keys span normal hardware brightness and available XDR headroom. Accessibility approval is required once; no separate enabling step. Launch starts at normal brightness. Reset, quit, sleep and lock restore the owned color table. Extended output uses EDR and gamma scaling; it can drain battery, add heat, clip HDR and change color accuracy. Do not combine with other gamma utilities. Values are relative, not measured nits. No capture, network, login item, daemon or paid gates."
        alert.runModal()
    }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        keys.stop()
        guard restoreNormal("Normal — quitting") else {
            let alert = NSAlert(); alert.messageText = "Display reset needs another attempt"
            alert.informativeText = "BrighterDisplay for Mac could not verify restoration. Keep it open and use Normal / Reset to retry."
            alert.addButton(withTitle: "Keep open"); alert.addButton(withTitle: "Quit anyway")
            return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
        }
        return .terminateNow
    }

    func runSmoke() {
        guard let target, let brightness, let originalHardware = brightness.read(target.displayID) else { print("SMOKE unavailable"); NSApp.terminate(nil); return }
        let snapshots = NSScreen.screens.compactMap { s -> (UInt32, Gamma)? in
            guard let g = try? DisplayGamma(id: s.displayID).read() else { return nil }; return (s.displayID, g)
        }
        print("SMOKE transport=direct-controller-not-physical-keys accessibilityTrusted=\(AXIsProcessTrusted())")
        print("SMOKE eligible=\(NSScreen.screens.filter { $0.eligible }.count) defaultNormal=\(!extendedActive) noBoostToggle=\(!menu.items.contains { $0.title.contains("Enable boost") })")
        applyPosition(1)
        adjustBrightness(up: true)
        adjustBrightness(up: false)
        print("SMOKE pendingCancellation=\(session == nil && range.extended == 0)")
        for _ in 0..<4 { adjustBrightness(up: true) }
        print("SMOKE repeatedKeysDuringWarmup=\(range.extended == min(0.25, range.maximum - 1)) cap=\(range.maximum)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            self.tick()
            print("SMOKE extendedActive=\(self.session != nil && self.warmingUntil == nil) status=\(self.message)")
            for _ in 0..<4 { self.adjustBrightness(up: false) }
            print("SMOKE boundaryRestores=\(self.session == nil && self.range.extended == 0)")
            self.adjustBrightness(up: false)
            print("SMOKE normalDown=\(abs((brightness.read(target.displayID) ?? -1) - 0.9375) < 0.02)")
            self.applyPosition(1.125); self.updateExtended()
            self.setSuspended(.locked, active: true)
            self.setSuspended(.locked, active: false)
            print("SMOKE simulatedLockResetsWithoutResume=\(self.session == nil && self.range.extended == 0)")
            _ = self.restoreNormal("Smoke reset")
            let hardwareRestored = brightness.write(target.displayID, originalHardware)
            print("SMOKE hardwareRestored=\(hardwareRestored)")
            for (id, baseline) in snapshots { print("SMOKE display=\(id) baselineRestored=\((try? DisplayGamma(id: id).read().matches(baseline)) ?? false)") }
            NSApp.terminate(nil)
        }
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
