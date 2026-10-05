import BackgroundCore
import Foundation

// Float4 alignment makes the stride 32 bytes, matching the Metal InkVertex struct.
// `paperAndMountainRenderThroughProductionShaders` exercises the buffer layout on GPU.
struct InkVertex: Sendable {
    let position: SIMD2<Float>
    let color: SIMD4<Float>
}

struct InkMesh: Sendable {
    let vertices: [InkVertex]
}

enum InkMeshError: Error, LocalizedError {
    case invalidGeometry
    case invalidPolygon

    var errorDescription: String? {
        switch self {
        case .invalidGeometry: "The ink geometry contains invalid coordinates or widths."
        case .invalidPolygon: "An ink wash could not be triangulated."
        }
    }
}

/// Compiles simple polygon washes and strokes to ordered triangles.
/// Washes are required to be simple polygons without holes; this is a caller contract.
struct InkMeshCompiler {
    func compile(_ scene: InkScene, clippingToBounds: Bool = false) throws -> InkMesh {
        guard scene.bounds.x.isFinite, scene.bounds.y.isFinite,
              scene.bounds.x > 0, scene.bounds.y > 0 else { throw InkMeshError.invalidGeometry }
        var vertices: [InkVertex] = []
        for primitive in scene.primitives {
            let rgb: SIMD3<Double> = primitive.color
            guard [rgb.x, rgb.y, rgb.z, primitive.opacity].allSatisfy({ $0.isFinite && (0...1).contains($0) }),
                  primitive.points.allSatisfy({ valid($0) }) else {
                throw InkMeshError.invalidGeometry
            }
            let color: SIMD4<Float> = [Float(rgb.x), Float(rgb.y), Float(rgb.z), Float(primitive.opacity)]
            switch primitive {
            case let .wash(points, _, _), let .colorWash(points, _, _):
                for triangle in try triangulate(points) {
                    vertices += triangle.map { InkVertex(position: SIMD2<Float>($0), color: color) }
                }
            case let .stroke(points, widths, _, _), let .colorStroke(points, widths, _, _):
                guard points.count == widths.count,
                      widths.allSatisfy({ $0.isFinite && $0 >= 0 && $0 < 1e8 }) else {
                    throw InkMeshError.invalidGeometry
                }
                vertices += stroke(points, widths: widths, color: color)
            }
        }
        return InkMesh(vertices: clippingToBounds ? clipped(vertices, bounds: SIMD2<Float>(scene.bounds)) : vertices)
    }

    /// Clips expanded triangles, not their centerlines, so edge strokes own only
    /// their local portion. expandedEdgeStrokeOwnsOnlyItsHalfAndDefaultIsUnchanged
    /// tests the half-rectangle area and the unchanged default path.
    private func clipped(_ vertices: [InkVertex], bounds: SIMD2<Float>) -> [InkVertex] {
        var output: [InkVertex] = []
        for i in stride(from: 0, to: vertices.count, by: 3) {
            var polygon = Array(vertices[i..<(i + 3)])
            for (axis, boundary, greater) in [(0, Float(0), true), (0, bounds.x, false),
                                              (1, Float(0), true), (1, bounds.y, false)] {
                guard var previous = polygon.last else { break }
                var next: [InkVertex] = []
                var wasInside: Bool = greater ? previous.position[axis] >= boundary : previous.position[axis] <= boundary
                for current in polygon {
                    let inside: Bool = greater ? current.position[axis] >= boundary : current.position[axis] <= boundary
                    if inside != wasInside {
                        // Use the same endpoint order on both sides of a shared triangle edge.
                        // sharedTriangleEdgesClipToIdenticalBoundaryVertices tests identical bits.
                        let a: InkVertex = previous.position[axis] < current.position[axis] ? previous : current
                        let b: InkVertex = previous.position[axis] < current.position[axis] ? current : previous
                        let t: Float = (boundary - a.position[axis]) / (b.position[axis] - a.position[axis])
                        var position: SIMD2<Float> = a.position + (b.position - a.position) * t
                        position[axis] = boundary
                        next.append(InkVertex(position: position, color: a.color + (b.color - a.color) * t))
                    }
                    if inside { next.append(current) }
                    previous = current; wasInside = inside
                }
                polygon = next
            }
            guard polygon.count >= 3 else { continue }
            for j in 1..<(polygon.count - 1) {
                let a = polygon[0].position, b = polygon[j].position, c = polygon[j + 1].position
                let area: Float = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
                if abs(area) > 1e-12 { output += [polygon[0], polygon[j], polygon[j + 1]] }
            }
        }
        return output
    }

    private func valid(_ p: SIMD2<Double>) -> Bool {
        p.x.isFinite && p.y.isFinite && abs(p.x) < 1e8 && abs(p.y) < 1e8
    }

    /// This straightforward ear search is O(n³) worst-case for small wash polygons.
    /// Normalize predicates to
    /// reduce dependence on world scale. Concave/both-winding coverage is tested by
    /// `concaveFillCoversAreaInBothWindings` and duplicate/collinear coverage separately.
    private func triangulate(_ input: [SIMD2<Double>]) throws -> [[SIMD2<Double>]] {
        var points: [SIMD2<Double>] = []
        for p in input {
            if let previous = points.last, lengthSquared(p - previous) < 1e-16 { continue }
            points.append(p)
        }
        if let first = points.first, let last = points.last,
           lengthSquared(first - last) < 1e-16 { points.removeLast() }
        guard points.count >= 3 else { return [] }

        let origin = points[0]
        let extent = points.reduce(0.0) { max($0, abs($1.x - origin.x), abs($1.y - origin.y)) }
        guard extent > 1e-8 else { return [] }
        let normalized = points.map { ($0 - origin) / extent }
        let signedArea = normalized.indices.reduce(0.0) {
            $0 + cross(normalized[$1], normalized[($1 + 1) % normalized.count])
        }
        guard abs(signedArea) > 1e-12 else { return [] }
        let direction: Double = signedArea > 0 ? 1 : -1
        var indices = Array(points.indices)
        var result: [[SIMD2<Double>]] = []

        while indices.count > 3 {
            var clipped: Bool = false
            for i in indices.indices {
                let a = indices[(i + indices.count - 1) % indices.count]
                let b = indices[i]
                let c = indices[(i + 1) % indices.count]
                let turn = cross(normalized[b] - normalized[a], normalized[c] - normalized[b]) * direction
                if abs(turn) < 1e-12 {
                    indices.remove(at: i)
                    clipped = true
                    break
                }
                guard turn > 0 else { continue }
                let occupied = indices.contains { p in
                    if p == a || p == b || p == c { return false }
                    let point = normalized[p]
                    return cross(normalized[b] - normalized[a], point - normalized[a]) * direction >= -1e-12
                        && cross(normalized[c] - normalized[b], point - normalized[b]) * direction >= -1e-12
                        && cross(normalized[a] - normalized[c], point - normalized[c]) * direction >= -1e-12
                }
                guard !occupied else { continue }
                result.append([points[a], points[b], points[c]])
                indices.remove(at: i)
                clipped = true
                break
            }
            guard clipped else { throw InkMeshError.invalidPolygon }
        }
        if indices.count == 3 { result.append(indices.map { points[$0] }) }
        return result
    }

    /// Expands segments to a strip, capping miter length at two half-widths.
    /// Duplicate/hairpin handling is tested by `repeatedStrokePointDoesNotCreateInvalidJoin`
    /// and `hairpinJoinHasBoundedExtent`. `reversingStrokeCoversBothSidesEvenly`
    /// tests coverage at exact and near reversals in four orientations.
    private func stroke(_ input: [SIMD2<Double>], widths: [Double],
                        color: SIMD4<Float>) -> [InkVertex] {
        var points: [SIMD2<Double>] = []
        var cleanWidths: [Double] = []
        for (p, width) in zip(input, widths) {
            if let previous = points.last, lengthSquared(p - previous) < 1e-16 { continue }
            points.append(p)
            cleanWidths.append(width)
        }
        guard points.count >= 2 else { return [] }
        let normals = zip(points, points.dropFirst()).map { a, b in
            let delta = b - a
            let tangent = delta / sqrt(lengthSquared(delta))
            return SIMD2<Double>(-tangent.y, tangent.x)
        }
        func offset(at index: Int, segmentNormal: SIMD2<Double>) -> SIMD2<Double> {
            let previous: SIMD2<Double> = normals[max(0, index - 1)]
            let next: SIMD2<Double> = normals[min(normals.count - 1, index)]
            let sum: SIMD2<Double> = previous + next
            let sumLength: Double = sqrt(lengthSquared(sum))
            let halfWidth: Double = cleanWidths[index] * 0.5
            // Keep each segment's orientation when a shared miter is undefined.
            guard sumLength > 1e-4 else { return segmentNormal * halfWidth }
            let normal: SIMD2<Double> = sum / sumLength
            let cosine: Double = abs(normal.x * next.x + normal.y * next.y)
            let scale: Double = min(2, 1 / max(0.5, cosine))
            return normal * (halfWidth * scale)
        }

        var vertices: [InkVertex] = []
        vertices.reserveCapacity((points.count - 1) * 6)
        for i in 0..<(points.count - 1) {
            let startOffset: SIMD2<Double> = offset(at: i, segmentNormal: normals[i])
            let endOffset: SIMD2<Double> = offset(at: i + 1, segmentNormal: normals[i])
            let startLeft: SIMD2<Double> = points[i] + startOffset
            let startRight: SIMD2<Double> = points[i] - startOffset
            let endLeft: SIMD2<Double> = points[i + 1] + endOffset
            let endRight: SIMD2<Double> = points[i + 1] - endOffset
            for point in [startLeft, startRight, endLeft, startRight, endRight, endLeft] {
                vertices.append(InkVertex(position: SIMD2<Float>(point), color: color))
            }
        }
        return vertices
    }

    private func cross(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double { a.x * b.y - a.y * b.x }
    private func lengthSquared(_ p: SIMD2<Double>) -> Double { p.x * p.x + p.y * p.y }
}
