import ARKit
import SceneKit

// MARK: - MeasurementPoint
// Represents a single tap point anchored in 3D AR world space.

struct MeasurementPoint {
    let id: UUID
    let worldPosition: SIMD3<Float>   // real-world X, Y, Z in metres
    let node: SCNNode                 // the sphere dot rendered in the scene

    init(worldPosition: SIMD3<Float>, node: SCNNode) {
        self.id = UUID()
        self.worldPosition = worldPosition
        self.node = node
    }
}
