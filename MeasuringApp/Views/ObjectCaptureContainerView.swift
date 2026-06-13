import SwiftUI
import RealityKit
import SwiftData
import AVFoundation

@available(iOS 17.0, *)
struct ObjectCaptureContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.scenePhase)   private var scenePhase

    // Manage both services
    @StateObject private var cameraManager = CaptureManager()
    @StateObject private var processingService = CaptureProcessingService()

    @State private var showNamePrompt   = false
    @State private var objectName       = ""
    @State private var tempModelURL: URL? = nil
    @State private var sessionState: ObjectCaptureSession.CaptureState = .initializing
    @State private var stateObserverTask: Task<Void, Never>? = nil
    @State private var activeCaptureDir: URL? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if processingService.isReconstructing {
                reconstructingView
            } else if let session = cameraManager.session {
                ObjectCaptureView(session: session)

                if sessionState == .initializing {
                    Color.black.opacity(0.4).ignoresSafeArea()
                        .overlay { initializingView }
                }

                VStack {
                    Spacer()
                    captureControls(session: session)
                }
                .padding(.bottom, 50)
            } else {
                initializingView
            }

            dismissButton
        }
        .onAppear {
            if scenePhase == .active { requestCameraPermissionThenStart() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && cameraManager.session == nil && !processingService.isReconstructing {
                requestCameraPermissionThenStart()
            }
        }
        .onDisappear {
            stateObserverTask?.cancel()
            cameraManager.tearDownSession()
        }
        .alert("Save Scanned Object", isPresented: $showNamePrompt) {
            TextField("Enter object name", text: $objectName)
            Button("Save") {
                Task {
                    if let url = tempModelURL {
                        try? await processingService.finalizeAndSave(tempURL: url, objectName: objectName, modelContext: modelContext)
                    }
                    dismiss()
                }
            }
            Button("Discard", role: .cancel) {
                if let tempURL = tempModelURL { try? FileManager.default.removeItem(at: tempURL) }
                dismiss()
            }
        } message: {
            Text("Give your newly scanned 3D model a name.")
        }
    }

    // MARK: - Capture Controls

    @ViewBuilder
    private func captureControls(session: ObjectCaptureSession) -> some View {
        switch sessionState {
        case .ready:
            Button("Detect Object") { session.startDetecting() }
                .buttonStyle(.borderedProminent)

        case .detecting:
            Button("Start Capture") { session.startCapturing() }
                .buttonStyle(.borderedProminent).tint(.orange)

        case .capturing:
            Button("Finish & Process") {
                session.finish()
                cameraManager.tearDownSession()
                stateObserverTask?.cancel()
                
                // Trigger the external processing service
                if let sourceDir = activeCaptureDir {
                    Task {
                        do {
                            tempModelURL = try await processingService.generate3DModel(from: sourceDir)
                            showNamePrompt = true
                        } catch {
                            print("DEBUG ERROR: Photogrammetry failed — \(error)")
                        }
                    }
                }
            }
            .buttonStyle(.borderedProminent).tint(.green)

        default: EmptyView()
        }
    }

    // MARK: - Camera & Observer Logic
    
    private func requestCameraPermissionThenStart() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                guard granted, self.cameraManager.session == nil else { return }
                
                let dir = FileManager.default.temporaryDirectory.appendingPathComponent("CaptureSession_\(UUID().uuidString)/")
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                self.activeCaptureDir = dir
                
                self.cameraManager.initializeSession(captureDir: dir)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.startStateObserver() }
            }
        }
    }

    private func startStateObserver() {
        guard let session = cameraManager.session else { return }
        sessionState = session.state
        
        stateObserverTask = Task {
            for await newState in session.stateUpdates {
                await MainActor.run { sessionState = newState }
                if case .completed = newState { return }
                if case .failed(_) = newState { return }
            }
        }
    }

    // MARK: - Subviews
    
    private var reconstructingView: some View {
        VStack(spacing: 16) {
            ProgressView("Processing 3D Model... \(Int(processingService.progressFraction * 100))%")
                .tint(.white).foregroundColor(.white)
            Text("Please wait while we generate the USDZ file.")
                .font(.caption).foregroundColor(.gray)
        }
        .padding().background(Color.black.opacity(0.8)).cornerRadius(12)
    }

    private var initializingView: some View {
        VStack(spacing: 20) {
            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(1.5)
            Text("Initializing Camera...").font(.headline).foregroundColor(.white)
        }
    }

    private var dismissButton: some View {
        VStack {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").font(.largeTitle).foregroundColor(.white).padding()
                }
            }
            Spacer()
        }
    }
}
