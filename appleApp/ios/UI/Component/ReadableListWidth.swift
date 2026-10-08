import SwiftUI

/// Centres a list's rows at a readable width on wide screens, so a switch doesn't sit a
/// whole screen away from its label.
private struct ReadableListWidth: ViewModifier {
    private static let maxWidth: CGFloat = 700
    @State private var width: CGFloat = 0

    func body(content: Content) -> some View {
        content
            // nil keeps the list's own margins; a zero here would strip them on narrow screens.
            .contentMargins(.horizontal, width > Self.maxWidth ? (width - Self.maxWidth) / 2 : nil, for: .scrollContent)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                width = newWidth
            }
    }
}

extension View {
    func readableListWidth() -> some View {
        modifier(ReadableListWidth())
    }
}
