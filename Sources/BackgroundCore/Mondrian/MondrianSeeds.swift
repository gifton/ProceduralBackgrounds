enum MondrianSeeds {
    static let layout: UInt64 = 0x4D4F4E440001
    static let color: UInt64 = 0x4D4F4E440002
    static let paint: UInt64 = 0x4D4F4E440003
    static let divider: UInt64 = 0x4D4F4E440004

    static func component(world: UInt64, identity: UInt64, tag: UInt64) -> UInt64 {
        var value: UInt64 = (world ^ tag) &+ (identity &* 0x9E3779B97F4A7C15)
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
