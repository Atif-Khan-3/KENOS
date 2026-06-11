import SwiftUI
import RealityKit
import SwiftData
import AVFoundation
import Combine
import QuickLookThumbnailing
// MARK: - Helpers
private func str(_ uuid: UUID) -> String {
    return uuid.uuidString
}

// MARK: - CaptureManager

@available(iOS 17.0, *)
class CaptureManager: ObservableObject {
    @Published var session: ObjectCaptureSession?
    @Published var isReconstructing = false

    func initializeSession(captureDir: URL) {
        guard self.session == nil else {
            print("DEBUG: Session already exists, skipping init")
            return
        }

        print("DEBUG: Creating new ObjectCaptureSession")
        let session = ObjectCaptureSession()
        self.session = session

        session.start(imagesDirectory: captureDir)
        print("DEBUG: Session started, initial state: \(session.state)")
    }

    /// Explicit cleanup to immediately recover system memory
    func tearDownSession() {
        print("DEBUG: Force tearing down camera session pipeline")
        session?.cancel()
        session = nil
    }
    
    deinit {
        print("DEBUG: CaptureManager deinit")
        let s = session
        Task { @MainActor in
            s?.cancel()
        }
    }
}


@available(iOS 17.0, *)
struct ObjectCaptureContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var manager = CaptureManager()

    @State private var showNamePrompt   = false
    @State private var objectName       = ""
    @State private var tempModelURL: URL? = nil
    @State private var sessionState: ObjectCaptureSession.CaptureState = .initializing
    @State private var stateObserverTask: Task<Void, Never>? = nil

    @State private var activeCaptureDir: URL? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if manager.isReconstructing {
                reconstructingView
            } else if let session = manager.session {
                // Render view when session is ready
                ObjectCaptureView(session: session)

                // Loading overlay on top while still initializing
                if sessionState == .initializing {
                    Color.black.opacity(0.4).ignoresSafeArea() // ✅ Let the camera feed show!
                        .overlay {
                            initializingView
                        }
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
            if scenePhase == .active {
                requestCameraPermissionThenStart()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && manager.session == nil && !manager.isReconstructing {
                requestCameraPermissionThenStart()
            }
        }
        .onDisappear {
            print("DEBUG: View disappeared — cleaning up")
            stateObserverTask?.cancel()
            stateObserverTask = nil
            manager.tearDownSession()
        }
        .alert("Save Scanned Object", isPresented: $showNamePrompt) {
            TextField("Enter object name", text: $objectName)
            Button("Save") {
                print("DEBUG: Save tapped — name: '\(objectName)'")
                Task { await finalizeAndSave() }
            }
            Button("Discard", role: .cancel) {
                print("DEBUG: Discard tapped")
                if let tempURL = tempModelURL {
                    try? FileManager.default.removeItem(at: tempURL)
                }
                dismiss()
            }
        } message: {
            Text("Give your newly scanned 3D model a name.")
        }
    }

    // MARK: - State Description

    private var stateDescription: String {
        switch sessionState {
        case .initializing:      return "initializing"
        case .ready:             return "ready"
        case .detecting:         return "detecting"
        case .capturing:         return "capturing"
        case .finishing:         return "finishing"
        case .completed:         return "completed"
        case .failed(let e):     return "failed: \(e)"
        default:                 return "unknown"
        }
    }

    // MARK: - Camera Permission + Session Start

    private func requestCameraPermissionThenStart() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                guard granted else {
                    print("DEBUG ERROR: Camera permission DENIED")
                    return
                }
                
                guard self.manager.session == nil else { return }
                print("DEBUG: Camera permission granted")

                let dir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("CaptureSession_\(str(UUID()))/")
                
                self.activeCaptureDir = dir
                self.setupCaptureDirectory(at: dir)
                self.manager.initializeSession(captureDir: dir)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.startStateObserver()
                }
            }
        }
    }

    // MARK: - State Observer

    private func startStateObserver() {
        guard let session = manager.session else {
            print("DEBUG ERROR: Cannot start observer — session is nil")
            return
        }
        sessionState = session.state

        print("DEBUG: Starting stateUpdates observer")

        stateObserverTask = Task {
            for await newState in session.stateUpdates {
                print("DEBUG: New state — \(newState)")

                await MainActor.run {
                    sessionState = newState
                }

                switch newState {
                case .completed:
                    print("DEBUG: Session completed loop safely")
                    return

                case .failed(let error):
                    print("DEBUG ERROR: Session failed — \(error)")
                    return

                default:
                    break
                }
            }
        }
    }

    // MARK: - Capture Controls

    @ViewBuilder
    private func captureControls(session: ObjectCaptureSession) -> some View {
        switch sessionState {

        case .ready:
            Button("Detect Object") {
                print("DEBUG: Starting object detection")
                session.startDetecting()
            }
            .buttonStyle(.borderedProminent)

        case .detecting:
            Button("Start Capture") {
                print("DEBUG: Object confirmed, starting capture")
                session.startCapturing()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)

        case .capturing:
            Button("Finish & Process") {
                print("DEBUG: Finishing capture loop")
                session.finish()
                
                // ✅ FIX: Kill the camera session layer IMMEDIATELY on the main thread
                // to free up allocations before initiating photogrammetry processing.
                self.manager.tearDownSession()
                self.stateObserverTask?.cancel()
                self.stateObserverTask = nil
                
                // Fire processing engine after memory layout drops camera pipeline
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.processCapture()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)

        default:
            EmptyView()
        }
    }

    // MARK: - Subviews

    private var reconstructingView: some View {
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

    private var initializingView: some View {
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

    private var dismissButton: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    print("DEBUG: Dismiss tapped")
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .padding()
                }
            }
            Spacer()
        }
    }

    // MARK: - Directory Setup

    private func setupCaptureDirectory(at url: URL) {
        do {
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true
            )
            print("DEBUG: Capture directory ready — \(url)")
        } catch {
            print("DEBUG ERROR: Failed to create capture dir — \(error)")
        }
    }

    private func generateThumbnail(for url: URL, size: CGSize = CGSize(width: 300, height: 300)) async -> Data? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: UIScreen.main.scale,
            representationTypes: .thumbnail
        )
        
        do {
            let generator = QLThumbnailGenerator.shared
            let thumbnail = try await generator.generateBestRepresentation(for: request)
            // Convert the resulting UIImage to Data (JPEG at 80% quality is usually a good balance of size and fidelity)
            return thumbnail.uiImage.jpegData(compressionQuality: 0.8)
        } catch {
            print("DEBUG ERROR: Failed to generate thumbnail — \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Photogrammetry

    private func processCapture() {
        guard let sourceDir = activeCaptureDir else {
            print("DEBUG ERROR: No active capture directory found.")
            return
        }
        
        manager.isReconstructing = true
        print("DEBUG: Photogrammetry started calculation pipeline")

        Task {
            do {
                let outputURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("scanned_model_\(str(UUID())).usdz")

                print("DEBUG: Output path — \(outputURL)")

                let photogrammetrySession = try PhotogrammetrySession(
                    input: sourceDir,
                    configuration: PhotogrammetrySession.Configuration()
                )

                try photogrammetrySession.process(
                    requests: [.modelFile(url: outputURL)]
                )

                for try await output in photogrammetrySession.outputs {
                    switch output {
                    case .processingComplete:
                        print("DEBUG: Photogrammetry complete")
                        await MainActor.run {
                            self.tempModelURL  = outputURL
                            self.showNamePrompt = true
                            self.manager.isReconstructing = false
                        }
                    case .requestError(let request, let error):
                        print("DEBUG ERROR: \(request) — \(error)")
                        await MainActor.run { self.manager.isReconstructing = false }
                    case .requestProgress(_, let fraction):
                        print("DEBUG: Progress — \(Int(fraction * 100))%")
                    default:
                        break
                    }
                }
            } catch {
                print("DEBUG ERROR: PhotogrammetrySession — \(error)")
                await MainActor.run { self.manager.isReconstructing = false }
            }
        }
    }

    // MARK: - Save

    @MainActor
    private func finalizeAndSave() async {
        guard let tempURL = tempModelURL else {
            print("DEBUG ERROR: tempModelURL is nil")
            return
        }

        var extractedHeight: Double = 0.0
        var extractedWidth:  Double = 0.0

        do {
            let entity = try await Entity.load(contentsOf: tempURL)
            let bounds = entity.visualBounds(relativeTo: nil)
            extractedWidth  = Double(bounds.extents.x)
            extractedHeight = Double(bounds.extents.y)
            print("DEBUG: Dimensions — width: \(extractedWidth) height: \(extractedHeight)")
        } catch {
            print("DEBUG WARNING: Dimension extraction failed — \(error)")
        }

        let fileManager      = FileManager.default
        let documentDirectory = fileManager.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first!
        let fileName         = "ScannedObject_\(str(UUID())).usdz"
        let destinationURL   = documentDirectory.appendingPathComponent(fileName)

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: tempURL, to: destinationURL)

            let finalName = objectName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty ? "Untitled Scan" : objectName
            let thumbnailData = await generateThumbnail(for: destinationURL)
            let newScan = ScannedObject(
                name: finalName,
                height: extractedHeight,
                width: extractedWidth,
                scanDate: Date(),
                thumbnailData: thumbnailData,
                modelFilePath: fileName
            )

            modelContext.insert(newScan)
            print("DEBUG: Saved '\(finalName)' to SwiftData")

        } catch {
            print("DEBUG ERROR: Save failed — \(error)")
        }

        dismiss()
    }
}
