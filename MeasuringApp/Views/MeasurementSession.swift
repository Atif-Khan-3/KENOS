import ARKit
import SceneKit

// MARK: - BoundingBox

struct BoundingBox {
    let length: Float
    let width:  Float
    let height: Float

    func formatted(unit: MeasurementUnit = .meters) -> (l: String, w: String, h: String) {
        (l: unit.format(metres: length),
         w: unit.format(metres: width),
         h: unit.format(metres: height))
    }
}

// MARK: - Segment

struct Segment {
    let indexA: Int
    let indexB: Int
    var lineNode:  SCNNode?
    var labelNode: SCNNode?
}

// MARK: - SnapTarget
// Snap is VISUAL ONLY — does NOT auto-activate any point.
// Activation only happens when the user explicitly presses +.

enum SnapTarget {
    case existingPoint(index: Int, position: SIMD3<Float>)
    case segmentMidpoint(segmentIndex: Int, position: SIMD3<Float>)
    case none
}

// MARK: - MeasurementSession

final class MeasurementSession {

    // MARK: Constants
    static let snapRadius: Float = 0.05   // 5 cm

    // MARK: State
    private(set) var points:   [MeasurementPoint] = []
    private(set) var segments: [Segment]          = []

    /// The index of the "active" point — the one the next + press connects FROM.
    /// nil means no active point (fresh start or line was just completed).
    private(set) var activePointIndex: Int? = nil

    // MARK: - Snap Detection (visual only, call every frame)

    func snapTarget(for cursor: SIMD3<Float>) -> SnapTarget {
        // 1. Existing points
        for (i, p) in points.enumerated() {
            if simd_distance(cursor, p.worldPosition) <= Self.snapRadius {
                return .existingPoint(index: i, position: p.worldPosition)
            }
        }
        // 2. Segment midpoints
        for (si, seg) in segments.enumerated() {
            let a   = points[seg.indexA].worldPosition
            let b   = points[seg.indexB].worldPosition
            let mid = (a + b) * 0.5
            if simd_distance(cursor, mid) <= Self.snapRadius {
                return .segmentMidpoint(segmentIndex: si, position: mid)
            }
        }
        return .none
    }

    // MARK: - Adding a Point (called on + press)
    //
    // Apple Measure app logic:
    //   • 1st press  → place point A, become active (drawing begins)
    //   • 2nd press  → place point B, draw segment A→B, DESELECT (drawing stops)
    //   • To continue → user must aim at an existing point and press + again;
    //                   that press activates it, the NEXT press draws from it.
    //
    // Snap-to-existing-point behaviour:
    //   • If snapping to an existing point and there IS an active point  →
    //     complete a segment to that point, then deselect.
    //   • If snapping to an existing point and there is NO active point  →
    //     activate that point (so user can draw FROM it next press).

    @discardableResult
    func addPoint(
        _ point: MeasurementPoint,
        snapTarget: SnapTarget
    ) -> (pointIndex: Int, segmentCreated: Bool) {

        switch snapTarget {

        // ── Snap to an existing point ──────────────────────────────────────
        case .existingPoint(let index, _):
            if let active = activePointIndex, active != index {
                // Complete segment → existing point, then stop
                segments.append(Segment(indexA: active, indexB: index))
                activePointIndex = nil          // drawing stops
                return (index, true)
            } else {
                // No active point → activate this existing point
                // (next + press will draw FROM here)
                activePointIndex = index
                return (index, false)
            }

        // ── Snap to segment midpoint ───────────────────────────────────────
        case .segmentMidpoint(let si, _):
            let newIndex = insertMidpoint(point, intoSegment: si)
            if let active = activePointIndex, active != newIndex {
                segments.append(Segment(indexA: active, indexB: newIndex))
                activePointIndex = nil
                return (newIndex, true)
            } else {
                activePointIndex = newIndex
                return (newIndex, false)
            }

        // ── Fresh point in empty space ─────────────────────────────────────
        case .none:
            points.append(point)
            let newIndex = points.count - 1

            if let active = activePointIndex, active != newIndex {
                // Second (or later) press in a chain → complete segment, stop
                segments.append(Segment(indexA: active, indexB: newIndex))
                activePointIndex = nil          // drawing stops after segment
                return (newIndex, true)
            } else {
                // First press → just activate
                activePointIndex = newIndex
                return (newIndex, false)
            }
        }
    }

    // MARK: - Insert midpoint into an existing segment

    private func insertMidpoint(_ point: MeasurementPoint, intoSegment si: Int) -> Int {
        let seg      = segments[si]
        let newIndex = points.count
        points.append(point)
        segments.remove(at: si)
        segments.insert(Segment(indexA: seg.indexA, indexB: newIndex), at: si)
        segments.insert(Segment(indexA: newIndex,   indexB: seg.indexB), at: si + 1)
        return newIndex
    }

    // MARK: - Register nodes on a segment

    func registerNodes(lineNode: SCNNode, labelNode: SCNNode, forSegmentAt index: Int) {
        guard index < segments.count else { return }
        segments[index].lineNode  = lineNode
        segments[index].labelNode = labelNode
    }

    // MARK: - Update just the label node (used when the user changes units)

    func updateLabelNode(_ labelNode: SCNNode, forSegmentAt index: Int) {
        guard index < segments.count else { return }
        segments[index].labelNode = labelNode
    }

    // MARK: - Deselect (stop drawing)

    func deselect() {
        activePointIndex = nil
    }

    // MARK: - Undo last segment

    func undoLastSegment() -> (lineNode: SCNNode?, labelNode: SCNNode?, orphanPoint: SCNNode?) {
        guard let last = segments.last else {
            if let p = points.popLast() {
                activePointIndex = points.indices.last
                return (nil, nil, p.node)
            }
            return (nil, nil, nil)
        }

        let removed  = segments.removeLast()
        let indexB   = removed.indexB
        let stillUsed = segments.contains { $0.indexA == indexB || $0.indexB == indexB }
        var orphan: SCNNode? = nil
        if !stillUsed && indexB == points.count - 1 {
            orphan = points.removeLast().node
        }

        activePointIndex = segments.last.map { $0.indexB } ?? points.indices.last
        return (removed.lineNode, removed.labelNode, orphan)
    }

    // MARK: - Clear everything

    func clear() -> [SCNNode] {
        var nodes: [SCNNode] = points.map(\.node)
        for seg in segments {
            if let l = seg.lineNode  { nodes.append(l) }
            if let l = seg.labelNode { nodes.append(l) }
        }
        points.removeAll()
        segments.removeAll()
        activePointIndex = nil
        return nodes
    }

    // MARK: - Helpers

    static func distance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        simd_distance(a, b)
    }

    func boundingBox() -> BoundingBox? {
        guard points.count >= 2 else { return nil }
        let p = points.map(\.worldPosition)
        return BoundingBox(
            length: (p.map(\.x).max()! - p.map(\.x).min()!),
            width:  (p.map(\.z).max()! - p.map(\.z).min()!),
            height: (p.map(\.y).max()! - p.map(\.y).min()!)
        )
    }
}
