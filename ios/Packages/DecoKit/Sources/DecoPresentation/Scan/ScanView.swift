import DecoDomain
import PhotosUI
import SwiftUI

public struct ScanView: View {
    @State private var model: ScanViewModel
    @State private var photoItem: PhotosPickerItem?
    @State private var isScannerPresented = false

    public init(dependencies: AppDependencies) {
        _model = State(initialValue: ScanViewModel(dependencies: dependencies))
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    DisclaimerBanner()

                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)
                        .padding(.top, 24)
                        .accessibilityHidden(true)
                    Text("Sacale una foto a la receta: la app lee cada renglón y te sugiere el medicamento, con su nivel de confianza.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)

                    actions

                    status

                    if let note = model.interpreterNote {
                        Label("Sin Apple Intelligence: se usa solo el diccionario. \(note)", systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Label("La foto se procesa en este teléfono. Nada se envía a internet.", systemImage: "lock.iphone")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Leer receta")
            .task { await model.loadInterpreterStatus() }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    defer { photoItem = nil }
                    guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                    await model.read(imageData: Self.prepared(data))
                }
            }
            .sheet(item: $model.review) { review in
                ReviewView(model: review)
            }
            #if os(iOS)
            .fullScreenCover(isPresented: $isScannerPresented) {
                DocumentScanner(
                    onScan: { image in
                        isScannerPresented = false
                        guard let data = ImageNormalizer.normalizedJPEG(image) else { return }
                        Task { await model.read(imageData: data) }
                    },
                    onCancel: { isScannerPresented = false }
                )
                .ignoresSafeArea()
            }
            #endif
        }
    }

    @ViewBuilder private var actions: some View {
        VStack(spacing: 12) {
            #if os(iOS)
            if DocumentScanner.isSupported {
                Button {
                    isScannerPresented = true
                } label: {
                    Label("Escanear receta", systemImage: "camera.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            #endif
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Elegir foto", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .disabled(isReading)
    }

    @ViewBuilder private var status: some View {
        switch model.state {
        case .idle:
            EmptyView()
        case .reading:
            ProgressView("Leyendo la receta…")
        case let .failed(message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        }
    }

    private var isReading: Bool {
        if case .reading = model.state { return true }
        return false
    }

    private static func prepared(_ data: Data) -> Data {
        #if os(iOS)
        ImageNormalizer.normalizedJPEG(data) ?? data
        #else
        data
        #endif
    }
}

#Preview {
    ScanView(dependencies: .preview())
}
