import AppKit
import Metal
import QuartzCore

extension NSScreen {
    var displayID: CGDirectDisplayID { (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0 }
    var eligible: Bool { CGDisplayIsBuiltin(displayID) != 0 && CGDisplayMirrorsDisplay(displayID) == kCGNullDirectDisplay && maximumPotentialExtendedDynamicRangeColorComponentValue > 1 }
}
struct DisplayGamma: GammaDevice {
    let id: CGDirectDisplayID
    func read() throws -> Gamma {
        let capacity = CGDisplayGammaTableCapacity(id)
        guard capacity >= 2, capacity <= 65536 else { throw LiftError.unavailable("Display has no readable color table") }
        var r = [Float](repeating: 0, count: Int(capacity)), g = r, b = r
        var count: UInt32 = 0
        guard CGGetDisplayTransferByTable(id, capacity, &r, &g, &b, &count) == .success, count >= 2, count <= capacity else { throw LiftError.unavailable("Cannot read display color table") }
        return Gamma(red: Array(r.prefix(Int(count))), green: Array(g.prefix(Int(count))), blue: Array(b.prefix(Int(count))))
    }
    func write(_ value: Gamma) throws {
        guard CGSetDisplayTransferByTable(id, UInt32(value.red.count), value.red, value.green, value.blue) == .success else { throw LiftError.unavailable("Cannot set display color table") }
    }
}

/// A tiny, click-through EDR stimulus; desktop scaling is done by GammaSession.
final class EDRSurface {
    let window: NSWindow
    let layer: CAMetalLayer
    let queue: MTLCommandQueue
    init(screen: NSScreen) throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else { throw LiftError.unavailable("Metal unavailable") }
        self.queue = queue
        layer = CAMetalLayer(); layer.device = device; layer.pixelFormat = .rgba16Float
        layer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
        layer.wantsExtendedDynamicRangeContent = true
        layer.isOpaque = false; layer.drawableSize = CGSize(width: 2, height: 2)
        window = NSWindow(contentRect: NSRect(x: screen.frame.minX, y: screen.frame.minY, width: 1, height: 1), styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.isOpaque = false; window.backgroundColor = .clear
        window.ignoresMouseEvents = true; window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1)); view.wantsLayer = true; layer.frame = view.bounds; view.layer?.addSublayer(layer)
        window.contentView = view
        window.orderFrontRegardless()
        try draw()
    }
    func draw() throws {
        guard let drawable = layer.nextDrawable(), let command = queue.makeCommandBuffer() else { throw LiftError.unavailable("EDR drawable unavailable") }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .clear; pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 8, green: 8, blue: 8, alpha: 1)
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { throw LiftError.unavailable("EDR render failed") }
        encoder.endEncoding(); command.present(drawable); command.commit(); command.waitUntilCompleted()
        guard command.status == .completed else { throw LiftError.unavailable("GPU command failed") }
    }
    deinit { window.orderOut(nil) }
}
