import UIKit
import SwiftUI
import ARKit
import SceneKit

final class MeasureViewController: UIViewController {
    
    // MARK: - Subviews
    private let sceneView = ARSCNView()
    private let hud       = MeasureHUDHostingController()
    
    // MARK: - State
    private let session   = MeasurementSession()
    private var crosshair = SceneBuilder.makeCrosshairNode()
    private var snapRing  = SceneBuilder.makeSnapRingNode()
    
    // Live preview nodes (line + label from active point → cursor)
    private var liveLineNode:  SCNNode?
    private var liveLabelNode: SCNNode?
    
    // Current cursor world position (updated every frame)
    private var cursorPosition: SIMD3<Float>?
    
    // Current snap state (visual only — updated every frame, consumed on + press)
    // NOTE: This does NOT activate any point. Activation only happens on + press.
    private var currentSnap: SnapTarget = .none

    // Currently selected display unit. Always starts at meters when the
    // screen opens — intentionally not persisted between sessions.
    private var currentUnit: MeasurementUnit = .meters
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSceneView()
        setupHUD()
        addPermanentNodes()
        updateHUD()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection       = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    // MARK: - Setup
    
    private func setupSceneView() {
        sceneView.frame                      = view.bounds
        sceneView.autoresizingMask           = [.flexibleWidth, .flexibleHeight]
        sceneView.delegate                   = self
        sceneView.session.delegate           = self
        sceneView.autoenablesDefaultLighting = true
        sceneView.antialiasingMode           = .multisampling4X
        view.addSubview(sceneView)
    }
    
    private func setupHUD() {
        addChild(hud)
        hud.view.translatesAutoresizingMaskIntoConstraints = false
        hud.view.backgroundColor = .clear
        view.addSubview(hud.view)
        hud.didMove(toParent: self)
        
        NSLayoutConstraint.activate([
            hud.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hud.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hud.view.topAnchor.constraint(equalTo: view.topAnchor),
            hud.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        hud.onAdd        = { [weak self] in self?.placePoint() }
        hud.onUndo       = { [weak self] in self?.undoLast() }
        hud.onClear      = { [weak self] in self?.clearAll() }
        hud.onUnitChange = { [weak self] unit in self?.changeUnit(to: unit) }
    }
    
    private func addPermanentNodes() {
        sceneView.scene.rootNode.addChildNode(crosshair)
        sceneView.scene.rootNode.addChildNode(snapRing)
        snapRing.isHidden = true
    }
    
    private func placePoint() {
        guard let worldPos = cursorPosition else { return }
        
        // Resolve the actual world position from snap or raw cursor
        let finalPos: SIMD3<Float>
        switch currentSnap {
        case .existingPoint(_, let pos):   finalPos = pos
        case .segmentMidpoint(_, let pos): finalPos = pos
        case .none:                         finalPos = worldPos
        }
        
        // Create a dot node (may be hidden later if snapping to existing point)
        let dotNode = SceneBuilder.makeDotNode(at: finalPos)
        sceneView.scene.rootNode.addChildNode(dotNode)
        let point = MeasurementPoint(worldPosition: finalPos, node: dotNode)
        
        // Hand off to session — it decides active state, segment creation, etc.
        let result = session.addPoint(point, snapTarget: currentSnap)
        
        // Hide the dot if we snapped to an already-existing point
        if case .existingPoint = currentSnap {
            dotNode.isHidden = true
        }
        
        // Draw permanent line + label if a new segment was created
        if result.segmentCreated, let seg = session.segments.last {
            let a    = session.points[seg.indexA].worldPosition
            let b    = session.points[seg.indexB].worldPosition
            let dist = MeasurementSession.distance(a, b)
            
            let lineNode  = SceneBuilder.makeLineNode(from: a, to: b)
            let labelNode = SceneBuilder.makeLabelNode(between: a, and: b, distanceMetres: dist, unit: currentUnit)
            
            sceneView.scene.rootNode.addChildNode(lineNode)
            sceneView.scene.rootNode.addChildNode(labelNode)
            
            let segIndex = session.segments.count - 1
            session.registerNodes(lineNode: lineNode, labelNode: labelNode, forSegmentAt: segIndex)
            
            // Segment drawn → live preview is irrelevant, clear it
            removeLivePreview()
        }
        
        updateHUD()
    }
    
    // MARK: - Live Preview
    //
    // Drawn only when there is an active point.
    // Snap does NOT change the active point — it only affects placePoint().
    
    private func updateLivePreview(cursor: SIMD3<Float>) {
        guard let activeIdx = session.activePointIndex else {
            removeLivePreview()
            return
        }
        
        let a    = session.points[activeIdx].worldPosition
        let b    = cursor
        let dist = MeasurementSession.distance(a, b)
        let mid  = (a + b) * 0.5
        
        liveLineNode?.removeFromParentNode()
        let line     = SceneBuilder.makeLineNode(from: a, to: b)
        line.opacity = 0.5
        sceneView.scene.rootNode.addChildNode(line)
        liveLineNode = line
        
        liveLabelNode?.removeFromParentNode()
        let label = SceneBuilder.buildLabel(
            text: currentUnit.format(metres: dist),
            midpoint: mid
        )
        sceneView.scene.rootNode.addChildNode(label)
        liveLabelNode = label
    }
    
    private func removeLivePreview() {
        liveLineNode?.removeFromParentNode();  liveLineNode  = nil
        liveLabelNode?.removeFromParentNode(); liveLabelNode = nil
    }
    
    // MARK: - Undo / Clear
    
    private func undoLast() {
        let result = session.undoLastSegment()
        result.lineNode?.removeFromParentNode()
        result.labelNode?.removeFromParentNode()
        result.orphanPoint?.removeFromParentNode()
        removeLivePreview()
        updateHUD()
    }
    
    private func clearAll() {
        session.clear().forEach { $0.removeFromParentNode() }
        removeLivePreview()
        snapRing.isHidden = true
        updateHUD()
    }

    // MARK: - Unit Change
    //
    // Fired when the user picks a new unit from the HUD's unit pill.
    // Re-labels every existing segment in place so old + new measurements
    // are always shown in the same, currently-selected unit.

    private func changeUnit(to unit: MeasurementUnit) {
        currentUnit = unit
        relabelAllSegments()
        hud.updateUnit(unit)
    }

    private func relabelAllSegments() {
        for (index, seg) in session.segments.enumerated() {
            seg.labelNode?.removeFromParentNode()

            let a    = session.points[seg.indexA].worldPosition
            let b    = session.points[seg.indexB].worldPosition
            let dist = MeasurementSession.distance(a, b)

            let newLabel = SceneBuilder.makeLabelNode(between: a, and: b, distanceMetres: dist, unit: currentUnit)
            sceneView.scene.rootNode.addChildNode(newLabel)
            session.updateLabelNode(newLabel, forSegmentAt: index)
        }
    }
    
    // MARK: - HUD
    
    private func updateHUD() {
        let count  = session.points.count
        let active = session.activePointIndex
        
        let status: String
        if count == 0 {
            status = "Press + to place first point"
        } else if active == nil && count > 0 {
            // Drawing stopped — guide user to either start fresh or re-use a point
            status = "Aim at a point and press + to continue"
        } else if active != nil && count == 1 {
            status = "Aim and press + for second point"
        } else {
            status = "Press + to add — aim at a point to connect"
        }
        
        hud.update(pointCount: count, status: status)
    }
    
    // MARK: - Raycasting
    
    private func raycast(from point: CGPoint) -> SIMD3<Float>? {
        guard let query = sceneView.raycastQuery(
            from: point,
            allowing: .estimatedPlane,
            alignment: .any
        ) else { return nil }
        
        return sceneView.session.raycast(query).first.map {
            SIMD3<Float>(
                $0.worldTransform.columns.3.x,
                $0.worldTransform.columns.3.y,
                $0.worldTransform.columns.3.z
            )
        }
    }
    
    
    private func raycastResult(from point: CGPoint) -> ARRaycastResult? {
        guard let query = sceneView.raycastQuery(
            from: point,
            allowing: .estimatedPlane,
            alignment: .any
        ) else { return nil }
        return sceneView.session.raycast(query).first
    }
    
    
    // MARK: - Per-frame update
    private func updateFrame() {
        let center = CGPoint(x: sceneView.bounds.midX, y: sceneView.bounds.midY)
        guard let result = raycastResult(from: center) else {
            crosshair.isHidden = true
            cursorPosition     = nil
            currentSnap        = .none
            snapRing.isHidden  = true
            removeLivePreview()
            return
        }
        
        let transform = result.worldTransform
        let worldPos  = SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
        
        // Surface normal from the raycast transform (column 2 = Z axis = forward)
        let normal = SIMD3<Float>(
            transform.columns.2.x,
            transform.columns.2.y,
            transform.columns.2.z
        )
        
        cursorPosition     = worldPos
        crosshair.isHidden = false
        crosshair.simdPosition = worldPos
        crosshair.simdLook(at: worldPos + normal)   // ✅ aligns to surface
        
        currentSnap = session.snapTarget(for: worldPos)
        
        switch currentSnap {
        case .existingPoint(_, let pos):
            snapRing.isHidden = false
            snapRing.simdPosition = pos
            snapRing.simdLook(at: pos + normal)     // ✅ aligns to surface
        case .segmentMidpoint(_, let pos):
            snapRing.isHidden = false
            snapRing.simdPosition = pos
            snapRing.simdLook(at: pos + normal)     // ✅ aligns to surface
        case .none:
            snapRing.isHidden = true
        }
        
        updateLivePreview(cursor: worldPos)
    }
}

// MARK: - ARSCNViewDelegate

extension MeasureViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async { [weak self] in self?.updateFrame() }
    }
}

// MARK: - ARSessionDelegate

extension MeasureViewController: ARSessionDelegate {
    func session(_ session: ARSession, didFailWithError error: Error) {
        hud.update(
            pointCount: session.currentFrame?.anchors.count ?? 0,
            status: "AR Error: \(error.localizedDescription)"
        )
    }
    func sessionWasInterrupted(_ session: ARSession) {
        hud.update(pointCount: 0, status: "Session interrupted")
    }
    func sessionInterruptionEnded(_ session: ARSession) {
        hud.update(pointCount: 0, status: "Move device to re-detect surfaces")
    }
}
