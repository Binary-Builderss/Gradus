import SwiftUI

/// Un tasto secondario su un fondo normale: vetro da iOS 26, «bordered» sotto.
struct SecondaryActionStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.buttonStyle(.glass)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}
