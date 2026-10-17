import AVFoundation
import AudioToolbox
import Domain
import Foundation
import Observation
import UIKit
import UserNotifications

/// Le notifiche locali del timer, dietro un confine: i test usano un finto.
protocol RestNotifier: Sendable {
    func requestAuthorizationIfNeeded() async
    func schedule(at date: Date, title: String, body: String, sound: Bool) async
    func cancel() async
}

/// Vibrazione e suono alla fine del recupero (con l'app aperta; in background parla la notifica).
@MainActor
protocol RestFeedback {
    func finished(sound: Bool, haptic: Bool)
}

struct SystemRestNotifier: RestNotifier {
    static let id = "rest-timer"
    /// Il suono di fine recupero (tre note che salgono), lo stesso con l'app aperta e nella notifica.
    static let soundFile = "RestEnd.caf"

    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        guard await center.notificationSettings().authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func schedule(at date: Date, title: String, body: String, sound: Bool) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        // Il suono della notifica fa anche vibrare (secondo le impostazioni di iOS); senza suono arriva in silenzio.
        content.sound = sound ? UNNotificationSound(named: UNNotificationSoundName(Self.soundFile)) : nil
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(date.timeIntervalSinceNow, 1), repeats: false)
        // Stesso identificatore: una nuova richiesta sostituisce la precedente (un solo timer alla volta).
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: Self.id, content: content, trigger: trigger))
    }

    func cancel() async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.id])
    }
}

/// Con l'app aperta: il suono di fine recupero sopra la musica (che si abbassa un momento, senza fermarsi) e una
/// vibrazione vera, non solo un tocco leggero. Il suono si sente anche con l'iPhone in silenzioso: l'ha chiesto
/// l'atleta nelle Preferenze, e in palestra il telefono è spesso in silenzioso.
@MainActor
final class SystemRestFeedback: RestFeedback {
    private var player: AVAudioPlayer?

    func finished(sound: Bool, haptic: Bool) {
        if haptic {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        if sound { play() }
    }

    private func play() {
        guard let url = Bundle.main.url(forResource: SystemRestNotifier.soundFile, withExtension: nil) else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers, .duckOthers])
        try? session.setActive(true)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
        let duration = player?.duration ?? 0
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration + 0.2))
            self?.player = nil
            // La musica torna al suo volume.
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}

/// Il timer di recupero. Un solo timer attivo: uno nuovo sostituisce il precedente. Salva l'orario di fine, non un
/// contatore: dopo background, blocco dello schermo o riavvio dell'app il residuo si ricalcola da quello.
@MainActor
@Observable
final class RestTimerModel {
    static let stateKey = "restTimer"
    static let soundKey = "timerSound"
    static let hapticKey = "timerHaptic"

    private(set) var state: RestTimerState?

    private let defaults: UserDefaults
    private let notifier: any RestNotifier
    private let feedback: any RestFeedback
    private let now: @Sendable () -> Date
    private let autoFinish: Bool
    private var finishTask: Task<Void, Never>?

    init(
        defaults: UserDefaults = .standard, notifier: any RestNotifier = SystemRestNotifier(),
        feedback: any RestFeedback = SystemRestFeedback(), now: @escaping @Sendable () -> Date = { Date() },
        autoFinish: Bool = true
    ) {
        self.defaults = defaults
        self.notifier = notifier
        self.feedback = feedback
        self.now = now
        self.autoFinish = autoFinish
        if let data = defaults.data(forKey: Self.stateKey),
            let saved = try? JSONDecoder().decode(RestTimerState.self, from: data)
        {
            state = saved
            refresh()
            if state != nil { armFinish() }
        }
    }

    // MARK: Azioni

    /// «Avvia timer»: non salva né conferma niente, parte solo il recupero.
    func start(seconds: Int, title: String) {
        guard seconds > 0 else { return }
        set(RestTimerState(startingAt: now(), seconds: seconds, title: title))
        Task { await notifier.requestAuthorizationIfNeeded() }
    }

    /// +15 s / −15 s. Sotto zero il recupero è finito.
    func adjust(bySeconds seconds: Int) {
        guard let current = state else { return }
        let next = current.adjusted(bySeconds: seconds)
        if next.isFinished(at: now()) {
            finish(withFeedback: false)
        } else {
            set(next)
        }
    }

    /// «Salta»: chiude il timer senza avvisi.
    func skip() {
        finish(withFeedback: false)
    }

    /// Chiamata quando l'app torna in primo piano: se il recupero è finito mentre non c'eravamo, l'ha già detto la
    /// notifica; qui si toglie la barra, senza vibrare un'altra volta.
    func refresh() {
        guard let current = state, current.isFinished(at: now()) else { return }
        finish(withFeedback: false)
    }

    /// «Prova» nelle Preferenze: suono e vibrazione come a fine recupero.
    func preview(sound: Bool, haptic: Bool) {
        feedback.finished(sound: sound, haptic: haptic)
    }

    /// Fine naturale con l'app aperta: vibrazione e suono, se attivi nelle impostazioni.
    func completeIfDue() {
        guard let current = state, current.isFinished(at: now()) else { return }
        finish(withFeedback: true)
    }

    func remainingSeconds(at date: Date) -> Int { state?.remainingSeconds(at: date) ?? 0 }

    // MARK: Interno

    private func set(_ next: RestTimerState) {
        state = next
        defaults.set(try? JSONEncoder().encode(next), forKey: Self.stateKey)
        armFinish()
        let sound = defaults.object(forKey: Self.soundKey) as? Bool ?? true
        Task { await notifier.schedule(at: next.endDate, title: "Recupero finito", body: next.title, sound: sound) }
    }

    private func finish(withFeedback: Bool) {
        finishTask?.cancel()
        finishTask = nil
        state = nil
        defaults.removeObject(forKey: Self.stateKey)
        Task { await notifier.cancel() }
        if withFeedback {
            feedback.finished(
                sound: defaults.object(forKey: Self.soundKey) as? Bool ?? true,
                haptic: defaults.object(forKey: Self.hapticKey) as? Bool ?? true)
        }
    }

    private func armFinish() {
        finishTask?.cancel()
        guard autoFinish, let end = state?.endDate else { return }
        finishTask = Task { [weak self, now] in
            try? await Task.sleep(for: .seconds(max(end.timeIntervalSince(now()), 0)))
            guard !Task.isCancelled else { return }
            self?.completeIfDue()
        }
    }
}
