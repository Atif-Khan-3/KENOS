//
//  RootView.swift
//  MeasuringApp
//
//  Created by Atif Khan  on 08/06/2026.
//

import Foundation
import SwiftUI

struct RootView: View {

  
   @StateObject var manager = UserPreferencesManager.shared

    var body: some View {
        if !manager.isProfileCreated {
            ProfileCard(isupdate: false)
        } else {
            HomeView()
        }
    }
}
