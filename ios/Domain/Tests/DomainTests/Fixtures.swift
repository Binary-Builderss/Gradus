import Foundation

/// Trova `/fixtures` risalendo dal file di test: i casi stanno nel repo, non in un bundle.
enum Fixtures {
    static func url(_ name: String, file: StaticString = #filePath) -> URL {
        var dir = URL(fileURLWithPath: "\(file)").deletingLastPathComponent()
        while dir.path != "/" {
            let candidate = dir.appendingPathComponent("fixtures").appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            dir.deleteLastPathComponent()
        }
        fatalError("fixture \(name) non trovata sopra \(file)")
    }
}
