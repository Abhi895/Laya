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
    @State private var isRequesting = false
    // Set only when the user just granted permission this session (not when
    // .task resolves an already-granted status). @State lifetime = this view
    // instance, so it resets to false on every future appearance of the button.
    @State private var justGranted = false

    var body: some View {
        Group {
            if isGranted && justGranted {
                // Transient confirmation — only visible in the session where
                // the user actually tapped and granted. Disappears on next visit.
                confirmation
            } else if isGranted {
                EmptyView()
            } else {
                ZStack {
                    askButton
                        .opacity(isDefault ? 1 : 0)
                    settingsLink
                        .opacity(isDenied ? 1 : 0)
                }
                .animation(.easeOut(duration: 0.35), value: status)
            }
        }
        .task {
            await refreshAndScheduleIfAuthorized()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await refreshAndScheduleIfAuthorized() }
        }
    }

    private var isGranted: Bool {
        status == .authorized || status == .provisional || status == .ephemeral
    }
    private var isDenied: Bool { status == .denied }
    private var isDefault: Bool { !isGranted && !isDenied }

    private func refreshAndScheduleIfAuthorized() async {
        status = await NotificationPermission.currentStatus()
        if status == .authorized || status == .provisional || status == .ephemeral {
            await NotificationPermission.scheduleNextDropReminder(
                at: date, title: notificationTitle, body: notificationBody
            )
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
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.right.circle.fill")
                Text("Open Settings")
            }
            .font(.layaBody(15, weight: .medium))
            .foregroundStyle(tintColor.opacity(0.6))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(PressableButtonStyle())
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
        guard !isRequesting else { return }
        isRequesting = true
        Task {
            let granted = await NotificationPermission.request()
            if granted {
                await NotificationPermission.scheduleNextDropReminder(
                    at: date, title: notificationTitle, body: notificationBody
                )
            }
            status = await NotificationPermission.currentStatus()
            if granted { justGranted = true }
            isRequesting = false
        }
    }
}
