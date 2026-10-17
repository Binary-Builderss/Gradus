import SwiftUI

struct LabeledField<Content: View>: View {
    @Environment(\.palette) private var palette
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            content
                .padding(12)
                .background(palette.surface, in: .rect(cornerRadius: Theme.Radius.m))
                .overlay { RoundedRectangle(cornerRadius: Theme.Radius.m).stroke(palette.hairline) }
        }
    }
}
