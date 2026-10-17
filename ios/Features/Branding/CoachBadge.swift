import SwiftUI

/// Il logo del coach (se c'è) e il nome del marchio: in cima alla home, come firma di chi ha scritto il programma.
struct CoachBadge: View {
    let branding: Branding

    var body: some View {
        if branding.logo != nil || branding.name != nil {
            HStack(spacing: Theme.Space.s) {
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
            }
        }
    }
}
