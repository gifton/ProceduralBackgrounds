@testable import BackgroundUI
import Metal
import Testing

@MainActor
func readInkFrame(_ renderer: ShanShuiRenderer, width: Int, height: Int) throws -> [SIMD4<UInt8>] {
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
    descriptor.storageMode = .shared
    descriptor.usage = [.renderTarget, .shaderRead]
    let output = try #require(renderer.device.makeTexture(descriptor: descriptor))
    let command = try renderer.encodeFrame(into: output)
    command.commit()
    command.waitUntilCompleted()
    #expect(command.status == .completed, "\(String(describing: command.error))")
    var pixels = [SIMD4<UInt8>](repeating: .zero, count: width * height)
    pixels.withUnsafeMutableBytes {
        output.getBytes($0.baseAddress!, bytesPerRow: width * 4,
                        from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
    }
    return pixels
}
