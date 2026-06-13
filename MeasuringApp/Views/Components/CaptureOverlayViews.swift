import SwiftUI
import RealityKit

@available(iOS 17.0, *)
struct ReconstructingOverlayView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView("Processing 3D Model...")
                .tint(.white)
                .foregroundColor(.white)
            Text("Please wait while we generate the USDZ file.")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(12)
    }
}

@available(iOS 17.0, *)
struct InitializingOverlayView: View {
    let stateDescription: String
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            Text("Initializing Camera...")
                .font(.headline)
                .foregroundColor(.white)
            Text("State: \(stateDescription)")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

struct DismissCaptureButton: View {
    let action: () -> Void
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: action) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .padding()
                }
            }
            Spacer()
        }
    }
}

