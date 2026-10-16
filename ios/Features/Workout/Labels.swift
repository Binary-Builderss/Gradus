import Domain
import GRDB
import SwiftUI

/// I nomi che il coach usa sul web, per riconoscersi tra coach e atleta.
enum Labels {
    static func role(_ role: String) -> String {
        switch role {
        case "warmup": "Riscaldamento"
        case "top": "Top set"
        case "backoff": "Back-off"
        default: "Serie"
        }
    }

    static func technique(_ technique: String) -> String? {
        switch technique {
        case "drop": "Drop set"
        case "rest_pause": "Rest-pause"
        case "myo": "Myo-reps"
        case "cluster": "Cluster"
        default: nil
        }
    }

    static func groupKind(_ kind: String) -> String? {
        switch kind {
        case "superset": "Superset"
        case "giant": "Giant set"
        case "circuit": "Circuito"
        case "jumpset": "Jump set"
        default: nil
        }
    }
}
