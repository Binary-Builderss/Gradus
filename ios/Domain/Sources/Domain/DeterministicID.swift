import CryptoKit
import Foundation

/// Gli id delle righe di esecuzione derivano dalla loro chiave naturale (UUID versione 5): lo stesso workout, la stessa
/// serie e lo stesso segmento hanno lo stesso id su ogni telefono e a ogni reinstallazione. Così reinviare una riga è
/// sempre un upsert sulla stessa chiave primaria e due dispositivi non creano mai righe doppie.
public enum DeterministicID {
    /// Namespace fisso dell'app: cambiarlo cambierebbe tutti gli id.
    static let namespace = UUID(uuidString: "6F0C1B5A-3D7E-4A2B-9C84-1E5D0A7B9F31")!

    /// `workouts (session_id, week)`.
    public static func workout(sessionID: UUID, week: Int) -> UUID {
        make("workout/\(sessionID.uuidString.lowercased())/\(week)")
    }

    /// `set_logs (workout_id, block_id, set_idx)`.
    public static func setLog(workoutID: UUID, blockID: UUID, setIdx: Int) -> UUID {
        make("set/\(workoutID.uuidString.lowercased())/\(blockID.uuidString.lowercased())/\(setIdx)")
    }

    /// `set_segments (set_log_id, seg_idx)`.
    public static func segment(setLogID: UUID, segIdx: Int) -> UUID {
        make("segment/\(setLogID.uuidString.lowercased())/\(segIdx)")
    }

    /// `nutrition_days (athlete_id, day)`: `day` come `yyyy-MM-dd`.
    public static func nutritionDay(athleteID: UUID, day: String) -> UUID {
        make("nutrition/\(athleteID.uuidString.lowercased())/\(day)")
    }

    static func make(_ name: String) -> UUID { v5(namespace: namespace, name: name) }

    static func v5(namespace: UUID, name: String) -> UUID {
        var bytes = withUnsafeBytes(of: namespace.uuid) { Array($0) }
        bytes.append(contentsOf: Array(name.utf8))
        var hash = Array(Insecure.SHA1.hash(data: bytes))
        hash[6] = (hash[6] & 0x0F) | 0x50  // versione 5
        hash[8] = (hash[8] & 0x3F) | 0x80  // variante RFC 4122
        return UUID(uuid: (
            hash[0], hash[1], hash[2], hash[3], hash[4], hash[5], hash[6], hash[7],
            hash[8], hash[9], hash[10], hash[11], hash[12], hash[13], hash[14], hash[15]))
    }
}
