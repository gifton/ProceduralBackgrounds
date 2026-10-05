/// Independent illustration streams; no cryptographic or cross-version contract.
enum GardenWallSeeds {
    static let masonry: UInt64 = 0x6D61736F6E727901
    static let vegetation: UInt64 = 0x7665676574617402
    static let pots: UInt64 = 0x706F747300000003
    static let cats: UInt64 = 0x6361747300000004

    static func mix(_ input: UInt64) -> UInt64 {
        var value = input
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    static func component(world: UInt64, index: Int64, tag: UInt64) -> UInt64 {
        mix(world ^ mix(UInt64(bitPattern: index)) ^ tag)
    }

    static func cell(world: UInt64, id: GardenWallCellID) -> UInt64 {
        component(world: world, index: id.ownerIndex,
                  tag: masonry ^ mix(UInt64(id.row) &+ 0xCA11) ^ mix(UInt64(bitPattern: Int64(id.slot))))
    }
}
