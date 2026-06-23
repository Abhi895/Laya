//
//  SecondaryActionButton.swift
//  Laya
//
//  Created by Abhi Reddy on 24/06/2026.
//

import SwiftUI

/// The app's secondary call-to-action — an outline counterpart to
/// `PrimaryActionButton`, matching the onboarding screen's "Continue as
/// guest" treatment (textPrimary stroke + text, no fill). Centralised here
/// for the same reason as `PrimaryActionButton`: callers that need a
/// secondary action (e.g. "Share Journey" beside a filled "Follow") should
/// never have to invent their own outline style.
struct SecondaryActionButton: View {
    let title: String
    var icon: Image? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    icon
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                }
                Text(title)
                    .font(.layaBody(17, weight: .semibold))
            }
            .foregroundStyle(.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Capsule().strokeBorder(Color.textPrimary, lineWidth: 1.3))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 24) {
        PrimaryActionButton(title: "+ Follow Tayo") {}
        SecondaryActionButton(title: "Share Journey", icon: Image(systemName: "square.and.arrow.up")) {}
    }
    .padding(.horizontal, 32)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.cream)
}
#endif
