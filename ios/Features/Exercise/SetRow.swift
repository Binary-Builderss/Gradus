import Domain
import SwiftUI

struct SetRow: View {
    @Environment(\.palette) private var palette
    @Bindable var model: ExerciseModel
    let block: BlockContent
    let key: SetKey
    /// La prima serie dell'esercizio: la guida ne evidenzia i campi e lo sforzo.
    let isTourFirst: Bool
    /// La serie con il primo «Avvia timer» dell'esercizio, per la guida.
    let isTourTimer: Bool
    var focused: FocusState<Bool>.Binding
    let startTimer: (SetKey) -> Void
    /// Cifre e caselle di kg e ripetizioni seguono la dimensione del testo di iOS, con un tetto: due caselle devono
    /// stare sulla stessa riga.
    @ScaledMetric(relativeTo: .largeTitle) private var digits = 44.0
    @ScaledMetric(relativeTo: .largeTitle) private var boxHeight = 68.0

    var body: some View {
        let draft = model.drafts[key] ?? SetDraft()
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Serie \(key.idx + 1)").font(.headline)
                if draft.hasData {
                    // Si salva da sola: il segno dice che la serie è registrata.
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(palette.accent)
                        .accessibilityLabel("registrata")
                        .transition(.scale.combined(with: .opacity))
                }
                Spacer()
                if let reps = block.prescription?.repsText {
                    Text("\(reps.replacingOccurrences(of: "-", with: "–")) rip.").font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Obiettivo \(reps) ripetizioni")
                }
            }
            .animation(.snappy, value: draft.hasData)
            if let reference = model.references[key] {
                Text(reference).font(.title3.weight(.bold).monospacedDigit()).foregroundStyle(palette.accent)
            }
            ForEach(draft.segments.indices, id: \.self) { index in
                HStack(spacing: 10) {
                    field(
                        text: $model[load: key, segment: index],
                        unit: "kg", keyboard: .decimalPad,
                        label: "Carico, serie \(key.idx + 1)\(draft.segments.count > 1 ? ", segmento \(index + 1)" : "")")
                    Text("×").foregroundStyle(.secondary)
                    field(
                        text: $model[reps: key, segment: index],
                        unit: "rip.", keyboard: .numberPad,
                        label: "Ripetizioni, serie \(key.idx + 1)\(draft.segments.count > 1 ? ", segmento \(index + 1)" : "")")
                }
                .tourTarget("exercise-set", if: isTourFirst && index == 0)
            }
            if block.hasSegments {
                Button {
                    model.addSegment(key)
                } label: {
                    Label("Segmento", systemImage: "plus.circle")
                }
                .buttonStyle(.borderless).font(.subheadline)
            }
            EffortRow(model: model, block: block, key: key)
                .tourTarget("exercise-effort", if: isTourFirst)
            if model.showsTimerButton(key, block: block) {
                Button {
                    startTimer(key)
                } label: {
                    Label("Avvia timer", systemImage: "timer").frame(maxWidth: .infinity)
                }
                .modifier(SecondaryActionStyle())
                .tourTarget("exercise-timer", if: isTourTimer)
                .accessibilityHint("Recupero di \(RestText.format(seconds: model.restSeconds(for: block)))")
            }
        }
        .padding(.vertical, 4)
    }

    private func field(text: Binding<String>, unit: String, keyboard: UIKeyboardType, label: String) -> some View {
        HStack(spacing: 6) {
            TextField("", text: text)  // vuoto: nessun valore (nemmeno grigio) finché l'atleta non scrive
                .keyboardType(keyboard)
                .multilineTextAlignment(.center)
                .font(.system(size: min(digits, 60), weight: .heavy).monospacedDigit())
                .minimumScaleFactor(0.5)
                .frame(minWidth: 64, maxWidth: 140, minHeight: min(boxHeight, 88))
                .background(palette.background, in: .rect(cornerRadius: Theme.Radius.s))
                .focused(focused)
                .accessibilityLabel(label)
            Text(unit).font(.footnote).foregroundStyle(.secondary)
        }
    }
}
