//
//  LayaApp.swift
//  Laya
//
//  Created by Abhi Reddy on 17/06/2026.
//

import SwiftUI
import FirebaseCore
import UIKit
import CoreHaptics
import AudioToolbox

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    LayaFontRegistration.registerAll()

    // TEMP-DEBUG: three architecturally different haptic paths, staggered
    // 2s apart, each with a console marker -- isolates which layer (if any)
    // is actually failing, since UIImpactFeedbackGenerator alone gave us no
    // error to read (it fails silently by design).

    // 1) UIFeedbackGenerator -- already tried, kept as the baseline/control.
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      print("🟠 [1/3] firing raw heavy UIImpactFeedbackGenerator now")
      UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    // 2) CHHapticEngine -- the lower-level API UIFeedbackGenerator is built
    // on. Throwing, so if something is actually denying access we should
    // see a real error here instead of silence.
    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
      let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
      print("🟠 [2/3] CHHapticEngine.capabilitiesForHardware().supportsHaptics = \(supportsHaptics)")
      guard supportsHaptics else { return }
      do {
        let engine = try CHHapticEngine()
        try engine.start()
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        let pattern = try CHHapticPattern(events: [event], parameters: [])
        let player = try engine.makePlayer(with: pattern)
        try player.start(atTime: 0)
        print("🟠 [2/3] CHHapticEngine pattern played without throwing")
      } catch {
        print("🟠 [2/3] CHHapticEngine FAILED: \(error)")
      }
    }

    // 3) AudioServicesPlaySystemSound -- the old pre-Taptic Engine vibration
    // call, routed through AudioToolbox rather than Core Haptics/UIKit at
    // all. Most architecturally distinct of the three.
    DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
      print("🟠 [3/3] firing AudioServicesPlaySystemSound(kSystemSoundID_Vibrate) now")
      AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    return true
  }
}


@main
struct LayaApp: App {
  // register app delegate for Firebase setup
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate


  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
