//
//  LayaApp.swift
//  Laya
//
//  Created by Abhi Reddy on 17/06/2026.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    LayaFontRegistration.registerAll()
    // Force the lazy singleton to initialize now, not on the first tap, so
    // the haptic engine (and its keep-alive player) is already warm.
    _ = Haptics.shared

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
