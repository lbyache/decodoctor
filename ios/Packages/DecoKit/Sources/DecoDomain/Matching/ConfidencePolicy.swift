/// Traduce puntajes en un nivel de confianza que el empleado entiende de un vistazo.
public enum ConfidencePolicy {
    public static let highThreshold = 0.93
    public static let mediumThreshold = 0.89
    /// Si los dos mejores candidatos están más cerca que esto, la lectura es ambigua.
    public static let ambiguityMargin = 0.03

    /// - Parameter chosenByModel: el modelo eligió un candidato que no era el de mayor puntaje.
    ///   Se acepta su elección, pero la confianza no puede ser alta.
    /// - Parameter modelRejected: el modelo dijo que el renglón no es un medicamento.
    public static func confidence(for candidates: [MedicationCandidate], chosenByModel: Bool = false, modelRejected: Bool = false) -> Confidence? {
        guard let top = candidates.first else { return nil }
        var level: Confidence = top.score >= highThreshold ? .high : top.score >= mediumThreshold ? .medium : .low
        if let runnerUp = candidates.dropFirst().first, top.score - runnerUp.score < ambiguityMargin {
            level = level.lowered
        }
        if chosenByModel { level = min(level, .medium) }
        if modelRejected { level = level.lowered }
        return level
    }
}

extension Confidence {
    var lowered: Confidence {
        switch self {
        case .high: .medium
        case .medium, .low: .low
        }
    }
}
