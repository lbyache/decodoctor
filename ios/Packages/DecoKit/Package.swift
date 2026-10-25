// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "DecoKit",
    defaultLocalization: "es",
    platforms: [
        // iOS 26: lo exige Foundation Models.
        .iOS(.v26),
        // macOS solo para correr `swift test` sin simulador.
        .macOS(.v26),
    ],
    products: [
        .library(name: "DecoDomain", targets: ["DecoDomain"]),
        .library(name: "DecoData", targets: ["DecoData"]),
        .library(name: "DecoPlatform", targets: ["DecoPlatform"]),
        .library(name: "DecoPresentation", targets: ["DecoPresentation"]),
    ],
    targets: [
        // Regla de dependencias de la arquitectura limpia, verificada por el compilador:
        // Domain no depende de nada; Data, Platform y Presentation dependen solo de Domain.
        .target(name: "DecoDomain"),
        .target(
            name: "DecoData",
            dependencies: ["DecoDomain"],
            resources: [.copy("Resources/medicamentos.json")]
        ),
        .target(name: "DecoPlatform", dependencies: ["DecoDomain"]),
        .target(name: "DecoPresentation", dependencies: ["DecoDomain"]),
        .testTarget(name: "DecoDomainTests", dependencies: ["DecoDomain"]),
        .testTarget(name: "DecoDataTests", dependencies: ["DecoData"]),
        .testTarget(name: "DecoPlatformTests", dependencies: ["DecoPlatform"]),
    ]
)
