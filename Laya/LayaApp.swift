//
//  LayaApp.swift
//  Laya
//
//  Created by Abhi Reddy on 17/06/2026.
//

import SwiftUI
import FirebaseCore
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    LayaFontRegistration.registerAll()

    // TEMP-DEBUG: most primitive possible haptic test -- no SwiftUI state,
    // no .task, no view hierarchy, no scene timing theories. If this still
    // doesn't fire on device while the Home Screen long-press does, the
    // issue is specific to this app process, not SwiftUI usage.
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      print("🟠 Laya debug: firing raw heavy impact haptic now")
      UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
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
