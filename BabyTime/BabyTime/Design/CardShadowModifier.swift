//
//  CardShadowModifier.swift
//  BabyTime
//
//  Multi-layer shadow modifier for floating card effect.
//

import SwiftUI

struct CardShadowModifier: ViewModifier {
    private let shadowColor = Color(red: 0.173, green: 0.145, blue: 0.125) // #2C2520

    func body(content: Content) -> some View {
        content
            .shadow(color: shadowColor.opacity(0.04), radius: 1, x: 0, y: 1)
            .shadow(color: shadowColor.opacity(0.03), radius: 4, x: 0, y: 4)
            .shadow(color: shadowColor.opacity(0.05), radius: 12, x: 0, y: 12)
            .shadow(color: shadowColor.opacity(0.04), radius: 24, x: 0, y: 24)
    }
}

extension View {
    func cardShadow() -> some View {
        modifier(CardShadowModifier())
    }
}
