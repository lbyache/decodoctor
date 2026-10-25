import Foundation

/// Lee concentración, dosis, frecuencia, duración y cantidad de cajas de un renglón de receta,
/// con las abreviaturas habituales en Argentina ("1 comp c/8 hs x 7 días", "N° 2").
public enum DosageParser {
    public static func parse(_ text: String) -> Dosage {
        // El OCR suele leer un "1" manuscrito como "l" o "i" delante de la unidad.
        let folded = TextNormalizer.fold(text).replacing(
            try! Regex(#"(^|\s)[li](?=\s*(?:comp|cp|caps|capsula|gota|gts|amp|puff|disparo|sobre|cucharada|cda))"#),
            with: { match in (match.output[1].substring ?? "") + "1" }
        )
        return Dosage(
            strength: strength(in: folded),
            dose: dose(in: folded),
            everyHours: everyHours(in: folded),
            days: firstInt(#"(?:x|por|durante)\s*(\d{1,3})\s*(?:d|dias?)(?![a-z])"#, in: folded),
            boxes: firstInt(#"(?:^|\s)(?:n°|no|nro\.?|n\.)\s*(\d{1,2})(?![0-9])"#, in: folded)
        )
    }

    private static func strength(in text: String) -> String? {
        guard let match = captures(#"(?:^|[^0-9/])(\d+(?:[.,]\d+)*)\s*(mg|mcg|g|ml|ui|%)(?![a-z])"#, in: text) else { return nil }
        let unit = match[1] == "ui" ? "UI" : match[1]
        return "\(match[0]) \(unit)"
    }

    private static func dose(in text: String) -> String? {
        let pattern = #"(?:^|\s)(\d+/\d+|\d+(?:[.,]\d+)?|una?|medio|media)\s*(comprimidos?|comp|cp|caps|capsulas?|gotas?|gts|ampollas?|amp|puffs?|disparos?|sobres?|cucharadas?|cdas?)(?![a-z])"#
        guard let match = captures(pattern, in: text) else { return nil }
        let amount: String = switch match[0] {
        case "un", "una": "1"
        case "medio", "media": "1/2"
        default: match[0]
        }
        let isSingular = amount == "1" || amount.contains("/")
        let unit: (singular: String, plural: String) = switch match[1] {
        case let u where u.hasPrefix("comp") || u == "cp": ("comprimido", "comprimidos")
        case let u where u.hasPrefix("cap"): ("cápsula", "cápsulas")
        case let u where u.hasPrefix("got") || u == "gts": ("gota", "gotas")
        case let u where u.hasPrefix("amp"): ("ampolla", "ampollas")
        case let u where u.hasPrefix("puff"): ("puff", "puff")
        case let u where u.hasPrefix("disp"): ("disparo", "disparos")
        case let u where u.hasPrefix("sobre"): ("sobre", "sobres")
        default: ("cucharada", "cucharadas")
        }
        return "\(amount) \(isSingular ? unit.singular : unit.plural)"
    }

    private static func everyHours(in text: String) -> Int? {
        if let times = firstInt(#"(\d)\s*(?:veces|v)\s*(?:al|por|x|/)\s*dia(?!s)"#, in: text), times > 0 {
            return 24 / times
        }
        if let hours = firstInt(#"(?:c/|cada)\s*(\d{1,2})\s*(?:-?\s*\d{1,2}\s*)?(?:h|hs|hrs|horas?)(?![a-z])"#, in: text) {
            return hours
        }
        if text.contains(regex: #"(?:al|por|x|/)\s*dia(?!s)"#) { return 24 }
        return nil
    }

    private static func firstInt(_ pattern: String, in text: String) -> Int? {
        captures(pattern, in: text).flatMap { Int($0[0]) }
    }

    /// Grupos de captura de la primera coincidencia.
    private static func captures(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? Regex(pattern), let match = text.firstMatch(of: regex) else { return nil }
        return (1..<match.output.count).map { match.output[$0].substring.map(String.init) ?? "" }
    }
}

private extension String {
    func contains(regex pattern: String) -> Bool {
        guard let regex = try? Regex(pattern) else { return false }
        return firstMatch(of: regex) != nil
    }
}
