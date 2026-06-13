import Foundation
import QuickLookThumbnailing
import Vision
import CoreImage
import UIKit

@available(iOS 17.0, *)
enum ThumbnailService {
    
    @MainActor
    static func generateTransparentThumbnail(for url: URL, size: CGSize = CGSize(width: 300, height: 300)) async -> Data? {
        let request = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: UIScreen.main.scale, representationTypes: .thumbnail)
        
        do {
            let thumbnail = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            let uiImage = thumbnail.uiImage
            
            guard let cgImage = uiImage.cgImage else { return uiImage.pngData() }
            let visionRequest = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            try handler.perform([visionRequest])
            guard let result = visionRequest.results?.first else { return uiImage.pngData() }
            
            let maskPixelBuffer = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
            let maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)
            let inputImage = CIImage(cgImage: cgImage)
            
            guard let blendFilter = CIFilter(name: "CIBlendWithMask") else { return uiImage.pngData() }
            
            blendFilter.setValue(inputImage, forKey: kCIInputImageKey)
            blendFilter.setValue(maskImage, forKey: kCIInputMaskImageKey)
            
            let clearBackground = CIImage(color: .clear).cropped(to: inputImage.extent)
            blendFilter.setValue(clearBackground, forKey: kCIInputBackgroundImageKey)
            
            let context = CIContext()
            if let outputCIImage = blendFilter.outputImage,
               let finalCGImage = context.createCGImage(outputCIImage, from: outputCIImage.extent) {
                return UIImage(cgImage: finalCGImage).pngData()
            }
            
            return uiImage.pngData()
        } catch {
            print("DEBUG ERROR: Thumbnail generation failed — \(error)")
            return nil
        }
    }
}
