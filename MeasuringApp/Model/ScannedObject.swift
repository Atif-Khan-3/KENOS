//
//  ScannedObject.swift
//  MeasuringApp
//
//  Created by Atif Khan  on 09/06/2026.
//
import Foundation
import SwiftData

@Model
final class ScannedObject {
    @Attribute(.unique) var id: UUID
    var name: String
    var height: Double
    var width: Double
    var scanDate: Date
    
    // Thumbnail handled via SwiftData's external storage
    @Attribute(.externalStorage) var thumbnailData: Data?
    
    // 3D Model handled via file system path
    var modelFilePath: String?
    
    init(
        id: UUID = UUID(),
        name: String,
        height: Double,
        width: Double,
        scanDate: Date = Date(),
        thumbnailData: Data? = nil,
        modelFilePath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.height = height
        self.width = width
        self.scanDate = scanDate
        self.thumbnailData = thumbnailData
        self.modelFilePath = modelFilePath
    }
    
    // Helper to dynamically get the full URL when needed for RealityKit / QuickLook
    @Transient
    var modelURL: URL? {
        guard let path = modelFilePath else { return nil }
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentsDirectory?.appendingPathComponent(path)
    }
}
