import Foundation
import Observation
import SwiftUI

/// Le posizioni degli elementi evidenziati dalla guida, in coordinate dello schermo. Ogni `tourTarget` scrive la sua qui e
/// la toglie quando sparisce: un registro condiviso funziona anche per le righe dentro una lista.
@MainActor
@Observable
final class TourRegistry {
    static let shared = TourRegistry()
    private(set) var frames: [String: CGRect] = [:]

    func set(_ id: String, _ frame: CGRect) { if frames[id] != frame { frames[id] = frame } }
    func remove(_ id: String) { frames[id] = nil }
}

extension View {
    /// Segna questo elemento come evidenziabile dalla guida (`TourStep.target`).
    func tourTarget(_ id: String) -> some View {
        modifier(TourTargetModifier(id: id))
    }
}

extension View {
    /// Come `tourTarget`, ma solo per un elemento della lista (il primo): gli altri restano com'erano.
    @ViewBuilder func tourTarget(_ id: String, if condition: Bool) -> some View {
        if condition { tourTarget(id) } else { self }
    }
}

private struct TourTargetModifier: ViewModifier {
    let id: String

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                TourRegistry.shared.set(id, frame)
            }
            .onDisappear { TourRegistry.shared.remove(id) }
    }
}

/// La guida in corso: il passo attuale e come muoversi. Parte da sola la prima volta e si rivede dal Profilo.
@MainActor
@Observable
final class TourModel {
    static let seenKey = "tourSeen"

    private(set) var steps: [TourStep] = []
    private(set) var index = 0
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var isActive: Bool { !steps.isEmpty }
    var current: TourStep? { steps.indices.contains(index) ? steps[index] : nil }
    var isFirst: Bool { index == 0 }
    var isLast: Bool { index == steps.count - 1 }
    /// La guida è già stata vista (o saltata): non riparte da sola.
    var hasSeen: Bool { defaults.bool(forKey: Self.seenKey) }

    func start(hasProgram: Bool) {
        steps = TourPlan.steps(hasProgram: hasProgram)
        index = 0
    }

    func next() {
        if isLast { finish() } else { index += 1 }
    }

    func back() { index = max(index - 1, 0) }

    /// Fine o «Salta»: non riparte più da sola.
    func finish() {
        steps = []
        index = 0
        defaults.set(true, forKey: Self.seenKey)
    }
}
