import DecoDomain
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Aviso permanente: la app ayuda a leer, no valida recetas (ADR 0002).
struct DisclaimerBanner: View {
    var body: some View {
        Label("Ayuda de lectura. La dispensa la valida siempre un profesional.", systemImage: "exclamationmark.shield")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(.yellow.opacity(0.15), in: .rect(cornerRadius: 10))
            .accessibilityElement(children: .combine)
    }
}

struct ConfidenceBadge: View {
    let confidence: Confidence?

    var body: some View {
        Text(title)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(.white)
            .background(color, in: .capsule)
            .accessibilityLabel("Confianza \(title)")
    }

    private var title: String {
        switch confidence {
        case .high: "Alta"
        case .medium: "Media"
        case .low: "Baja"
        case nil: "—"
        }
    }

    private var color: Color {
        switch confidence {
        case .high: .green
        case .medium: .orange
        case .low, nil: .red
        }
    }
}

extension Confidence {
    var tint: Color {
        switch self {
        case .high: .green
        case .medium: .orange
        case .low: .red
        }
    }
}

/// Foto de la receta, con renglones resaltados opcionales (cajas normalizadas, origen arriba-izquierda).
struct PrescriptionImage: View {
    let data: Data
    var highlights: [(box: NormalizedBox, color: Color, isSelected: Bool)] = []

    var body: some View {
        if let image = Self.image(from: data) {
            image
                .resizable()
                .scaledToFit()
                .overlay {
                    GeometryReader { proxy in
                        ForEach(Array(highlights.enumerated()), id: \.offset) { _, highlight in
                            let rect = CGRect(x: highlight.box.x * proxy.size.width, y: highlight.box.y * proxy.size.height,
                                              width: highlight.box.width * proxy.size.width, height: highlight.box.height * proxy.size.height)
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(highlight.color, lineWidth: highlight.isSelected ? 3 : 1.5)
                                .background(highlight.color.opacity(highlight.isSelected ? 0.2 : 0.06))
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)
                        }
                    }
                }
                .accessibilityLabel("Foto de la receta")
        } else {
            ContentUnavailableView("No se pudo mostrar la imagen", systemImage: "photo")
        }
    }

    static func image(from data: Data) -> Image? {
        #if canImport(UIKit)
        UIImage(data: data).map(Image.init(uiImage:))
        #else
        NSImage(data: data).map(Image.init(nsImage:))
        #endif
    }
}
