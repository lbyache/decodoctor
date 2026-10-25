/// Similitud de Jaro-Winkler (0…1). Premia los prefijos iguales, que en letra manuscrita suelen ser
/// la parte más legible de una palabra.
enum JaroWinkler {
    static func similarity(_ lhs: String, _ rhs: String) -> Double {
        let a = Array(lhs), b = Array(rhs)
        if a.isEmpty || b.isEmpty { return a.isEmpty && b.isEmpty ? 1 : 0 }
        if a == b { return 1 }

        let window = max(0, max(a.count, b.count) / 2 - 1)
        var aMatched = [Bool](repeating: false, count: a.count)
        var bMatched = [Bool](repeating: false, count: b.count)
        var matches = 0
        for i in a.indices {
            let start = max(0, i - window), end = min(b.count - 1, i + window)
            guard start <= end else { continue }
            for j in start...end where !bMatched[j] && a[i] == b[j] {
                aMatched[i] = true
                bMatched[j] = true
                matches += 1
                break
            }
        }
        guard matches > 0 else { return 0 }

        var transpositions = 0, k = 0
        for i in a.indices where aMatched[i] {
            while !bMatched[k] { k += 1 }
            if a[i] != b[k] { transpositions += 1 }
            k += 1
        }
        let m = Double(matches)
        let jaro = (m / Double(a.count) + m / Double(b.count) + (m - Double(transpositions) / 2) / m) / 3

        var prefix = 0
        while prefix < min(4, a.count, b.count), a[prefix] == b[prefix] { prefix += 1 }
        return jaro + Double(prefix) * 0.1 * (1 - jaro)
    }
}
