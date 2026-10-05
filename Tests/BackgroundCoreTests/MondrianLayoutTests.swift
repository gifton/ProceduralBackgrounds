@testable import BackgroundCore
import Testing

struct MondrianLayoutTests {
    @Test(arguments: Array(UInt64(0)...UInt64(127)) + [.max - 1, .max])
    func layoutsCoverTheWorldWithBoundedCells(seed: UInt64) {
        let cells = MondrianLayout(seed: seed).cells
        #expect((10...24).contains(cells.count))
        #expect(Set(cells.map(\.id)).count == cells.count)
        #expect(cells.reduce(0) { $0 + $1.rect.area } == 1200 * 800)
        #expect(Set(cells.map(\.color)) == Set(MondrianColor.allCases))
        for cell in cells {
            #expect(cell.rect.width >= 80 && cell.rect.height >= 80)
            #expect(cell.rect.min.x >= 0 && cell.rect.max.x <= 1200)
            #expect(cell.rect.min.y >= 0 && cell.rect.max.y <= 800)
        }
        for i in cells.indices {
            for j in cells.indices where j > i {
                let a = cells[i].rect, b = cells[j].rect
                let dx: Int = min(a.max.x, b.max.x) - max(a.min.x, b.min.x)
                let dy: Int = min(a.max.y, b.max.y) - max(a.min.y, b.min.y)
                #expect(dx <= 0 || dy <= 0)
            }
        }
        let largestPrimary: Int = cells.filter {
            [.red, .blue, .yellow].contains($0.color)
        }.map { $0.rect.area }.max() ?? 0
        #expect(cells.filter { $0.color == .black }.allSatisfy {
            $0.rect.area < largestPrimary
        })
        _ = MondrianLayout(seed: seed &+ 1)
        let repeated = MondrianLayout(seed: seed).cells
        #expect(repeated.count == cells.count)
        for (a, b) in zip(cells, repeated) {
            #expect(a.id == b.id && a.color == b.color)
            #expect(a.rect.min == b.rect.min && a.rect.max == b.rect.max)
        }
    }

    @Test func seedSampleHasVariedLayoutsAndReportsAreaBalance() {
        var descriptions: Set<String> = []
        var areas: [MondrianColor: Int] = [:]
        for seed: UInt64 in 0..<32 {
            let cells = MondrianLayout(seed: seed).cells
            descriptions.insert(cells.map {
                "\($0.rect.min.x),\($0.rect.min.y),\($0.rect.max.x),\($0.rect.max.y)"
            }.joined(separator: ";"))
            for cell in cells { areas[cell.color, default: 0] += cell.rect.area }
        }
        #expect(descriptions.count >= 8)
        let total: Double = Double(32 * 1200 * 800)
        let primary: Double = Double((areas[.red] ?? 0) + (areas[.blue] ?? 0) + (areas[.yellow] ?? 0)) / total
        print("Mondrian 32-seed area balance: primary \(primary), white \(Double(areas[.white] ?? 0) / total), black \(Double(areas[.black] ?? 0) / total)")
    }
}
