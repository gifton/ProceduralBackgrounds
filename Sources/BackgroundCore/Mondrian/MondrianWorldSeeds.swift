enum MondrianWorldSeeds {
    static let boundary: UInt64 = 0x4D4F4E570001
    static let layout: UInt64 = 0x4D4F4E570002
    static let color: UInt64 = 0x4D4F4E570003
    static let paint: UInt64 = 0x4D4F4E570004
    static let divider: UInt64 = 0x4D4F4E570005

    static func owner(seed: UInt64, owner: Int64, tag: UInt64) -> UInt64 {
        MondrianSeeds.component(world: seed, identity: UInt64(bitPattern: owner), tag: tag)
    }

    /// Caller contract: canonical endpoints have integral y in 0...800.
    /// adjacentNeighborhoodsAgreeOnFullSegmentsAndSeeds checks world seed agreement.
    static func edge(seed: UInt64, id: MondrianWorldEdgeID) -> UInt64 {
        let fields: [UInt64] = [UInt64(id.axis.rawValue), UInt64(bitPattern: id.startX.owner),
            UInt64(id.startX.offset), UInt64(id.startY), UInt64(bitPattern: id.endX.owner),
            UInt64(id.endX.offset), UInt64(id.endY)]
        return fields.reduce(seed ^ divider) { value, field in
            MondrianSeeds.component(world: value, identity: field, tag: divider)
        }
    }
}
