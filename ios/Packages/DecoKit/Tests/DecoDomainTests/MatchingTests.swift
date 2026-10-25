import Testing
@testable import DecoDomain

@Suite struct MatchingTests {
    @Test func jaroWinklerReferenceValues() {
        #expect(abs(JaroWinkler.similarity("martha", "marhta") - 0.961) < 0.001)
        #expect(JaroWinkler.similarity("abc", "abc") == 1)
        #expect(JaroWinkler.similarity("abc", "xyz") == 0)
    }

    @Test func normalizerDropsPosologyAndFixesOCRDigits() {
        #expect(TextNormalizer.nameWords("Omepraz0l 20 mg 1 comp c/24 hs") == ["omeprazol"])
        #expect(TextNormalizer.correctionKey("ÁCIDO Fólico 5mg") == "acido folico")
    }

    @Test func combinationBeatsSingleDrugWhenTheLineNamesBoth() {
        let candidates = Shared.index.candidates(for: line("Amoxicilina + ac. clavulanico 875/125"))
        #expect(candidates.first?.medication.id == "amoxicilina-acido-clavulanico")
    }

    @Test func singleDrugBeatsCombinationWhenTheLineNamesOne() {
        let candidates = Shared.index.candidates(for: line("Amoxicilina 500 mg"))
        #expect(candidates.first?.medication.id == "amoxicilina")
    }

    @Test func alternativeReadingsCountSlightlyLess() throws {
        let first = try #require(Shared.index.candidates(for: line("Enalapril 10")).first)
        let second = try #require(Shared.index.candidates(for: line("xxxx", "Enalapril 10")).first)
        #expect(second.score < first.score)
        #expect(second.medication.id == "enalapril")
    }

    /// Texto que no es un medicamento tiene que quedar con margen por debajo del umbral.
    @Test(arguments: ["Dr. Juan Pérez - Médico clínico", "Paciente: María Gómez", "Obra social OSDE 210",
                      "Dx: faringitis aguda", "Firma y sello", "Hospital de Clínicas", "Tomar con abundante agua"])
    func nonMedicationTextStaysBelowThreshold(_ text: String) {
        #expect(Shared.index.candidates(for: line(text)).isEmpty)
    }

    @Test func manualSearchToleratesTypos() {
        #expect(Shared.index.search("sertralin").first?.id == "sertralina")
        #expect(Shared.index.search("buscapin").first?.id == "butilescopolamina")
    }

    @Test func vocabularyIncludesGenericsAndBrands() {
        let vocabulary = Shared.index.vocabulary
        #expect(vocabulary.contains("Amoxicilina"))
        #expect(vocabulary.contains("Ibupirac"))
    }

    @Test func confidenceLevels() {
        let med = Medication(id: "a", generic: "A")
        let other = Medication(id: "b", generic: "B")
        func candidate(_ m: Medication, _ score: Double) -> MedicationCandidate {
            MedicationCandidate(medication: m, score: score, matchedName: m.generic)
        }
        #expect(ConfidencePolicy.confidence(for: [candidate(med, 0.97)]) == .high)
        #expect(ConfidencePolicy.confidence(for: [candidate(med, 0.90)]) == .medium)
        #expect(ConfidencePolicy.confidence(for: [candidate(med, 0.85)]) == .low)
        #expect(ConfidencePolicy.confidence(for: [candidate(med, 0.97), candidate(other, 0.96)]) == .medium)
        #expect(ConfidencePolicy.confidence(for: [candidate(med, 0.97)], chosenByModel: true) == .medium)
        #expect(ConfidencePolicy.confidence(for: []) == nil)
    }
}
