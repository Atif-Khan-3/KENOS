//  UserPreferencesManager.swift
//  MeasuringApp
//
//  Created by Atif Khan on 08/06/2026.

import Foundation
import Combine
import UIKit

// MARK: - UserPreferencesManager

final class UserPreferencesManager: ObservableObject {

    static let shared = UserPreferencesManager()
    private init() {}

    private enum Keys {
        static let isProfileCreated = "isProfileCreated"
        static let userName        = "userName"
        static let profileImagePath = "profileImagePath"
    }

    @Published var userName: String = UserDefaults.standard.string(forKey: Keys.userName) ?? "" {
        didSet { UserDefaults.standard.set(userName, forKey: Keys.userName) }
    }

    @Published var profileImagePath: String = UserDefaults.standard.string(forKey: Keys.profileImagePath) ?? "" {
        didSet { UserDefaults.standard.set(profileImagePath, forKey: Keys.profileImagePath) }
    }

    @Published var isProfileCreated: Bool = UserDefaults.standard.bool(forKey: Keys.isProfileCreated) {
        didSet { UserDefaults.standard.set(isProfileCreated, forKey: Keys.isProfileCreated) }
    }

    // MARK: - Computed helper (no extra storage needed)
    var profileImage: UIImage? {
        guard !profileImagePath.isEmpty else { return nil }
        return ImageStorageManager.shared.loadImage(fileName: profileImagePath)
    }

    // MARK: - Update image
    func updateProfileImage(image: UIImage) {
        let oldPath = profileImagePath          // ✅ read from own @Published, not a missing static method

        if let fileName = ImageStorageManager.shared.saveProfileImage(image: image) {
            // Delete old file only if name changed (dynamic names)
            if !oldPath.isEmpty && oldPath != fileName {
                ImageStorageManager.shared.deleteImage(fileName: oldPath)
            }
            profileImagePath = fileName         // ✅ write back through own @Published
        }
    }

    // MARK: - Clear
    func clearProfile() {
        if !profileImagePath.isEmpty {
            ImageStorageManager.shared.deleteImage(fileName: profileImagePath)
        }
        userName        = ""
        profileImagePath = ""
        isProfileCreated = false
    }
}

// MARK: - ImageStorageManager

final class ImageStorageManager {

    static let shared = ImageStorageManager()
    private init() {}

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: Save / overwrite
    func saveProfileImage(image: UIImage, fileName: String = "profile.jpg") -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let fileURL = documentsURL.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileName
        } catch {
            print("Image save error:", error)
            return nil
        }
    }

    // MARK: Delete
    func deleteImage(fileName: String) {
        let fileURL = documentsURL.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    // MARK: Load
    func loadImage(fileName: String) -> UIImage? {
        let fileURL = documentsURL.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
}
