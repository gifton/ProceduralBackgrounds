import BackgroundCore

/// Immutable for a view lifetime. Each product factory creates a fresh worker;
/// retainedDesignRestartsWithItsOwnFactory checks reconstruction after stop.
struct InkScrollSource: Sendable {
    let id: String
    let title: String
    let loadingText: String
    let surfaceColor: SIMD3<Double>
    let prefersDarkAppearance: Bool
    let makePreparer: @Sendable () -> any ShanShuiChunkPreparing

    init(id: String, title: String, loadingText: String,
         surfaceColor: SIMD3<Double> = SIMD3(repeating: 1),
         prefersDarkAppearance: Bool = false,
         makePreparer: @escaping @Sendable () -> any ShanShuiChunkPreparing) {
        self.id = id
        self.title = title
        self.loadingText = loadingText
        self.surfaceColor = surfaceColor
        self.prefersDarkAppearance = prefersDarkAppearance
        self.makePreparer = makePreparer
    }

    static var shanShui: InkScrollSource {
        .init(id: "shanShui", title: "Shan Shui", loadingText: "Preparing landscape…",
              makePreparer: { ShanShuiChunkBuilder() })
    }
    static var gardenWall: InkScrollSource {
        .init(id: "gardenWall", title: "Garden Wall", loadingText: "Preparing garden…", makePreparer: {
            ShanShuiChunkBuilder(makeChunk: { seed, index in
                let chunk = GardenWallChunkGenerator().generate(seed: seed, index: index)
                return ShanShuiPreparedChunk(chunk: chunk,
                                            mesh: try InkMeshCompiler().compile(chunk.scene, clippingToBounds: true))
            })
        })
    }

    static var nightSky: InkScrollSource {
        .init(id: "nightSky", title: "Night Sky", loadingText: "Preparing sky…",
              surfaceColor: NightSkyChunkGenerator.surfaceColor, prefersDarkAppearance: true,
              makePreparer: {
            ShanShuiChunkBuilder(makeChunk: { seed, index in
                let chunk = NightSkyChunkGenerator().generate(seed: seed, index: index)
                return ShanShuiPreparedChunk(chunk: chunk,
                                            mesh: try InkMeshCompiler().compile(chunk.scene, clippingToBounds: true))
            })
        })
    }

    static var mondrian: InkScrollSource {
        .init(id: "mondrian", title: "Mondrian scrolling", loadingText: "Preparing painting…",
              makePreparer: {
            ShanShuiChunkBuilder(makeChunk: { seed, index in
                let chunk = try MondrianChunkGenerator().generate(seed: seed, index: index)
                return ShanShuiPreparedChunk(chunk: chunk,
                    mesh: try InkMeshCompiler().compile(chunk.scene, clippingToBounds: true))
            })
        })
    }
}

struct InkScrollIdentity: Hashable {
    let source: String
    let seed: UInt64
}
