enum MondrianWorldCellKind: Int, Hashable, Sendable { case bridge, residual }

struct MondrianWorldCellID: Hashable, Comparable, Sendable {
    let owner: Int64
    let kind: MondrianWorldCellKind
    let root: UInt8
    let path: UInt32

    // Kind, root and path occupy disjoint fields; owner has a separate paint seed.
    var paintID: UInt64 {
        UInt64(kind.rawValue) << 56 | UInt64(root) << 48 | UInt64(path)
    }

    static func < (a: Self, b: Self) -> Bool {
        if a.owner != b.owner { return a.owner < b.owner }
        if a.kind != b.kind { return a.kind.rawValue < b.kind.rawValue }
        if a.root != b.root { return a.root < b.root }
        return a.path < b.path
    }
}

struct MondrianWorldLeaf: Sendable {
    let id: MondrianWorldCellID
    let rect: MondrianRect
}

struct MondrianWorldCell: Sendable {
    let id: MondrianWorldCellID
    let rect: MondrianRect
    let color: MondrianColor
}
