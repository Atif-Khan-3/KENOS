//
//  HomeView.swift
//  MeasuringApp
//
//  Created by Atif Khan  on 08/06/2026.
//

import SwiftUI

struct HomeView: View {
    @ObservedObject private var prefs = UserPreferencesManager.shared
    var body: some View {
        VStack{
            if let image = prefs.profileImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else {
                            // Placeholder
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.gray)
                                )
                        }
            Text("\(prefs.userName)").bold()

            Button {
                UserPreferencesManager.shared.clearProfile()
            } label: {
                Text("Remove Defaults")
            }
        }

    }
}

#Preview {
    HomeView()
}
