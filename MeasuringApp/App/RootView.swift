//
//  RootView.swift
//  MeasuringApp
//
//  Created by Atif Khan  on 08/06/2026.
//

import Foundation
import SwiftUI

struct RootView: View {
    
    @State private var showSplashScreen = true
    @StateObject var manager = UserPreferencesManager.shared

    var body: some View {
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
                //.transition(.opacity) // Fades out smoothly
                .zIndex(1) // Ensures it stays on top of the app
            }
        }
    }
}
