import SwiftUI

/// Chi firma il programma, sulla fascia della home: il logo e il nome del coach se ha la personalizzazione, altrimenti la
/// G di Gradus. Il colore del testo lo decide chi lo mette (`foregroundStyle`).
struct CoachBadge: View {
    let branding: Branding

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            if branding.logo != nil || branding.name != nil {
                if let logo = branding.logo, let image = UIImage(data: logo) {
                    Image(uiImage: image)
                        .resizable().scaledToFit()
                        .frame(width: 40, height: 40)
                        .clipShape(.rect(cornerRadius: Theme.Radius.s))
                        .accessibilityHidden(true)
                }
                if let name = branding.name {
                    Text(name).font(.headline)
                }
            } else {
                GradusMark(height: 24)
                Text("Gradus Atleta").font(.subheadline.weight(.semibold))
            }
        }
    }
}
