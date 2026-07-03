//
//  NotificationPermission.swift
//  Laya
//
//  Created by Abhi Reddy on 25/06/2026.
//

import UIKit
import UserNotifications

/// Local-notification permission + scheduling for "the next thing is ready"
/// reminders (next chapter unlocking, or next week's journey). Local, not
/// remote/push — the target date is always already known on-device, so no
/// backend is needed to send these.
enum NotificationPermission {
    static func currentStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Requests system permission. Only actually shows a prompt the first
    /// time an app ever calls this — every call after the user has answered
    /// once just resolves immediately with that same decision, no UI. That's
    /// an iOS constraint, not a choice this app is making.
    @discardableResult
    static func request() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Schedules a single local reminder for "the next thing," replacing any
    /// previously scheduled one — only one is ever relevant at a time (next
    /// chapter, or next week's journey), so a fixed identifier means
    /// re-scheduling naturally supersedes the last one rather than stacking.
    /// Returns false if the date is in the past (nothing scheduled) or if the
    /// OS rejects the request; true on success.
    @discardableResult
    static func scheduleNextDropReminder(at date: Date, title: String, body: String) async -> Bool {
        guard date > Date() else { return false }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "laya.nextDrop", content: content, trigger: trigger)
        return (try? await UNUserNotificationCenter.current().add(request)) != nil
    }

    /// The only way to change a *denied* decision is the Settings app —
    /// requestAuthorization silently no-ops once the user has already
    /// answered once.
    @MainActor
    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
