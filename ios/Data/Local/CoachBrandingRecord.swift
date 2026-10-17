import Domain
import Foundation
import GRDB

/// Il marchio del coach (`coach_branding`): nome, logo PNG in base64 e colori scelti. Sola lettura; il server lo mostra
/// all'atleta solo finché il coach ha la personalizzazione.
struct CoachBrandingRecord: Codable, Equatable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "coach_branding"
    var coachId: UUID
    var brandName: String?
    var logoPng: String?
    var colors: [String: String]
    var hideGradusCredit: Bool
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case coachId = "coach_id"
        case brandName = "brand_name"
        case logoPng = "logo_png"
        case colors
        case hideGradusCredit = "hide_gradus_credit"
        case updatedAt = "updated_at"
    }
}

/// Quello che l'interfaccia usa del marchio: nome (senza spazi vuoti), logo già decodificato e palette.
struct Branding: Equatable, Sendable {
    var name: String?
    var logo: Data?
    var palette: BrandPalette

    init(_ record: CoachBrandingRecord) {
        let trimmed = record.brandName?.trimmingCharacters(in: .whitespacesAndNewlines)
        name = trimmed?.isEmpty == false ? trimmed : nil
        logo = record.logoPng.flatMap { Data(base64Encoded: $0) }
        palette = BrandPalette(colors: record.colors)
    }

    static let standard = Branding(name: nil, logo: nil, palette: .standard)

    private init(name: String?, logo: Data?, palette: BrandPalette) {
        self.name = name
        self.logo = logo
        self.palette = palette
    }
}

enum BrandingStore {
    /// Sostituisce il marchio locale con quello del server (nessuna riga = il coach non ha la personalizzazione).
    static func replace(_ db: Database, with rows: [CoachBrandingRecord]) throws {
        _ = try CoachBrandingRecord.deleteAll(db)
        // L'atleta ha un solo coach attivo: se arrivassero più righe vale quella del coach collegato.
        let active = try UUID.fetchSet(db, sql: "SELECT coach_id FROM coach_athletes WHERE status = 'active'")
        if let row = rows.first(where: { active.contains($0.coachId) }) ?? rows.first { try row.insert(db) }
    }

    static func current(_ db: Database) throws -> Branding {
        try CoachBrandingRecord.fetchOne(db).map(Branding.init) ?? .standard
    }
}
