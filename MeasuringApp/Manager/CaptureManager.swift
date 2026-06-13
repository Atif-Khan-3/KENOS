//
//  CaptureManager.swift
//  MeasuringApp
//
//  Created by Hussnain on 13/6/26.
//


import Foundation
import RealityKit
import Combine
import _RealityKit_SwiftUI

@available(iOS 17.0, *)
class CaptureManager: ObservableObject {
    @Published var session: ObjectCaptureSession?

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
