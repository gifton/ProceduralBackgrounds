enum MondrianWorldError: Error, Equatable {
    case indexOverflow
    case invalidNeighborhood
}

/// Integral 2400-unit addresses avoid forming an absolute floating-point world x.
/// euclideanChunkOriginsStayLocal tests negative odd chunks and signed extrema.
struct MondrianWorldAddress: Hashable, Comparable, Sendable {
    let owner: Int64
    let offset: Int

    init(chunk index: Int64) {
        let quotient: Int64 = index / 2
        let remainder: Int64 = index % 2
        // q is in the half-sized Int64 range, leaving room for this decrement.
        owner = remainder < 0 ? quotient - 1 : quotient
        offset = remainder == 0 ? 0 : 1200
    }

    init(owner: Int64, offset: Int) throws {
        var carry: Int = offset / 2400
        var local: Int = offset % 2400
        // Dividing first leaves room for one decrement even for Int.min.
        if local < 0 { carry -= 1; local += 2400 }
        let normalized = owner.addingReportingOverflow(Int64(carry))
        guard !normalized.overflow else { throw MondrianWorldError.indexOverflow }
        self.owner = normalized.partialValue
        self.offset = local
    }

    /// Caller contract: the point is within eight composition owners of anchor.
    /// equivalentAddressesNormalizeAndArithmeticFailuresAreReported tests rejection.
    func relativeX(to anchor: Int64) throws -> Int {
        let difference = owner.subtractingReportingOverflow(anchor)
        guard !difference.overflow else { throw MondrianWorldError.indexOverflow }
        guard (-8...8).contains(difference.partialValue) else {
            throw MondrianWorldError.invalidNeighborhood
        }
        return Int(difference.partialValue) * 2400 + offset
    }

    static func < (a: Self, b: Self) -> Bool {
        a.owner == b.owner ? a.offset < b.offset : a.owner < b.owner
    }
}
