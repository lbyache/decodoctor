import Foundation

/// Índice en memoria del diccionario: preselecciona por trigramas y puntúa con Jaro-Winkler por
/// ventana de palabras. Tolera los errores que FTS5 no tolera (ADR 0003).
public struct MedicationIndex: Sendable {
    /// Puntaje mínimo para considerar que un renglón menciona un medicamento.
    public static let candidateThreshold = 0.84
    /// Máximo de nombres que pasan la preselección por trigramas.
    static let prefilterLimit = 250

    private struct Entry: Sendable {
        let medication: Medication
        let name: String
        let words: [String]
    }

    private let entries: [Entry]
    private let trigramIndex: [String: [Int]]
    private let medicationsByID: [String: Medication]

    public init(medications: [Medication]) {
        var entries: [Entry] = []
        var trigramIndex: [String: [Int]] = [:]
        for medication in medications {
            for name in medication.searchableNames {
                let words = TextNormalizer.nameWords(name)
                guard !words.isEmpty else { continue }
                let position = entries.count
                entries.append(Entry(medication: medication, name: name, words: words))
                for trigram in Self.trigrams(of: words.joined(separator: " ")) {
                    trigramIndex[trigram, default: []].append(position)
                }
            }
        }
        self.entries = entries
        self.trigramIndex = trigramIndex
        self.medicationsByID = Dictionary(medications.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public var count: Int { medicationsByID.count }

    public func medication(id: String) -> Medication? { medicationsByID[id] }

    /// Vocabulario para el OCR: todas las palabras de nombres genéricos y marcas.
    public var vocabulary: [String] {
        Array(Set(entries.flatMap { $0.name.split(separator: " ").map(String.init) })).sorted()
    }

    /// Candidatos para un renglón, considerando todas sus lecturas OCR. Mejor puntaje primero,
    /// uno por medicamento, solo los que superan `minimumScore`.
    public func candidates(for line: RecognizedLine, limit: Int = 5, minimumScore: Double = candidateThreshold) -> [MedicationCandidate] {
        var best: [String: MedicationCandidate] = [:]
        for (rank, reading) in line.candidates.enumerated() {
            // Las lecturas alternativas del OCR valen un poco menos que la principal.
            let rankPenalty = Double(rank) * 0.01
            for candidate in candidates(forText: reading.text) {
                let adjusted = MedicationCandidate(medication: candidate.medication, score: candidate.score - rankPenalty, matchedName: candidate.matchedName)
                if adjusted.score > (best[adjusted.medication.id]?.score ?? -1) {
                    best[adjusted.medication.id] = adjusted
                }
            }
        }
        return best.values
            .filter { $0.score >= minimumScore }
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.medication.id < $1.medication.id }
            .prefix(limit)
            .map { $0 }
    }

    /// Búsqueda manual (el empleado escribe un nombre): misma lógica, umbral más bajo.
    public func search(_ query: String, limit: Int = 10) -> [Medication] {
        candidates(for: RecognizedLine(candidates: [TextCandidate(text: query, confidence: 1)]), limit: limit, minimumScore: 0.7)
            .map(\.medication)
    }

    private func candidates(forText text: String) -> [MedicationCandidate] {
        let lineWords = TextNormalizer.nameWords(text)
        guard !lineWords.isEmpty else { return [] }

        var results: [MedicationCandidate] = []
        for words in TextNormalizer.variants(of: lineWords) {
            for position in prefilter(words) {
                let entry = entries[position]
                let score = Self.score(lineWords: words, nameWords: entry.words)
                results.append(MedicationCandidate(medication: entry.medication, score: score, matchedName: entry.name))
            }
        }
        return results
    }

    /// Nombres que comparten más trigramas con el renglón.
    private func prefilter(_ words: [String]) -> [Int] {
        var shared: [Int: Int] = [:]
        for trigram in Self.trigrams(of: words.joined(separator: " ")) {
            for position in trigramIndex[trigram] ?? [] { shared[position, default: 0] += 1 }
        }
        return shared
            .filter { $0.value >= 2 }
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(Self.prefilterLimit)
            .map(\.key)
    }

    /// Mejor similitud entre el nombre y cualquier ventana de palabras consecutivas del renglón del
    /// mismo largo, ajustada por cobertura: un nombre que explica más palabras del renglón gana
    /// (así "amoxicilina ac clavulanico" prefiere la asociación a "amoxicilina" sola).
    static func score(lineWords: [String], nameWords: [String]) -> Double {
        let size = min(nameWords.count, lineWords.count)
        let name = nameWords.joined(separator: " ")
        var best = 0.0
        for start in 0...(lineWords.count - size) {
            let windowWords = Array(lineWords[start..<(start + size)])
            let window = windowWords.joined(separator: " ")
            let ratio = Double(window.count) / Double(name.count)
            guard window.count >= 4, ratio >= 0.6, ratio <= 1.6 else { continue }
            let similarity = size == nameWords.count && size > 1
                ? wordByWordSimilarity(windowWords, nameWords)
                : JaroWinkler.similarity(window, name)
            best = max(best, similarity)
        }
        let coverage = Double(size) / Double(lineWords.count)
        let nameCoverage = Double(size) / Double(nameWords.count)
        return best * (0.9 + 0.05 * coverage + 0.05 * nameCoverage)
    }

    /// Nombres de varias palabras, palabra por palabra y ponderado por largo. Acepta abreviaturas
    /// por prefijo ("ac." por "ácido"), habituales en recetas; solo aquí, nunca en nombres de una
    /// palabra, para que "ibu" o "pa" sueltos no sugieran nada.
    private static func wordByWordSimilarity(_ lineWords: [String], _ nameWords: [String]) -> Double {
        var weighted = 0.0, total = 0.0
        for (word, nameWord) in zip(lineWords, nameWords) {
            let isAbbreviation = word.count >= 2 && word.count < nameWord.count && nameWord.hasPrefix(word)
            let similarity = max(JaroWinkler.similarity(word, nameWord), isAbbreviation ? 0.92 : 0)
            weighted += similarity * Double(nameWord.count)
            total += Double(nameWord.count)
        }
        return weighted / total
    }

    static func trigrams(of text: String) -> Set<String> {
        let padded = Array("  \(text) ")
        guard padded.count >= 3 else { return [] }
        return Set((0...(padded.count - 3)).map { String(padded[$0..<($0 + 3)]) })
    }
}
