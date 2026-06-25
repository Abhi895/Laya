//
//  NotifyMeButton.swift
//  Laya
//
//  Created by Abhi Reddy on 25/06/2026.
//

import SwiftUI
import UserNotifications

/// Requests notification permission and schedules a single "next thing is
/// ready" reminder, then reflects whatever the user actually decided. iOS
/// never lets an app re-prompt after the first answer, so once tapped this
/// stops being a button at all — granted settles into a quiet confirmation,
/// denied becomes a link to Settings (the only way left to change it).
struct NotifyMeButton: View {
    enum Style {
        /// Matches the filled CTA it's replacing — pass the same colour
        /// (`.copper` on the dark locked screen, `.textPrimary` elsewhere).
        case primary(background: Color)
        /// For places this is a secondary action alongside another primary
        /// CTA (e.g. paired with the "Stream" placeholder).
        case secondary
    }

    let style: Style
    let label: String
    let date: Date
    let notificationTitle: String
    let notificationBody: String

    @State private var status: UNAuthorizationStatus?

    var body: some View {
        Group {
            switch status {
            case .authorized, .provisional, .ephemeral:
                confirmation
            case .denied:
                settingsLink
            default:
                askButton
            }
        }
        .task {
            status = await NotificationPermission.currentStatus()
        }
    }

    @ViewBuilder private var askButton: some View {
        switch style {
        case .primary(let background):
            PrimaryActionButton(
                title: label,
                background: background,
                icon: Image(systemName: "bell"),
                action: requestAndSchedule
            )
        case .secondary:
            SecondaryActionButton(title: label, icon: Image(systemName: "bell"), action: requestAndSchedule)
        }
    }

    private var settingsLink: some View {
        Button(action: NotificationPermission.openSettings) {
            Text("Enable notifications in Settings")
                .font(.layaBody(14, weight: .regular))
                .foregroundStyle(tintColor.opacity(0.7))
                .underline()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(HapticOnlyButtonStyle())
    }

    private var confirmation: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
            Text("We'll let you know")
        }
        .font(.layaBody(15, weight: .medium))
        .foregroundStyle(tintColor)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private var tintColor: Color {
        switch style {
        case .primary(let background): return background
        case .secondary: return .textPrimary
        }
    }

    private func requestAndSchedule() {
        Task {
            let granted = await NotificationPermission.request()
            if granted {
                NotificationPermission.scheduleNextDropReminder(
                    at: date, title: notificationTitle, body: notificationBody
                )
            }
            status = await NotificationPermission.currentStatus()
        }
    }
}
