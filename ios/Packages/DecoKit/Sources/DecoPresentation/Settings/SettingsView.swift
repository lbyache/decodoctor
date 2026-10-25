import DecoDomain
import LocalAuthentication
import SwiftUI

public struct SettingsView: View {
    let dependencies: AppDependencies
    @AppStorage(SettingsKey.retentionDays) private var retentionDays = PurgeExpiredHistory.defaultRetentionDays
    @AppStorage(SettingsKey.keepImages) private var keepImages = false
    @AppStorage(SettingsKey.requireUnlock) private var requireUnlock = false
    @State private var interpreterNote: String?

    public init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Borrar lecturas a los \(retentionDays) días", value: $retentionDays, in: PurgeExpiredHistory.retentionRange)
                    Toggle("Guardar fotos de recetas", isOn: $keepImages)
                    Toggle("Pedir Face ID / código al abrir", isOn: $requireUnlock)
                        .disabled(!PrivacyLock.isAvailable)
                } header: {
                    Text("Privacidad")
                } footer: {
                    Text("Todo queda cifrado en este teléfono y nunca se envía a internet. Las fotos de recetas son datos de salud: guardalas solo si hace falta.")
                }

                Section("Reconocimiento") {
                    LabeledContent("Lectura de texto", value: "Vision (en el dispositivo)")
                    LabeledContent("Interpretación", value: interpreterNote == nil ? "Apple Intelligence" : "Solo diccionario")
                    if let interpreterNote {
                        Text(interpreterNote).font(.footnote).foregroundStyle(.secondary)
                    }
                    LabeledContent("Diccionario", value: dependencies.dictionaryDescription)
                }

                Section {
                    DisclaimerBanner()
                } footer: {
                    Text("DecoDoctor sugiere lecturas posibles a partir de un diccionario. No reemplaza el criterio del farmacéutico ni autoriza dispensas.")
                }
            }
            .navigationTitle("Ajustes")
            .task { interpreterNote = await dependencies.interpreterUnavailableReason() }
        }
    }
}
