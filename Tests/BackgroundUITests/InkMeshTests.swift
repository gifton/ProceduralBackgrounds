@testable import BackgroundCore
@testable import BackgroundUI
import Testing

struct InkMeshTests {
    @Test(arguments: [false, true])
    func concaveFillCoversAreaInBothWindings(reversed: Bool) throws {
        let polygon: [SIMD2<Double>] = [[0, 0], [4, 0], [4, 4], [2, 2], [0, 4]]
        let points = reversed ? Array(polygon.reversed()) : polygon
        let mesh = try compile([.wash(points: points, tone: 0, opacity: 1)])
        #expect(abs(area(mesh) - 12) < 1e-5)
    }

    @Test
    func duplicateAndCollinearFillPointsDoNotLoseArea() throws {
        let points: [SIMD2<Double>] = [[0, 0], [0, 0], [2, 0], [4, 0], [4, 4], [0, 4], [0, 0]]
        let mesh = try compile([.wash(points: points, tone: 0, opacity: 1)])
        #expect(abs(area(mesh) - 16) < 1e-5)
    }

    @Test
    func repeatedStrokePointDoesNotCreateInvalidJoin() throws {
        let mesh = try compile([.stroke(points: [[0, 0], [0, 0], [20, 0]],
                                        widths: [2, 2, 2], tone: 0, opacity: 1)])
        #expect(abs(area(mesh) - 40) < 1e-5)
        #expect(mesh.vertices.allSatisfy { $0.position.x.isFinite && $0.position.y.isFinite })
    }

    @Test
    func hairpinJoinHasBoundedExtent() throws {
        let mesh = try compile([.stroke(points: [[0, 0], [10, 0], [0.0001, 0.0001]],
                                        widths: [2, 2, 2], tone: 0, opacity: 1)])
        #expect(!mesh.vertices.isEmpty)
        for vertex in mesh.vertices {
            #expect(vertex.position.x.isFinite && vertex.position.y.isFinite)
            #expect((-2...12).contains(vertex.position.x))
            #expect((-2...2).contains(vertex.position.y))
        }
    }

    @Test(arguments: [0.0, 1e-5, -1e-5])
    func reversingStrokeCoversBothSidesEvenly(deviation: Double) throws {
        for quarterTurns in 0..<4 {
            let points: [SIMD2<Double>] = [[0, 0], [10, 0], [0, deviation]].map {
                rotate($0, quarterTurns: quarterTurns)
            }
            let mesh = try compile([.stroke(points: points, widths: [2, 2, 2],
                                            tone: 0, opacity: 0.5)])
            // Each retraced segment covers each sample once, so both sides receive
            // two alpha blends. These points lie away from the triangle edges.
            for side in [-0.4, 0.4] {
                let point = SIMD2<Float>(rotate([4, side], quarterTurns: quarterTurns))
                #expect(coverage(mesh, at: point) == 2)
            }
        }
    }

    @Test
    func invalidGeometryIsRejected() {
        #expect(throws: InkMeshError.self) {
            try compile([.stroke(points: [[0, 0], [1, 1]], widths: [1], tone: 0, opacity: 1)])
        }
        #expect(throws: InkMeshError.self) {
            try compile([.wash(points: [[0, 0], [.nan, 1], [1, 0]], tone: 0, opacity: 1)])
        }
        #expect(throws: InkMeshError.self) {
            try compile([.wash(points: [[0, 0], [1, 1], [1, 0]], tone: .infinity, opacity: 1)])
        }
    }

    @Test
    func emptyOrCollapsedStrokesHaveNoTriangles() throws {
        let mesh = try compile([
            .stroke(points: [], widths: [], tone: 0, opacity: 1),
            .stroke(points: [[3, 3], [3, 3]], widths: [1, 1], tone: 0, opacity: 1)
        ])
        #expect(mesh.vertices.isEmpty)
    }

    @Test(arguments: [UInt64(0), 42, UInt64.max])
    func generatedMountainCompilesToFiniteTriangles(seed: UInt64) throws {
        let mesh = try InkMeshCompiler().compile(ShanShuiGenerator().generate(seed: seed))
        #expect(mesh.vertices.count > 300)
        #expect(mesh.vertices.count % 3 == 0)
        #expect(mesh.vertices.allSatisfy {
            $0.position.x.isFinite && $0.position.y.isFinite && $0.color.w.isFinite
        })
    }

    @Test(arguments: (0..<32).map { UInt64($0) } + [42, 43, 60, 9_999, 793_993, 7_293_725_857_078_157_220, UInt64.max - 1, UInt64.max])
    func completeLandscapeCompilesToFiniteTriangles(seed: UInt64) throws {
        let mesh = try InkMeshCompiler().compile(ShanShuiLandscapeGenerator().generate(seed: seed))
        #expect(mesh.vertices.count > 1000 && mesh.vertices.count % 3 == 0)
        #expect(mesh.vertices.allSatisfy {
            $0.position.x.isFinite && $0.position.y.isFinite && $0.color.w.isFinite
        })
    }

    @Test(arguments: ShanShuiElement.allCases, (0..<128).map { UInt64($0) } + [UInt64.max - 1, UInt64.max])
    func eachElementCompilesToFiniteTriangles(element: ShanShuiElement, seed: UInt64) throws {
        let scene = ShanShuiElementGenerator(element: element).generate(seed: seed)
        let mesh = try InkMeshCompiler().compile(scene)
        #expect(mesh.vertices.count > 30 && mesh.vertices.count % 3 == 0)
        #expect(mesh.vertices.allSatisfy {
            $0.position.x.isFinite && $0.position.y.isFinite && $0.color.w.isFinite
        })
    }

    @Test(arguments: (0..<128).map { UInt64($0) } + [793_993, 7_293_725_857_078_157_220, UInt64.max], [false, true])
    func placedBareTreesFitIncludingStrokeJoins(seed: UInt64, reflected: Bool) throws {
        let plan = ShanShuiComposition(seed: seed)
        for tree in plan.foreground where tree.subject == .bareTree {
            let study = ShanShuiElementGenerator(element: .bareTree).generate(seed: tree.seed)
            let primitives: [InkPrimitive] = study.primitives.map { primitive in
                let points = primitive.points.map { point in
                    let p = tree.anchor + (point - [400, 500]) * tree.scale
                    return SIMD2<Double>(reflected ? 1200 - p.x : p.x, p.y)
                }
                switch primitive {
                case .wash:
                    return .wash(points: points, tone: primitive.tone, opacity: primitive.opacity)
                case let .colorWash(_, color, opacity):
                    return .colorWash(points: points, color: color, opacity: opacity)
                case let .colorStroke(_, widths, color, opacity):
                    return .colorStroke(points: points, widths: widths.map { $0 * tree.scale }, color: color, opacity: opacity)
                case let .stroke(_, widths, tone, opacity):
                    return .stroke(points: points, widths: widths.map { $0 * tree.scale }, tone: tone, opacity: opacity)
                }
            }
            let mesh = try InkMeshCompiler().compile(ShanShuiScene(seed: seed, bounds: [1200, 800], primitives: primitives))
            #expect(!mesh.vertices.isEmpty)
            #expect(mesh.vertices.allSatisfy {
                (0...1200).contains($0.position.x) && (0...800).contains($0.position.y)
            })
        }
    }

    private func compile(_ primitives: [InkPrimitive]) throws -> InkMesh {
        try InkMeshCompiler().compile(ShanShuiScene(seed: 0, bounds: [800, 800], primitives: primitives))
    }

    private func area(_ mesh: InkMesh) -> Double {
        stride(from: 0, to: mesh.vertices.count, by: 3).reduce(0) { total, index in
            let a = mesh.vertices[index].position
            let b = mesh.vertices[index + 1].position
            let c = mesh.vertices[index + 2].position
            return total + abs(Double((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x))) / 2
        }
    }

    private func rotate(_ p: SIMD2<Double>, quarterTurns: Int) -> SIMD2<Double> {
        switch quarterTurns {
        case 1: [-p.y, p.x]
        case 2: [-p.x, -p.y]
        case 3: [p.y, -p.x]
        default: p
        }
    }

    private func coverage(_ mesh: InkMesh, at point: SIMD2<Float>) -> Int {
        stride(from: 0, to: mesh.vertices.count, by: 3).reduce(0) { total, index in
            let vertices: [SIMD2<Float>] = (0..<3).map { mesh.vertices[index + $0].position }
            let signs: [Float] = (0..<3).map { i in
                let a = vertices[i]
                let b = vertices[(i + 1) % 3]
                return (b.x - a.x) * (point.y - a.y) - (b.y - a.y) * (point.x - a.x)
            }
            let inside = signs.allSatisfy { $0 > 1e-5 } || signs.allSatisfy { $0 < -1e-5 }
            return total + (inside ? 1 : 0)
        }
    }
}
