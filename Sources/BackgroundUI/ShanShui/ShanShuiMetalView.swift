import MetalKit
import SwiftUI

#if os(macOS)
struct ShanShuiMetalView: NSViewRepresentable {
    let renderer: ShanShuiRenderer

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: renderer.device)
        renderer.attach(to: view)
        return view
    }

    func updateNSView(_ view: MTKView, context: Context) {
        renderer.attach(to: view)
    }

    static func dismantleNSView(_ view: MTKView, coordinator: ()) {
        view.delegate = nil
        view.releaseDrawables()
    }
}
#else
struct ShanShuiMetalView: UIViewRepresentable {
    let renderer: ShanShuiRenderer

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: renderer.device)
        renderer.attach(to: view)
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        renderer.attach(to: view)
    }

    static func dismantleUIView(_ view: MTKView, coordinator: ()) {
        view.delegate = nil
        view.releaseDrawables()
    }
}
#endif
