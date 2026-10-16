import SwiftUI

/// Il riquadro della guida: oscura lo schermo, evidenzia l'elemento del passo (se è visibile) e mostra titolo, testo e i
/// pulsanti. Sta sopra tutta l'app e assorbe i tocchi finché la guida è aperta.
struct TourOverlay: View {
    let tour: TourModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// L'altezza vera del riquadro (dipende dal testo): serve a non coprire l'elemento evidenziato.
    @State private var cardHeight: CGFloat = 260

    var body: some View {
        if let step = tour.current {
            GeometryReader { proxy in
                let origin = proxy.frame(in: .global).origin
                let size = proxy.size
                let target = TourRegistry.shared.frames[step.target ?? ""].map { $0.offsetBy(dx: -origin.x, dy: -origin.y) }
                let visible = target.flatMap { Self.visible($0, in: size) }.map { Self.highlight($0, in: size) }
                ZStack {
                    Self.dim(hole: visible, size: size)
                        .fill(Color.black.opacity(0.62), style: FillStyle(eoFill: true))
                        .contentShape(Rectangle())
                        .onTapGesture {}  // assorbe i tocchi: l'app sotto non si usa durante la guida
                        .accessibilityHidden(true)
                    if let visible {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.9), lineWidth: 2)
                            .frame(width: visible.width + 12, height: visible.height + 12)
                            .position(x: visible.midX, y: visible.midY)
                            .accessibilityHidden(true)
                    }
                    card(step)
                        .frame(maxWidth: 420)
                        .padding(.horizontal, 20)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { cardHeight = $0 }
                        .position(x: size.width / 2, y: Self.cardCenterY(visible, size: size, cardHeight: cardHeight))
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: step.id)
            }
            .ignoresSafeArea()
            .accessibilityAddTraits(.isModal)
            .transition(.opacity)
        }
    }

    private func card(_ step: TourStep) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(tour.index + 1) di \(tour.steps.count)").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                if !tour.isLast { Button("Salta") { tour.finish() }.font(.subheadline) }
            }
            Text(step.title).font(.title3.bold()).accessibilityAddTraits(.isHeader)
            Text(step.body).font(.body).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                if !tour.isFirst { Button("Indietro") { tour.back() }.buttonStyle(.bordered) }
                Spacer()
                Button(tour.isLast ? "Fine" : "Avanti") { tour.next() }.buttonStyle(.borderedProminent)
            }
            .padding(.top, 4)
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.25), radius: 18, y: 6)
        .accessibilityElement(children: .contain)
    }

    // MARK: Geometria (funzioni pure, provabili senza schermo)

    /// L'elemento solo se sta almeno in parte sullo schermo; altrimenti il passo si mostra senza evidenziare nulla.
    static func visible(_ rect: CGRect, in size: CGSize) -> CGRect? {
        let screen = CGRect(origin: .zero, size: size)
        guard rect.width > 0, rect.height > 0, rect.intersects(screen) else { return nil }
        return rect.intersection(screen)
    }

    /// L'evidenziazione occupa tutta la riga (un elemento largo quanto il suo testo sembrerebbe tagliato).
    static func highlight(_ rect: CGRect, in size: CGSize) -> CGRect {
        CGRect(x: 16, y: rect.minY, width: max(size.width - 32, rect.width), height: rect.height)
    }

    /// Dove mettere il riquadro: sotto l'elemento se ci sta, altrimenti sopra, altrimenti dalla parte con più spazio; al
    /// centro se non c'è un elemento. Mai fuori dallo schermo né sulla barra in basso. `cardHeight` è l'altezza misurata.
    static func cardCenterY(_ target: CGRect?, size: CGSize, cardHeight: CGFloat = 260) -> CGFloat {
        let top: CGFloat = 70  // sotto l'orologio
        let bottom: CGFloat = 110  // sopra la barra delle schede
        let lowest = size.height - bottom - cardHeight / 2
        let highest = top + cardHeight / 2
        guard let target else { return min(max(size.height / 2, highest), lowest) }
        let gap: CGFloat = 20
        let spaceBelow = size.height - bottom - target.maxY - gap
        let spaceAbove = target.minY - gap - top
        let below = target.maxY + gap + cardHeight / 2
        let above = target.minY - gap - cardHeight / 2
        let preferred: CGFloat
        if spaceBelow >= cardHeight { preferred = below }
        else if spaceAbove >= cardHeight { preferred = above }
        else { preferred = spaceBelow >= spaceAbove ? below : above }
        return min(max(preferred, highest), lowest)
    }

    /// Lo schermo intero con un buco attorno all'elemento (riempimento «pari-dispari»).
    static func dim(hole: CGRect?, size: CGSize) -> Path {
        var path = Path(CGRect(origin: .zero, size: size))
        if let hole { path.addRoundedRect(in: hole.insetBy(dx: -6, dy: -6), cornerSize: CGSize(width: 12, height: 12)) }
        return path
    }
}
