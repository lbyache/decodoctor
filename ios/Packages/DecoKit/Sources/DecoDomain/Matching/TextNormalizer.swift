import Foundation

/// Normaliza texto de recetas para compararlo con el diccionario.
public enum TextNormalizer {
    /// Minúsculas, sin acentos, solo letras/dígitos y los signos que usa la posología (`/ , . %`).
    public static func fold(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es"))
        let allowed = folded.map { char -> Character in
            char.isLetter || char.isNumber || "/,.%°".contains(char) ? char : " "
        }
        return String(allowed).split(separator: " ").joined(separator: " ")
    }

    /// Palabras que pueden ser parte de un nombre de medicamento: se descartan números, unidades
    /// y palabras de posología. Corrige confusiones típicas de OCR dentro de palabras (0→o, 1→l, 5→s).
    public static func nameWords(_ text: String) -> [String] {
        fold(text)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .compactMap(fixOCRConfusions)
            .filter { $0.count >= 2 && !stopwords.contains($0) }
    }

    /// Clave estable de un renglón para recordar correcciones: sus palabras de nombre, unidas.
    public static func correctionKey(_ text: String) -> String {
        nameWords(text).joined(separator: " ")
    }

    /// Variantes para comparar: la palabra tal cual y con "rn" → "m" (confusión clásica de OCR).
    static func variants(of words: [String]) -> [[String]] {
        let joined = words.joined(separator: " ")
        guard joined.contains("rn") else { return [words] }
        return [words, words.map { $0.replacingOccurrences(of: "rn", with: "m") }]
    }

    /// Devuelve la palabra con los dígitos confundidos reemplazados, o `nil` si es un número.
    private static func fixOCRConfusions(_ word: String) -> String? {
        let letters = word.filter(\.isLetter).count
        guard letters > 0 else { return nil }
        // Un token como "500mg" o "8hs" es posología, no nombre.
        if word.first?.isNumber == true, letters <= 3 { return nil }
        guard letters * 2 > word.count else { return nil }
        let map: [Character: Character] = ["0": "o", "1": "l", "5": "s", "4": "a"]
        return String(word.map { map[$0] ?? $0 }).filter(\.isLetter)
    }

    /// Palabras frecuentes en recetas que nunca son parte de un nombre de medicamento.
    static let stopwords: Set<String> = [
        "a", "al", "c", "cada", "con", "de", "del", "el", "en", "la", "las", "los", "por", "y", "x", "o",
        "mg", "mcg", "ug", "g", "gr", "ml", "ui", "u", "cc",
        "h", "hs", "hrs", "hora", "horas", "dia", "dias", "d", "semana", "semanas", "mes", "meses",
        "manana", "tarde", "noche", "mediodia", "ayunas", "desayuno", "almuerzo", "cena",
        "comp", "cp", "comprimido", "comprimidos", "caps", "capsula", "capsulas", "gota", "gotas", "gts",
        "amp", "ampolla", "ampollas", "sobre", "sobres", "cucharada", "cucharadas", "cda", "cdas",
        "puff", "puffs", "disparo", "disparos", "jarabe", "susp", "suspension", "crema", "gel",
        "tomar", "aplicar", "via", "oral", "vo", "im", "ev", "sl", "sublingual", "veces", "vez",
        "durante", "hasta", "segun", "necesidad", "sos", "n", "nro", "no", "uno", "una", "medio", "media",
        "rp", "rx", "tto", "tratamiento", "liberacion", "prolongada",
    ]
}
