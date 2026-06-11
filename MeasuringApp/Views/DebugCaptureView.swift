////
////  DebugCaptureView.swift
////  MeasuringApp
////
////  Created by Atif Khan  on 10/06/2026.
////
//
//import SwiftUI
//import RealityKit
//import AVFoundation
//
//@available(iOS 17.0, *)
//struct DebugCaptureView: View {
//    @Environment(\.dismiss) private var dismiss
//    @State private var imageCount = 0
//    
//    // Kept strictly NIL until completely on-screen
//    @State private var session: ObjectCaptureSession? = nil
//    @State private var currentState: ObjectCaptureSession.CaptureState = .initializing
//    @State private var statusMessage: String = "Waiting for transition..."
//    @State private var trackingTask: Task<Void, Never>? = nil
//    @State private var captureFolder: URL?
//    var body: some View {
//        ZStack {
//            Color.black.ignoresSafeArea()
//
//            if let session = session {
//                ObjectCaptureView(session: session)
//                    .ignoresSafeArea()
//            } else {
//                VStack(spacing: 20) {
//                    ProgressView()
//                        .tint(.white)
//                    Text(statusMessage)
//                        .foregroundColor(.white)
//                }
//            }
//            
//            // HUD controls overlay
//            VStack {
//                HStack {
//                    Button("Close") {
//                        cleanUp()
//                        dismiss()
//                    }
//                    .buttonStyle(.borderedProminent)
//                    .padding()
//                    Spacer()
//                }
//                Spacer()
//                Button("Finish Scan") {
//                    finishScan()
//                }
//                .buttonStyle(.borderedProminent)
//                .padding(.bottom, 10)
//                VStack(alignment: .leading, spacing: 5) {
//
//                    Text("State:")
//                    Text("\(String(describing: currentState))")
//
//                    Divider()
//
//                    Text("Images Saved:")
//                    Text("\(imageCount)")
//
//                    Divider()
//
//                    Text("Folder:")
//                    Text(captureFolder?.lastPathComponent ?? "None")
//
//                }
//                .font(.caption)
//                .padding()
//                .background(.ultraThinMaterial)
//                .cornerRadius(12)
//                .padding(.bottom, 20)
//            }
//        }
//        .onAppear {
//            // Delay initialization until the transition window finishes rendering
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                startCaptureSessionSafely()
//
//                Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
//
//                    guard let folder = captureFolder else { return }
//
//                    let files = (try? FileManager.default.contentsOfDirectory(
//                        at: folder,
//                        includingPropertiesForKeys: nil
//                    )) ?? []
//
//                    imageCount = files.count
//                }
//            }
//        }
//        .onDisappear {
//            cleanUp()
//        }
//    }
//    
//    private func startCaptureSessionSafely() {
//        statusMessage = "Requesting Camera Access..."
//
//        AVCaptureDevice.requestAccess(for: .video) { granted in
//            DispatchQueue.main.async {
//                guard granted else {
//                    self.statusMessage = "Camera access denied."
//                    return
//                }
//
//                // 1. Create a temp directory for captured images
//                let tempDir = FileManager.default.temporaryDirectory
//                    .appendingPathComponent(UUID().uuidString)
//
//                self.captureFolder = tempDir
//                do {
//                    try FileManager.default.createDirectory(
//                        at: tempDir,
//                        withIntermediateDirectories: true
//                    )
//                } catch {
//                    self.statusMessage = "Failed to create capture directory: \(error)"
//                    return
//                }
//
//                self.statusMessage = "Starting capture session..."
//
//                // 2. Create AND start the session
//                let newSession = ObjectCaptureSession()
//                self.session = newSession
//
//                // 3. Start tracking state BEFORE calling start()
//                self.trackingTask = Task {
//                    for await state in newSession.stateUpdates {
//                        await MainActor.run {
//                            self.currentState = state
//                            self.statusMessage = "State: \(String(describing: state))"
//                        }
//                    }
//                }
//
//                // 4. NOW start the session with the directory
//                newSession.start(imagesDirectory: tempDir)
//            }
//        }
//        
//    }
//    private func cleanUp() {
//        trackingTask?.cancel()
//        trackingTask = nil
//        session?.cancel()   // ✅ Tell the session to stop, don't just nil it
//        session = nil
//    }
//    private func finishScan() {
//
//        guard let folder = captureFolder else {
//            statusMessage = "No capture folder found."
//            return
//        }
//
//        session?.finish()
//
//        let images = (try? FileManager.default.contentsOfDirectory(
//            at: folder,
//            includingPropertiesForKeys: nil
//        )) ?? []
//
//        statusMessage = """
//        Scan Complete
//
//        Images Captured:
//        \(images.count)
//
//        Folder:
//        \(folder.lastPathComponent)
//        """
//    }
//}
