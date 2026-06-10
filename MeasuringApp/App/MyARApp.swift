//
//  AppDelegate.swift
//  MeasuringApp
//
//  Created by Atif Khan  on 03/06/2026.
//

import UIKit
import SwiftUI

import SwiftUI

@main
struct MyARApp: App {
    @State private var showSplashScreen = true
    @StateObject var manager = UserPreferencesManager.shared
    var body: some Scene {
        WindowGroup {
            ZStack{
                if !manager.isProfileCreated {
                    ProfileCard(isupdate: false)
                } else {
                    HomeView()
                }
                if showSplashScreen {
                    VideoSplashView {
                        // This closure runs when the video finishes
                        withAnimation(.easeOut(duration: 1.0 )) {
                            showSplashScreen = false
                        }
                    }
                    .transition(.opacity) // Fades out smoothly
                    .zIndex(1) // Ensures it stays on top of the app
                }
            }
        }
    }
}

