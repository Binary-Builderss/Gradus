import Domain
import SwiftUI

struct FloatingGlass: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content
                .glass(.rect(cornerRadius: Theme.Radius.l + Theme.Space.s))
                .padding(.horizontal, Theme.Space.m)
                .padding(.bottom, Theme.Space.xs)
        } else {
            content
        }
    }
}
