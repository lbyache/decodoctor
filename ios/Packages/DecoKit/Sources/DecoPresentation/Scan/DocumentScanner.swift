#if os(iOS)
import SwiftUI
import UIKit
import VisionKit

/// Escáner de documentos de VisionKit: detecta los bordes de la hoja, la endereza y mejora el
/// contraste antes del OCR. No está disponible en el simulador.
struct DocumentScanner: UIViewControllerRepresentable {
    let onScan: (UIImage) -> Void
    let onCancel: () -> Void

    static var isSupported: Bool { VNDocumentCameraViewController.isSupported }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan, onCancel: onCancel) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: (UIImage) -> Void
        let onCancel: () -> Void

        init(onScan: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onScan = onScan
            self.onCancel = onCancel
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            // Una receta = una hoja: se toma la primera página.
            guard scan.pageCount > 0 else { return onCancel() }
            onScan(scan.imageOfPage(at: 0))
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { onCancel() }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: any Error) { onCancel() }
    }
}

enum ImageNormalizer {
    /// Lado mayor máximo: suficiente para el OCR y liviano para guardar en el historial.
    static let maxDimension: CGFloat = 2_400

    /// Redibuja la imagen orientada "arriba" (Vision no siempre respeta la orientación EXIF)
    /// y la reduce si hace falta. Devuelve JPEG.
    static func normalizedJPEG(_ image: UIImage) -> Data? {
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.jpegData(compressionQuality: 0.85)
    }

    static func normalizedJPEG(_ data: Data) -> Data? {
        UIImage(data: data).flatMap(normalizedJPEG)
    }
}
#endif
