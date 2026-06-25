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
    // Wake the Taptic Engine before the first real interaction, so the very
    // first button tap doesn't eat the cold-start latency on its own.
    Haptics.warmUp()

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
