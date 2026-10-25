import DecoDomain
import SwiftUI

struct ReviewView: View {
    @Bindable var model: ReviewViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.keepImages) private var keepImages = false
    @State private var searchingLine: PrescriptionLine?

    var body: some View {
        NavigationStack {
            Group {
                if let record = model.savedRecord {
                    SavedSummary(record: record) { dismiss() }
                } else {
                    form
                }
            }
            .navigationTitle("Revisar lectura")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .sheet(item: $searchingLine) { line in
                MedicationSearchView(initialQuery: line.recognized.bestText, search: model.search) { medication in
                    model.choose(.medication(medication), for: line)
                }
            }
        }
        .interactiveDismissDisabled(model.savedRecord == nil && model.undecidedCount < model.lines.count)
    }

    private var form: some View {
        ScrollViewReader { proxy in
            List {
                Section {
                    PrescriptionImage(data: model.reading.imageData, highlights: model.lines.compactMap { line in
                        line.recognized.box.map { ($0, line.confidence?.tint ?? .red, line.id == model.selectedLineID) }
                    })
                    .listRowInsets(EdgeInsets())
                    Label(model.reading.interpretedBy == .onDeviceModel
                          ? "Sugerencias ordenadas con Apple Intelligence"
                          : "Sugerencias solo por diccionario",
                          systemImage: model.reading.interpretedBy == .onDeviceModel ? "sparkles" : "text.book.closed")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if model.highConfidencePendingCount > 0 {
                    Button("Aceptar \(model.highConfidencePendingCount) sugerencia(s) de confianza alta", systemImage: "checkmark.circle") {
                        model.acceptHighConfidenceSuggestions()
                    }
                }

                ForEach(Array(model.lines.enumerated()), id: \.element.id) { position, line in
                    Section("Renglón \(position + 1)") {
                        LineReview(line: line, choice: model.choice(for: line), dosage: dosageBinding(for: line),
                                   onChoose: { model.choose($0, for: line) },
                                   onSearch: { searchingLine = line })
                    }
                    .id(line.id)
                }

                if !model.reading.otherLines.isEmpty {
                    Section {
                        DisclosureGroup("Otro texto leído (\(model.reading.otherLines.count))") {
                            ForEach(Array(model.reading.otherLines.enumerated()), id: \.offset) { _, line in
                                Text(line.bestText).font(.callout).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section {
                    Toggle("Guardar la foto en el historial", isOn: $keepImages)
                    if let error = model.errorMessage {
                        Text(error).foregroundStyle(.red)
                    }
                    Button {
                        Task { await model.save(keepImage: keepImages) }
                    } label: {
                        Text(model.undecidedCount == 0 ? "Guardar lectura" : "Faltan \(model.undecidedCount) renglón(es) por decidir")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.canSave)
                } footer: {
                    DisclaimerBanner().padding(.top, 8)
                }
            }
            .onChange(of: model.selectedLineID) { _, id in
                guard let id else { return }
                withAnimation { proxy.scrollTo(id, anchor: .top) }
            }
        }
    }

    private func dosageBinding(for line: PrescriptionLine) -> Binding<Dosage> {
        Binding(get: { model.dosages[line.id] ?? line.dosage }, set: { model.dosages[line.id] = $0 })
    }
}

private struct LineReview: View {
    let line: PrescriptionLine
    let choice: ReviewViewModel.Choice
    @Binding var dosage: Dosage
    let onChoose: (ReviewViewModel.Choice) -> Void
    let onSearch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("«\(line.recognized.bestText)»")
                    .font(.headline)
                    .accessibilityLabel("Texto leído: \(line.recognized.bestText)")
                Spacer()
                ConfidenceBadge(confidence: line.confidence)
            }
            if line.recognized.candidates.count > 1 {
                Text("Otras lecturas: " + line.recognized.candidates.dropFirst().prefix(3).map(\.text).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if line.confidence == .low {
                Label("Lectura dudosa: si no estás seguro, derivala al farmacéutico.", systemImage: "hand.raised")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }

        ForEach(line.candidates, id: \.medication.id) { candidate in
            Button { onChoose(.medication(candidate.medication)) } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(candidate.medication.generic).font(.body.weight(.medium))
                        if candidate.matchedName != candidate.medication.generic {
                            Text("Leído como marca: \(candidate.matchedName)").font(.caption).foregroundStyle(.secondary)
                        } else if !candidate.medication.brands.isEmpty {
                            Text(candidate.medication.brands.prefix(3).joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                        }
                        if candidate.isLearned {
                            Label("Ya confirmado antes en este teléfono", systemImage: "brain").font(.caption2).foregroundStyle(.tint)
                        }
                    }
                    Spacer()
                    Text(candidate.score, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Image(systemName: isChosen(candidate.medication) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isChosen(candidate.medication) ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isChosen(candidate.medication) ? .isSelected : [])
        }

        if case let .medication(medication) = choice, !line.candidates.contains(where: { $0.medication == medication }) {
            Label("Elegido a mano: \(medication.generic)", systemImage: "checkmark.circle.fill").foregroundStyle(.tint)
        }

        Button("Buscar otro medicamento", systemImage: "magnifyingglass", action: onSearch)
        // Cada opción en su propia fila: dos botones en una misma fila de List se disparan juntos.
        optionRow("No es un medicamento", systemImage: "text.badge.xmark", choice: .notAMedication, tint: .secondary)
        optionRow("Derivar al farmacéutico", systemImage: "person.badge.clock", choice: .referToPharmacist, tint: .orange)

        DosageEditor(dosage: $dosage)
    }

    private func optionRow(_ title: String, systemImage: String, choice option: ReviewViewModel.Choice, tint: Color) -> some View {
        Button { onChoose(option) } label: {
            HStack {
                Label(title, systemImage: systemImage).foregroundStyle(choice == option ? tint : .primary)
                Spacer()
                Image(systemName: choice == option ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(choice == option ? AnyShapeStyle(tint) : AnyShapeStyle(.tertiary))
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(choice == option ? .isSelected : [])
    }

    private func isChosen(_ medication: Medication) -> Bool { choice == .medication(medication) }
}

private struct DosageEditor: View {
    @Binding var dosage: Dosage

    var body: some View {
        DisclosureGroup {
            TextField("Concentración (ej. 500 mg)", text: optional(\.strength))
            TextField("Dosis (ej. 1 comprimido)", text: optional(\.dose))
            numberField("Cada cuántas horas", \.everyHours)
            numberField("Días de tratamiento", \.days)
            numberField("Cajas", \.boxes)
        } label: {
            VStack(alignment: .leading) {
                Text("Posología").font(.subheadline)
                Text(dosage.isEmpty ? "No se detectó: completala si hace falta" : dosage.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func optional(_ keyPath: WritableKeyPath<Dosage, String?>) -> Binding<String> {
        Binding(get: { dosage[keyPath: keyPath] ?? "" },
                set: { dosage[keyPath: keyPath] = $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 })
    }

    private func numberField(_ title: String, _ keyPath: WritableKeyPath<Dosage, Int?>) -> some View {
        LabeledContent(title) {
            TextField(title, value: Binding(get: { dosage[keyPath: keyPath] }, set: { dosage[keyPath: keyPath] = $0 }), format: .number)
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
        }
    }
}

private struct SavedSummary: View {
    let record: PrescriptionRecord
    let onDone: () -> Void

    var body: some View {
        List {
            Section {
                Label(record.status == .confirmed ? "Lectura guardada" : "Guardada con renglones para el farmacéutico",
                      systemImage: record.status == .confirmed ? "checkmark.seal.fill" : "person.badge.clock")
                    .font(.headline)
                    .foregroundStyle(record.status == .confirmed ? .green : .orange)
            }
            RecordItemsSection(record: record)
            Section {
                Button("Listo", action: onDone).frame(maxWidth: .infinity)
            }
        }
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    let reading = PrescriptionReading(createdAt: .now, imageData: Data(), medicationLines: [
        PrescriptionLine(recognized: RecognizedLine(candidates: [TextCandidate(text: "Amoxicilna 500", confidence: 0.4)]),
                         candidates: [MedicationCandidate(medication: Medication(id: "amoxicilina", generic: "Amoxicilina", brands: ["Amoxidal"]), score: 0.96, matchedName: "Amoxicilina")],
                         dosage: Dosage(strength: "500 mg", dose: "1 comprimido", everyHours: 8, days: 7), confidence: .high),
    ], otherLines: [], interpretedBy: .matchingOnly)
    ReviewView(model: ReviewViewModel(reading: reading, confirmReading: dependencies.confirmReading, searchMedications: dependencies.searchMedications))
}
