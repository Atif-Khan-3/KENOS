import Foundation
import RealityKit
import SwiftData
import Combine

@available(iOS 17.0, *)
@MainActor
class CaptureProcessingService: ObservableObject {
    @Published var isReconstructing = false
    @Published var progressFraction: Double = 0.0
    
    // MARK: - Phase 1: Photogrammetry
    func generate3DModel(from sourceDir: URL) async throws -> URL {
        self.isReconstructing = true
        self.progressFraction = 0.0
        
        defer { self.isReconstructing = false }
        
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("scanned_model_\(UUID().uuidString).usdz")
        
        let session = try PhotogrammetrySession(
            input: sourceDir,
            configuration: PhotogrammetrySession.Configuration()
        )
        
        try session.process(requests: [.modelFile(url: outputURL)])
        
        for try await output in session.outputs {
            switch output {
            case .processingComplete:
                print("DEBUG: Photogrammetry complete")
                return outputURL
            case .requestProgress(_, let fraction):
                self.progressFraction = fraction
            case .requestError(let request, let error):
                print("DEBUG ERROR: \(request) — \(error)")
                throw error
            default:
                break
            }
        }
        
        throw NSError(domain: "CaptureProcessingService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Session completed without output"])
    }
    
    // MARK: - Phase 2: Save to SwiftData
    func finalizeAndSave(tempURL: URL, objectName: String, modelContext: ModelContext) async throws {
        var extractedHeight: Double = 0.0
        var extractedWidth:  Double = 0.0

        do {
            let entity = try await Entity.load(contentsOf: tempURL)
            let bounds = entity.visualBounds(relativeTo: nil)
            extractedWidth  = Double(bounds.extents.x)
            extractedHeight = Double(bounds.extents.y)
        } catch {
            print("DEBUG WARNING: Dimension extraction failed — \(error)")
        }

        let fileManager = FileManager.default
        let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "ScannedObject_\(UUID().uuidString).usdz"
        let destinationURL = documentDirectory.appendingPathComponent(fileName)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: tempURL, to: destinationURL)

        // Delegate thumbnail creation to the dedicated service
        let thumbnailData = await ThumbnailService.generateTransparentThumbnail(for: destinationURL)

        let finalName = objectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Scan" : objectName

        let newScan = ScannedObject(
            name: finalName,
            height: extractedHeight,
            width: extractedWidth,
            scanDate: Date(),
            thumbnailData: thumbnailData,
            modelFilePath: fileName
        )

        modelContext.insert(newScan)
        try modelContext.save()
        print("DEBUG: Saved '\(finalName)' and flushed context to disk.")
    }
}
