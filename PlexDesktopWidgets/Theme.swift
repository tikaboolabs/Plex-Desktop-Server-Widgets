import SwiftUI

// MARK: - Widget Background
struct WidgetBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.07, green: 0.08, blue: 0.14).opacity(0.85),
                                Color(red: 0.05, green: 0.06, blue: 0.11).opacity(0.85)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.20, green: 0.25, blue: 0.40).opacity(0.4),
                                        Color(red: 0.10, green: 0.12, blue: 0.22).opacity(0.2)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
            )
    }
}

extension View {
    func widgetBackground() -> some View {
        modifier(WidgetBackground())
    }
}

// MARK: - Colors
extension Color {
    // Plex brand
    static let plexGold = Color(red: 229/255, green: 160/255, blue: 13/255)
    static let plexCyan = Color(red: 90/255, green: 200/255, blue: 250/255)
    static let plexPurple = Color(red: 191/255, green: 90/255, blue: 242/255)
    static let plexGreen = Color(red: 52/255, green: 199/255, blue: 89/255)
    static let plexRed = Color(red: 255/255, green: 59/255, blue: 48/255)
    static let plexAmber = Color(red: 255/255, green: 159/255, blue: 10/255)

    // Text hierarchy — cool blue-white tones
    static let wText = Color(red: 0.90, green: 0.93, blue: 0.98)
    static let wTextMid = Color(red: 0.52, green: 0.58, blue: 0.72)
    static let wTextDim = Color(red: 0.32, green: 0.38, blue: 0.52)
    static let wTextFaint = Color(red: 0.20, green: 0.24, blue: 0.36)

    // Structural
    static let wSeparator = Color(red: 0.16, green: 0.20, blue: 0.32).opacity(0.6)
    static let wCardBg = Color(red: 0.09, green: 0.10, blue: 0.18)
    static let wTrack = Color(red: 0.12, green: 0.14, blue: 0.24)
}
