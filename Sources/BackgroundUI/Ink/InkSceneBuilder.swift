import BackgroundCore

struct InkPreparedScene: Sendable {
    let scene: InkScene
    let mesh: InkMesh
}

protocol InkScenePreparing: Sendable {
    func prepare<Generator: BackgroundGenerator>(seed: UInt64, using generator: Generator,
        clippingToBounds: Bool) async throws -> InkPreparedScene where Generator.Scene == InkScene
}

/// Actor-owned CPU preparation; realBuilderClipsOnlyWhenRequested exercises
/// the production compiler option used by the static host.
actor InkSceneBuilder: InkScenePreparing {
    func prepare<Generator: BackgroundGenerator>(seed: UInt64, using generator: Generator,
        clippingToBounds: Bool) throws -> InkPreparedScene where Generator.Scene == InkScene {
        try Task.checkCancellation()
        let scene = generator.generate(seed: seed)
        let mesh = try InkMeshCompiler().compile(scene, clippingToBounds: clippingToBounds)
        try Task.checkCancellation()
        return InkPreparedScene(scene: scene, mesh: mesh)
    }
}
