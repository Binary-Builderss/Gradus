import SwiftUI

struct LabeledField<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            content
                .padding(12)
                .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.m))
                .overlay { RoundedRectangle(cornerRadius: Theme.Radius.m).stroke(Theme.hairline) }
        }
    }
}
