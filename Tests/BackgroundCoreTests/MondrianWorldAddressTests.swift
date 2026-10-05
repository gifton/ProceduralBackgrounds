@testable import BackgroundCore
import Testing

struct MondrianWorldAddressTests {
    @Test(arguments: [Int64.min, .min + 1, -3, -2, -1, 0, 1, 2, 3, .max - 1, .max])
    func euclideanChunkOriginsStayLocal(index: Int64) throws {
        let address = MondrianWorldAddress(chunk: index)
        #expect(address.offset == (index.isMultiple(of: 2) ? 0 : 1200))
        let doubled = address.owner.multipliedReportingOverflow(by: 2)
        let rebuilt = doubled.partialValue.addingReportingOverflow(Int64(address.offset / 1200))
        #expect(!doubled.overflow && !rebuilt.overflow && rebuilt.partialValue == index)
        for delta: Int64 in -2...2 {
            let neighbor = address.owner.addingReportingOverflow(delta)
            #expect(!neighbor.overflow)
            let point = try MondrianWorldAddress(owner: neighbor.partialValue, offset: 880)
            #expect(try point.relativeX(to: address.owner) == Int(delta) * 2400 + 880)
        }
    }

    @Test func equivalentAddressesNormalizeAndArithmeticFailuresAreReported() throws {
        #expect(try MondrianWorldAddress(owner: 7, offset: -1)
            == MondrianWorldAddress(owner: 6, offset: 2399))
        #expect(try MondrianWorldAddress(owner: -7, offset: 2401)
            == MondrianWorldAddress(owner: -6, offset: 1))
        #expect(try MondrianWorldAddress(owner: -1, offset: 2399)
            < MondrianWorldAddress(owner: 0, offset: 0))
        #expect(throws: MondrianWorldError.indexOverflow) {
            try MondrianWorldAddress(owner: .max, offset: 2400)
        }
        #expect(throws: MondrianWorldError.indexOverflow) {
            try MondrianWorldAddress(owner: .min, offset: -1)
        }
        let distant = try MondrianWorldAddress(owner: .max, offset: 0)
        #expect(throws: MondrianWorldError.indexOverflow) { try distant.relativeX(to: .min) }
        #expect(throws: MondrianWorldError.invalidNeighborhood) { try distant.relativeX(to: 0) }
        let normalized = try [Int.min, Int.max].map { try MondrianWorldAddress(owner: 0, offset: $0) }
        #expect(normalized.allSatisfy { (0..<2400).contains($0.offset) })
    }

    @Test func structuralCellIDsSeparateOwnersKindsRootsAndPaths() {
        var ids: [MondrianWorldCellID] = []
        for owner: Int64 in [-1, 0, 1] {
            var paintIDs: Set<UInt64> = []
            for kind in [MondrianWorldCellKind.bridge, .residual] {
                for root: UInt8 in 0..<5 {
                    for path: UInt32 in 1...64 {
                        let id = MondrianWorldCellID(owner: owner, kind: kind, root: root, path: path)
                        #expect(paintIDs.insert(id.paintID).inserted)
                        ids.append(id)
                    }
                }
            }
        }
        #expect(Set(ids).count == ids.count)
        #expect(ids.sorted() == ids)
        #expect(ids.reversed().sorted() == ids)
    }

    @Test(arguments: [UInt64(0), 42, .max])
    func componentStreamsSeparateOwnersAndPurposes(seed: UInt64) {
        let tags = [MondrianWorldSeeds.boundary, MondrianWorldSeeds.layout,
                    MondrianWorldSeeds.color, MondrianWorldSeeds.paint, MondrianWorldSeeds.divider]
        for owner: Int64 in [-1, 0, 1] {
            let streams = tags.map { MondrianWorldSeeds.owner(seed: seed, owner: owner, tag: $0) }
            #expect(Set(streams).count == tags.count)
        }
        for tag in tags {
            let streams = [Int64(-1), 0, 1].map { MondrianWorldSeeds.owner(seed: seed, owner: $0, tag: tag) }
            #expect(Set(streams).count == 3)
        }
    }
}
