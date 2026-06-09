//
//  VideoSplashView.swift
//  Optix-Person_Tracker_for_Homes-iOS
//
//  Created by Hussnain on 17/2/26.
//

import SwiftUI
import AVKit

// MARK: - 1. The Custom Cover View (Mimics Frame 0)
struct SplashCoverView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()
        }
    }
}

// MARK: - 2. The Main Video Splash
struct VideoSplashView: View {
    
    @Environment(\.colorScheme) var colorScheme
    var onAnimationFinished: () -> Void
    
    @State private var player: AVPlayer?
    @State private var showCover = true // Controls the cover visibility
    
    var body: some View {
        ZStack {
            // Layer A: Background Color (Safety net)
            // FIX: Use ternary operator directly for Color
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()
            
            // Layer B: Video Player
            if let player = player {
                VideoPlayer(player: player)
                    .disabled(true)
                    .aspectRatio(contentMode: .fit)
                    .ignoresSafeArea()
                    .onAppear {
                        player.play()
                        
                        // Wait 0.2s for video to render, then remove cover
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            withAnimation(.easeOut(duration: 0.2)) {
                                showCover = false
                            }
                        }
                    }
            }
            
            // Layer C: The "Cover Up" (Sits on top)
            if showCover {
                SplashCoverView()
                    .transition(.opacity)
                    .zIndex(2) // Forces it to sit on top of the video
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { _ in
            withAnimation(.linear(duration: 0.5)) {
                onAnimationFinished()
            }
        }
    }
    
    func setupPlayer() {
        // Note: I removed the file extension here so we can check both .mp4 and .mov below
        let videoName = colorScheme == .dark ? "kenos_dark" : "kenos_light"
        
        // Check for .mp4 first, then .mov
        var url = Bundle.main.url(forResource: videoName, withExtension: "mp4")
        
        if url == nil {
            url = Bundle.main.url(forResource: videoName, withExtension: "mov")
        }
        
        guard let finalUrl = url else {
            print("Video \(videoName) not found! Check your filename and Target Membership.")
            onAnimationFinished()
            return
        }
        
        let player = AVPlayer(url: finalUrl)
        player.isMuted = true
        self.player = player
    }
}

#Preview {
    VideoSplashView {
        print("Done")
    }
}
