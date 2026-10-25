import DecoDomain
import SwiftUI

public struct HistoryView: View {
    @State private var model: HistoryViewModel
    @AppStorage(SettingsKey.retentionDays) private var retentionDays = PurgeExpiredHistory.defaultRetentionDays

    public init(dependencies: AppDependencies) {
        _model = State(initialValue: HistoryViewModel(listHistory: dependencies.listHistory, deleteRecord: dependencies.deleteRecord))
    }

    public var body: some View {
        NavigationStack {
            List {
                ForEach(model.records) { record in
                    NavigationLink(value: record) { HistoryRow(record: record) }
                }
                .onDelete { offsets in
                    let records = offsets.map { model.records[$0] }
                    Task { for record in records { await model.delete(record) } }
                }
            }
            .overlay {
                if model.records.isEmpty {
                    ContentUnavailableView("Sin lecturas guardadas", systemImage: "clock",
                                           description: Text("Las lecturas se borran solas a los \(retentionDays) días."))
                }
            }
            .navigationTitle("Historial")
            .navigationDestination(for: PrescriptionRecord.self) { RecordDetailView(record: $0) }
            .task { await model.load() }
            .refreshable { await model.load() }
            .safeAreaInset(edge: .bottom) {
                if let error = model.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(.red).padding()
                }
            }
        }
    }
}

private struct HistoryRow: View {
    let record: PrescriptionRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(record.createdAt, format: .dateTime.day().month().hour().minute())
                    .font(.subheadline.weight(.medium))
                Spacer()
                if record.status == .referredToPharmacist {
                    Label("Farmacéutico", systemImage: "person.badge.clock")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Text(record.items.isEmpty ? "Sin medicamentos confirmados" : record.items.map(\.medication.generic).joined(separator: ", "))
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}

struct RecordDetailView: View {
    let record: PrescriptionRecord

    var body: some View {
        List {
            if let imageData = record.imageData {
                Section { PrescriptionImage(data: imageData).listRowInsets(EdgeInsets()) }
            }
            RecordItemsSection(record: record)
        }
        .navigationTitle(record.createdAt.formatted(date: .abbreviated, time: .shortened))
    }
}

/// Medicamentos confirmados y renglones derivados de una receta guardada.
struct RecordItemsSection: View {
    let record: PrescriptionRecord

    var body: some View {
        if !record.items.isEmpty {
            Section("Confirmados") {
                ForEach(Array(record.items.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.medication.generic).font(.headline)
                        if !item.dosage.isEmpty { Text(item.dosage.summary).font(.callout) }
                        Text("Leído: «\(item.sourceText)»").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        if !record.referredTexts.isEmpty {
            Section("Para el farmacéutico") {
                ForEach(record.referredTexts, id: \.self) { Text("«\($0)»") }
            }
        }
    }
}

#Preview {
    HistoryView(dependencies: .preview())
}
