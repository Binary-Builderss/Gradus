import Foundation
import Testing

@testable import Gradus

@MainActor
struct TourTests {
    // MARK: La guida copre tutta l'app (come sul sito)

    /// Tutti i `tourTarget("…")` scritti nelle schermate.
    private static func targetsInSources(file: StaticString = #filePath) throws -> Set<String> {
        var root = URL(fileURLWithPath: "\(file)").deletingLastPathComponent()  // ios/Tests
        root.deleteLastPathComponent()  // ios
        var found = Set<String>()
        let pattern = try NSRegularExpression(pattern: #"tourTarget\(\s*"([a-z-]+)""#)
        for folder in ["Features", "App"] {
            let enumerator = FileManager.default.enumerator(at: root.appending(path: folder), includingPropertiesForKeys: nil)
            while let url = enumerator?.nextObject() as? URL {
                guard url.pathExtension == "swift", !url.lastPathComponent.hasPrefix("Tour") else { continue }  // non la definizione
                let text = try String(contentsOf: url, encoding: .utf8)
                for match in pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                    if let range = Range(match.range(at: 1), in: text) { found.insert(String(text[range])) }
                }
            }
        }
        return found
    }

    @Test("ogni passo evidenzia un elemento che esiste davvero")
    func everyTargetExists() throws {
        let sources = try Self.targetsInSources()
        for step in TourPlan.steps(hasProgram: true) {
            if let target = step.target { #expect(sources.contains(target), "manca tourTarget(\"\(target)\") per il passo \(step.id)") }
        }
    }

    @Test("ogni elemento evidenziabile ha un passo (nuove funzioni = nuovo passo in TourPlan)")
    func everyTargetHasAStep() throws {
        let used = Set(TourPlan.steps(hasProgram: true).compactMap(\.target))
        for target in try Self.targetsInSources() { #expect(used.contains(target), "nessun passo per tourTarget(\"\(target)\")") }
    }

    @Test("ogni scheda dell'app è nel percorso")
    func everyTabIsVisited() {
        let tabs = Set(TourPlan.steps(hasProgram: true).map(\.tab))
        for tab in [MainTab.workout, .macro, .profile] { #expect(tabs.contains(tab), "la guida non passa da \(tab)") }
    }

    @Test("ogni passo ha un id unico, un titolo e un testo")
    func stepsAreWellFormed() {
        for hasProgram in [true, false] {
            let steps = TourPlan.steps(hasProgram: hasProgram)
            #expect(Set(steps.map(\.id)).count == steps.count)
            #expect(steps.allSatisfy { !$0.title.isEmpty && !$0.body.isEmpty })
        }
    }

    @Test("senza un programma la guida salta i passi che lo mostrano e lo spiega")
    func withoutProgram() {
        let steps = TourPlan.steps(hasProgram: false)
        #expect(!steps.contains { $0.target?.hasPrefix("home-") == true })
        #expect(steps.contains { $0.id == "no-program" })
    }

    // MARK: Come ci si muove

    @Test("avanti, indietro, e alla fine non riparte da sola")
    func navigation() {
        let defaults = UserDefaults(suiteName: "tour-\(UUID())")!
        let tour = TourModel(defaults: defaults)
        #expect(!tour.isActive && !tour.hasSeen)
        tour.start(hasProgram: true)
        #expect(tour.isActive && tour.isFirst && tour.current?.id == "welcome")
        tour.back()
        #expect(tour.isFirst)
        tour.next()
        #expect(tour.index == 1)
        tour.back()
        #expect(tour.isFirst)
        while !tour.isLast { tour.next() }
        #expect(tour.current?.id == "guide")
        tour.next()  // «Fine»
        #expect(!tour.isActive)
        #expect(tour.hasSeen)
    }

    @Test("«Salta» chiude e la guida non riparte da sola, ma si può rifare")
    func skip() {
        let tour = TourModel(defaults: UserDefaults(suiteName: "tour-\(UUID())")!)
        tour.start(hasProgram: true)
        tour.next()
        tour.finish()
        #expect(!tour.isActive && tour.hasSeen)
        tour.start(hasProgram: false)
        #expect(tour.isActive && tour.isFirst)
    }

    // MARK: Geometria del riquadro

    @Test("l'elemento è evidenziato solo se sta sullo schermo")
    func visibleRect() {
        let size = CGSize(width: 390, height: 844)
        #expect(TourOverlay.visible(CGRect(x: 20, y: 100, width: 200, height: 60), in: size) == CGRect(x: 20, y: 100, width: 200, height: 60))
        #expect(TourOverlay.visible(CGRect(x: 20, y: 900, width: 200, height: 60), in: size) == nil)
        #expect(TourOverlay.visible(.zero, in: size) == nil)
        #expect(TourOverlay.visible(CGRect(x: 20, y: 800, width: 200, height: 100), in: size)?.maxY == 844)
    }

    @Test("l'evidenziazione si allarga a tutta la riga e non cambia l'altezza")
    func highlightRow() {
        let size = CGSize(width: 390, height: 844)
        let row = TourOverlay.highlight(CGRect(x: 40, y: 120, width: 120, height: 50), in: size)
        #expect(row == CGRect(x: 16, y: 120, width: 358, height: 50))
    }

    @Test("il riquadro sta sotto un elemento in alto, sopra uno in basso, al centro senza elemento, sempre dentro lo schermo")
    func cardPosition() {
        let size = CGSize(width: 390, height: 844)
        let top = TourOverlay.cardCenterY(CGRect(x: 0, y: 120, width: 390, height: 80), size: size)
        let bottom = TourOverlay.cardCenterY(CGRect(x: 0, y: 700, width: 390, height: 80), size: size)
        #expect(top > 200)  // sotto
        #expect(bottom < 700)  // sopra
        #expect(TourOverlay.cardCenterY(nil, size: size) == 422)
        for height in [CGFloat(200), 260, 380] {
            for y in [CGFloat(0), 120, 400, 700, 840] {
                let center = TourOverlay.cardCenterY(CGRect(x: 0, y: y, width: 100, height: 40), size: size, cardHeight: height)
                #expect(center - height / 2 >= 0 && center + height / 2 <= size.height, "fuori schermo (y \(y), altezza \(height))")
            }
        }
        // Un riquadro alto non copre l'elemento quando c'è posto da una parte: elemento a metà schermo, riquadro di 300.
        let middle = CGRect(x: 0, y: 430, width: 390, height: 60)
        let center = TourOverlay.cardCenterY(middle, size: size, cardHeight: 300)
        #expect(center + 150 <= middle.minY || center - 150 >= middle.maxY)
    }
}
