import ARKit
import SceneKit

// MARK: - BoundingBox
// The calculated L × W × H from all placed points.

struct BoundingBox {
    let length: Float   // X axis span (metres)
    let width: Float    // Z axis span (metres)
    let height: Float   // Y axis span (metres)

    var volumeM3: Float { length * width * height }

    func formatted() -> (l: String, w: String, h: String) {
        return (
            l: String(format: "%.2f m", length),
            w: String(format: "%.2f m", width),
            h: String(format: "%.2f m", height)
        )
    }
}

// MARK: - MeasurementSession
// All state for one measurement session: points, connecting lines,
// bounding-box calculation, and undo/clear support.

final class MeasurementSession {

    // MARK: Constants
    static let snapRadiusMetres: Float = 0.05   // 5 cm snap-to-first-point radius

    // MARK: State
    private(set) var points: [MeasurementPoint] = []
    private(set) var lineNodes: [SCNNode] = []   // one per segment
    private(set) var isClosed = false

    // MARK: - Adding Points

    /// Adds a new point. Returns whether the shape was auto-closed
    /// (tap was within snap radius of the first point).
    @discardableResult
    func addPoint(_ point: MeasurementPoint) -> Bool {
        guard !isClosed else { return false }

        // Snap-to-close check
        if points.count >= 3, let first = points.first {
            let d = simd_distance(point.worldPosition, first.worldPosition)
            if d <= Self.snapRadiusMetres {
                isClosed = true
                return true   // caller should draw the closing segment
            }
        }

        points.append(point)
        return false
    }

    // MARK: - Segment Information

    /// Returns the two world positions of the latest open segment (last → current),
    /// or nil if there is no previous point to connect to.
    func lastSegment() -> (SIMD3<Float>, SIMD3<Float>)? {
        guard points.count >= 2 else { return nil }
        let a = points[points.count - 2].worldPosition
        let b = points[points.count - 1].worldPosition
        return (a, b)
    }

    /// Closing segment: last point → first point.
    func closingSegment() -> (SIMD3<Float>, SIMD3<Float>)? {
        guard isClosed, let first = points.first, let last = points.last else { return nil }
        return (last.worldPosition, first.worldPosition)
    }

    /// Distance in metres between two world positions.
    static func distance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        simd_distance(a, b)
    }

    // MARK: - Bounding Box

    /// Calculates axis-aligned bounding box from all placed points.
    /// Returns nil if fewer than 2 points exist.
    func boundingBox() -> BoundingBox? {
        guard points.count >= 2 else { return nil }
        let positions = points.map(\.worldPosition)

        let minX = positions.map(\.x).min()!
        let maxX = positions.map(\.x).max()!
        let minY = positions.map(\.y).min()!
        let maxY = positions.map(\.y).max()!
        let minZ = positions.map(\.z).min()!
        let maxZ = positions.map(\.z).max()!

        return BoundingBox(
            length: max(maxX - minX, 0.001),
            width:  max(maxZ - minZ, 0.001),
            height: max(maxY - minY, 0.001)
        )
    }

    // MARK: - Undo & Clear

    /// Removes the last placed point and its associated line node.
    /// Returns the nodes that should be removed from the scene.
    func undoLast() -> (pointNode: SCNNode?, lineNode: SCNNode?) {
        guard !points.isEmpty else { return (nil, nil) }
        isClosed = false
        let pointNode = points.removeLast().node
        let lineNode = lineNodes.isEmpty ? nil : lineNodes.removeLast()
        return (pointNode, lineNode)
    }

    /// Clears everything. Returns all nodes that must be removed from the scene.
    func clear() -> [SCNNode] {
        isClosed = false
        var all: [SCNNode] = points.map(\.node) + lineNodes
        points.removeAll()
        lineNodes.removeAll()
        return all
    }

    // MARK: - Line Node Registration

    func registerLineNode(_ node: SCNNode) {
        lineNodes.append(node)
    }
}
