# KENOS

KENOS is an iOS AR measuring and object-capture application built with SwiftUI, ARKit, RealityKit, and SwiftData. The app combines two core workflows:

- AR ruler mode for measuring real-world distances with surface snapping and unit conversion.
- Object Capture mode for scanning physical objects into USDZ models, generating thumbnails, and previewing them in AR.

## Table of Contents

- Overview
- Key Features
- Product Flow
- Architecture
- Tech Stack
- Project Structure
- Requirements
- Getting Started
- Configuration and Permissions
- Data Model
- Troubleshooting
- Roadmap
- Contributing

## Overview

KENOS is designed to help users quickly measure spaces and objects, then move from dimensions to reusable 3D assets. It provides:

- A profile-based home experience with scanned object history.
- Real-time AR line measurement with snap-to-point and snap-to-midpoint interactions.
- On-device photogrammetry pipeline for generating USDZ files from captured images.
- Saved scans with metadata (name, dimensions, date), persistent model paths, and generated thumbnails.
- AR placement mode for viewing and manipulating scanned objects on detected horizontal planes.

## Key Features

### 1) AR Measurement (Ruler Mode)

- Plane-aware cursor and surface-aligned crosshair.
- Point placement workflow similar to Apple Measure:
	- First tap creates an active point.
	- Next tap creates a segment.
	- Users can continue by re-selecting an existing point.
- Visual snapping:
	- Existing measurement points.
	- Segment midpoints.
- Multi-unit support:
	- Meters, centimeters, millimeters, feet, inches, yards.
- Actions:
	- Add point, undo last segment, clear all.

### 2) Object Capture (iOS 17+)

- Uses Object Capture session for guided image acquisition.
- Processes captures into USDZ using PhotogrammetrySession.
- Auto-extracts rough width/height from model bounds.
- Stores model in app documents directory.
- Generates transparent thumbnail previews with QuickLook + Vision foreground masking.

### 3) AR Preview for Scanned Objects

- Tap to place the model on a detected horizontal surface.
- One-finger drag to reposition.
- Rotation gesture to orient model.
- Displays object name and saved dimensions in an on-screen bottom HUD.

### 4) User and Library Experience

- First-run profile creation flow.
- Editable profile name and image.
- Searchable scan library (by object name).
- Grid-based object cards with dimensions and thumbnails.

## Product Flow

1. Create profile on first launch.
2. Open home dashboard with scanned object library.
3. Choose mode from the action menu:
	 - Ruler Mode for measurements.
	 - Capture Mode for 3D scanning.
4. Save captured model with an object name.
5. Select any saved object from home to open AR preview.

## Architecture

The app follows a modular feature-oriented structure.

- App layer:
	- SwiftUI entry and root navigation.
- Views layer:
	- Home, profile, capture container, AR preview, measurement HUD.
- Manager layer:
	- Capture lifecycle manager.
	- User preferences manager.
- Services layer:
	- Photogrammetry processing and persistence.
	- Thumbnail generation.
- Model layer:
	- SwiftData entity for scanned objects.
	- Measurement session models for points, segments, and units.

## Tech Stack

- Language: Swift
- UI: SwiftUI + UIKit bridging where required
- AR and 3D: ARKit, RealityKit, ObjectCapture
- Data Persistence: SwiftData
- Media and Imaging: AVFoundation, QuickLookThumbnailing, Vision, CoreImage
- Platform target: iOS (Object Capture paths require iOS 17+)

## Project Structure

```text
KENOS/
├─ MeasuringApp/
│  ├─ App/
│  ├─ Manager/
│  ├─ Model/
│  ├─ Services/
│  ├─ Views/
│  └─ Resources/
└─ MeasuringApp.xcodeproj/
```

## Requirements

- macOS with latest stable Xcode installed.
- iOS 17.0+ for Object Capture flow.
- Physical iPhone device recommended for AR features.
- For best Object Capture performance, a LiDAR-capable device is recommended.

## Getting Started

1. Clone this repository.
2. Open the project in Xcode:

	 ```bash
	 open MeasuringApp.xcodeproj
	 ```

3. Select an iOS device target.
4. Build and run.
5. On first launch:
	 - Create profile.
	 - Grant camera access when prompted.

## Configuration and Permissions

The project is configured with camera usage description for AR and object capture workflows.

If you add new media workflows, also consider adding relevant photo-library permission keys in project settings.

## Data Model

Primary persisted entity: ScannedObject

- id: unique identifier.
- name: user-defined object name.
- height, width: extracted dimensions from model bounds.
- scanDate: capture save timestamp.
- thumbnailData: external storage thumbnail payload.
- modelFilePath: relative documents path to USDZ file.

## Troubleshooting

### Object Capture button does not open

- Verify device runs iOS 17 or newer.
- Confirm camera access is granted in iOS Settings.
- Test on supported hardware.

### AR placement is unstable

- Move device slowly to improve tracking.
- Ensure adequate lighting and textured surfaces.
- Avoid highly reflective or featureless environments.

### Scan appears in list but model fails to load

- Confirm file exists in app documents directory.
- Retry capture and save flow.
- Check free storage and processing completion.

## Roadmap

- Re-enable pinch scaling with robust gesture arbitration.
- Add export/share options for USDZ assets.
- Add measurement history persistence.
- Add automated tests for model persistence and conversion utilities.

## Contributing

1. Create a feature branch.
2. Make focused, atomic commits.
3. Open a pull request with:
	 - Summary of behavior changes.
	 - Screenshots or recordings for UI/AR changes.
	 - Notes on device and iOS version used for testing.
