// swift-tools-version: 6.0
import PackageDescription

// Regole di dominio dell'app atleta: funzioni pure, senza I/O (vedi ios/CLAUDE.md).
// Si testano da terminale con `swift test`, senza simulatore.
let package = Package(
    name: "Domain",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "Domain", targets: ["Domain"])],
    targets: [
        .target(name: "Domain"),
        .testTarget(name: "DomainTests", dependencies: ["Domain"]),
    ],
    swiftLanguageModes: [.v6]
)
