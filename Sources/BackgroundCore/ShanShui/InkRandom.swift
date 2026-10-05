/// SplitMix64 sequence shared by the ink generators. Upper 53 bits map to [0, 1).
/// This is an illustration RNG, not a cryptographic random generator.
struct InkRandom {
    var state: UInt64

    mutating func unit() -> Double {
        state &+= 0x9E3779B97F4A7C15
        var value: UInt64 = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        value ^= value >> 31
        return Double(value >> 11) * 0x1.0p-53
    }
}
