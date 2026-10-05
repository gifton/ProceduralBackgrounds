import Foundation

public enum ShanShuiWorldError: Error, LocalizedError {
    case invalidCamera, invalidMovement, invalidViewport, invalidWindow, indexOverflow

    public var errorDescription: String? {
        switch self {
        case .invalidCamera: "The landscape camera position is invalid."
        case .invalidMovement: "The landscape movement is outside its supported range."
        case .invalidViewport: "The landscape preview size is invalid."
        case .invalidWindow: "The requested landscape window is invalid."
        case .indexOverflow: "The landscape reached the end of its coordinate range."
        }
    }
}

/// Horizontal center in chunk-local coordinates; world ink remains local too.
public struct ShanShuiCamera: Sendable {
    public let index: Int64
    public let offset: Double

    public init(index: Int64 = 0, offset: Double = 600) throws {
        guard offset.isFinite, offset >= 0, offset < 1200 else {
            throw ShanShuiWorldError.invalidCamera
        }
        self.index = index
        self.offset = offset
    }

    /// O(1). Per-move contract: finite distance with magnitude ≤ 1e9 world units.
    /// Boundary/reversal/overflow cases: cameraCrossesBothEdgesAndReturns,
    /// tinyBoundaryMovementsStayNormalizedAndReverseWithinRounding and
    /// cameraRejectsInvalidInputsAndOverflow.
    public func moving(by distance: Double) throws -> ShanShuiCamera {
        guard distance.isFinite, abs(distance) <= 1e9,
              var whole = Int64(exactly: (distance / 1200).rounded(.towardZero)) else {
            throw ShanShuiWorldError.invalidMovement
        }
        var local: Double = offset + distance.truncatingRemainder(dividingBy: 1200)
        if local < 0 {
            local += 1200
            whole -= 1
        }
        // Adding 1200 can round a tiny negative residual to the upper boundary.
        // Normalize that rounded carry as well, keeping the offset half-open.
        if local >= 1200 {
            local -= 1200
            whole += 1
        }
        let next = index.addingReportingOverflow(whole)
        guard !next.overflow else { throw ShanShuiWorldError.indexOverflow }
        return try ShanShuiCamera(index: next.partialValue, offset: local)
    }

    /// x_relative = 1200(index_chunk − index_camera) − offset.
    public func relativeOrigin(for chunkIndex: Int64) throws -> Double {
        let delta = chunkIndex.subtractingReportingOverflow(index)
        guard !delta.overflow else { throw ShanShuiWorldError.indexOverflow }
        return Double(delta.partialValue) * 1200 - offset
    }

    /// O(C), at most seven indices for the supported width/prefetch ranges.
    /// Uses a half-open visible interval; windowsUseFloorAndExcludeTheirRightEdge
    /// exercises exact boundaries, negative coordinates and maximal spans.
    public func window(width: Double, prefetch: Int = 1) throws -> [Int64] {
        guard width.isFinite, width > 0, width <= 4800, (0...1).contains(prefetch) else {
            throw ShanShuiWorldError.invalidWindow
        }
        let half: Double = width / 2
        guard half > 0 else { throw ShanShuiWorldError.invalidWindow }
        let left: Double = offset - half
        let right: Double = offset + half
        // Preserve the interval's sign when division of a subnormal rounds to
        // zero. tinySpansNeverCreateAnInvalidClosedRange covers this boundary.
        let lower: Int64 = left < 0 ? min(-1, Int64(floor(left / 1200))) : Int64(floor(left / 1200))
        let upper: Int64 = right > 0 ? max(0, Int64(ceil(right / 1200)) - 1) : Int64(ceil(right / 1200)) - 1
        let first: Int64 = lower - Int64(prefetch)
        let last: Int64 = max(lower, upper) + Int64(prefetch)
        return try (first...last).map { delta in
            let result = index.addingReportingOverflow(delta)
            guard !result.overflow else { throw ShanShuiWorldError.indexOverflow }
            return result.partialValue
        }
    }
}

/// Uniform height scale with a maximum four-chunk visible span.
public struct ShanShuiScrollViewport: Sendable {
    public let scale: Double
    public let visibleWidth: Double

    public init(size: SIMD2<Double>) throws {
        guard size.x.isFinite, size.y.isFinite, size.x > 0, size.y > 0 else {
            throw ShanShuiWorldError.invalidViewport
        }
        let scale: Double = size.y / 800
        let span: Double = size.x / scale
        guard scale.isFinite, scale > 0, span.isFinite, span > 0 else {
            throw ShanShuiWorldError.invalidViewport
        }
        self.scale = scale
        self.visibleWidth = min(4800, span)
    }
}
