//
//  CardShadowModifier.swift
//  BabyTime
//
//  Single shadow modifier for floating card effect.
//  Uses one layer to match matchedTransitionSource config shadow.
//

import SwiftUI

struct CardShadowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: BTShadow.color.opacity(0.12), radius: 16, x: 0, y: 4)
    }
}

extension View {
    func cardShadow() -> some View {
        modifier(CardShadowModifier())
    }
}
