enum NightSkySeeds {
    static let pools: UInt64 = 0x736B79500001
    static let clouds: UInt64 = 0x736B79430002
    static let stars: UInt64 = 0x736B79530003
    static let starInk: UInt64 = 0x736B79530004
    static let moonSlots: UInt64 = 0x736B794D0005
    static let moonLayout: UInt64 = 0x736B794D0006
    static let moonInk: UInt64 = 0x736B794D0007
    static let scene: UInt64 = 0x736B79000008

    static func mix(_ input: UInt64) -> UInt64 {
        var value = input
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    static func component(world: UInt64, index: Int64, tag: UInt64) -> UInt64 {
        mix(world ^ mix(UInt64(bitPattern: index)) ^ tag)
    }
}
