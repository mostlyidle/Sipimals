import SwiftUI

enum SipTheme {
    static let background = Color("Background")
    static let surface = Color("Surface")
    static let ink = Color("Ink")
    static let muted = Color("Muted")
    static let green = Color("Bamboo")
    static let mint = Color("Mint")
    static let blue = Color(red: 0.20, green: 0.66, blue: 0.89)

    static func volume(_ amount: Double) -> String {
        amount.formatted(.number.precision(.fractionLength(0)))
    }
}

extension DrinkKind {
    var color: Color {
        switch self {
        case .water, .sparklingWater: SipTheme.blue
        case .coffee: Color(red: 0.58, green: 0.37, blue: 0.24)
        case .tea: SipTheme.green
        case .softDrink: Color(red: 0.70, green: 0.35, blue: 0.29)
        case .juice: Color(red: 0.85, green: 0.47, blue: 0.13)
        case .milk: Color(red: 0.48, green: 0.53, blue: 0.70)
        case .sportsDrink: Color(red: 0.57, green: 0.44, blue: 0.75)
        case .alcohol: Color(red: 0.67, green: 0.34, blue: 0.48)
        }
    }
}

struct SipPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .bold))
            .frame(maxWidth: .infinity, minHeight: 58)
            .foregroundStyle(Color("OnBamboo"))
            .background(SipTheme.green, in: RoundedRectangle(cornerRadius: 22))
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

struct SipChoiceButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.65 : 1)
    }
}
