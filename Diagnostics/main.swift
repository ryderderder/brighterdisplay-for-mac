// Original diagnostic. Private ABI references: Lunar (MIT); see ATTRIBUTION.md.
import AppKit
import IOKit
import Darwin
let app = NSApplication.shared
func symbol<T>(_ h: UnsafeMutableRawPointer?, _ name: String, _: T.Type) -> T? {
    guard let h, let p = dlsym(h, name) else { return nil }; return unsafeBitCast(p, to: T.self)
}
let ds = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY | RTLD_LOCAL)
let cd = dlopen("/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay", RTLD_LAZY | RTLD_LOCAL)
typealias SetFloat = @convention(c) (UInt32, Float) -> Int32
typealias GetFloat = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
typealias GetDouble = @convention(c) (UInt32) -> Double
typealias GetIndex = @convention(c) (UInt32) -> Int32
typealias CopyPreset = @convention(c) (UInt32, Int32) -> Unmanaged<CFDictionary>?
typealias GetRange = @convention(c) (UInt32, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>) -> Int32
typealias GetBool = @convention(c) (UInt32, UnsafeMutablePointer<Bool>) -> Int32
func telemetry() {
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleARMBacklight"))
    guard service != 0 else { print("backlightTelemetry=unavailable"); return }
    defer { IOObjectRelease(service) }
    if let p = IORegistryEntryCreateCFProperty(service, "IODisplayParameters" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] {
        for key in ["brightness", "BrightnessMilliNits", "BrightnessMicroAmps"] { if let v = p[key] { print("driverReported \(key)=\(v)") } }
    }
}
for screen in NSScreen.screens where screen.eligible {
    let id = screen.displayID
    print("builtIn=\(id) currentEDR=\(screen.maximumExtendedDynamicRangeColorComponentValue) potentialEDR=\(screen.maximumPotentialExtendedDynamicRangeColorComponentValue)")
    for name in ["DisplayServicesGetBrightness", "DisplayServicesGetLinearBrightness"] {
        var v: Float = -1
        if let f = symbol(ds, name, GetFloat.self) { print("\(name) result=\(f(id,&v)) value=\(v)") }
    }
    for name in ["CoreDisplay_Display_GetUserBrightness", "CoreDisplay_Display_GetLinearBrightness", "CoreDisplay_Display_GetDynamicLinearBrightness"] {
        if let f = symbol(cd, name, GetDouble.self) { print("\(name)=\(f(id))") }
    }
    if let f = symbol(ds, "DisplayServicesAmbientLightCompensationEnabled", GetBool.self) { var enabled = false; print("autoBrightness result=\(f(id, &enabled)) enabled=\(enabled)") }
    if let f = symbol(cd, "CoreDisplay_Display_GetActivePresetIndex", GetIndex.self), let copy = symbol(cd, "CoreDisplay_Display_CopyPreset", CopyPreset.self) {
        let index = f(id); print("activePresetIndex=\(index)")
        if let p = copy(id,index)?.takeRetainedValue() as? [String: Any] {
            for key in ["PresetName","PresetMaxSDRLuminance","PresetMaxHDRLuminance","PresetHostMaxPotentialEDRHeadroom","PresetHostMaxSliderBrightness","PresetHostMinSliderBrightness"] { if let v = p[key] { print("preset \(key)=\(v)") } }
        }
    }
    if let f = symbol(ds, "DisplayServicesGetLinearBrightnessUsableRange", GetRange.self) { var lo: Int32 = -1; var hi: Int32 = -1; print("linearRange result=\(f(id,&lo,&hi)) min=\(lo) max=\(hi)") }
    telemetry()
}
