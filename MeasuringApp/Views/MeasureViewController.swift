import UIKit
import ARKit
import SceneKit
import SwiftUI
final class MeasureViewController: UIViewController {

    // MARK: - Subviews
    private let sceneView = ARSCNView()
    private let hud       = MeasureHUDHostingController()

    // MARK: - AR / Scene state
    private let session   = MeasurementSession()
    private var crosshair = SceneBuilder.makeCrosshairNode()
    private var snapRing  = SceneBuilder.makeSnapRingNode()
    private var labelNodes: [SCNNode] = []

    // Live segment: line + label shown while moving before placing next point
    private var liveLineNode:  SCNNode?
    private var liveLabelNode: SCNNode?

    // Last known cursor world position (updated every frame)
    private var cursorPosition: SIMD3<Float>?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSceneView()
        setupHUD()
        addPermanentNodes()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection        = [.horizontal, .vertical]
        config.environmentTexturing  = .automatic
        sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    // MARK: - Setup

    private func setupSceneView() {
        sceneView.frame                    = view.bounds
        sceneView.autoresizingMask         = [.flexibleWidth, .flexibleHeight]
        sceneView.delegate                 = self
        sceneView.session.delegate         = self
        sceneView.autoenablesDefaultLighting = true
        sceneView.antialiasingMode         = .multisampling4X
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
            hud.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        // + button places a point at the current cursor position
        hud.onAdd = { [weak self] in self?.placePointAtCursor() }
        hud.onUndo  = { [weak self] in self?.undoLastPoint() }
        hud.onClear = { [weak self] in self?.clearAll() }
    }

    private func addPermanentNodes() {
        sceneView.scene.rootNode.addChildNode(crosshair)
        sceneView.scene.rootNode.addChildNode(snapRing)
    }

    // MARK: - Place Point (triggered by + button)

    private func placePointAtCursor() {
        guard !session.isClosed, let worldPos = cursorPosition else { return }

        // Remove live preview before committing
        removeLivePreview()

        let dotNode = SceneBuilder.makeDotNode(at: worldPos)
        sceneView.scene.rootNode.addChildNode(dotNode)

        let point    = MeasurementPoint(worldPosition: worldPos, node: dotNode)
        let didClose = session.addPoint(point)

        if let (a, b) = didClose ? session.closingSegment() : session.lastSegment() {
            addFixedSegment(from: a, to: b)
        }

        let status: String
        if didClose {
            snapRing.isHidden = true
            status = "Shape closed!"
        } else {
            status = session.points.count == 1
                ? "Aim and press + to continue"
                : "Press + to add point — aim near P1 to close"
        }

        updateHUD(status: status)
    }

    // MARK: - Fixed Segment + Label

    private func addFixedSegment(from a: SIMD3<Float>, to b: SIMD3<Float>) {
        let lineNode  = SceneBuilder.makeLineNode(from: a, to: b)
        let dist      = MeasurementSession.distance(a, b)
        let labelNode = SceneBuilder.makeLabelNode(between: a, and: b, distanceMetres: dist)

        sceneView.scene.rootNode.addChildNode(lineNode)
        sceneView.scene.rootNode.addChildNode(labelNode)

        session.registerLineNode(lineNode)
        labelNodes.append(labelNode)
    }

    // MARK: - Live Preview (line + label from last point → cursor)

    private func updateLivePreview(to cursor: SIMD3<Float>) {
        guard let last = session.points.last, !session.isClosed else {
            removeLivePreview()
            return
        }

        let a = last.worldPosition
        let b = cursor
        let dist = MeasurementSession.distance(a, b)
        let mid  = (a + b) * 0.5

        // Rebuild live line
        liveLineNode?.removeFromParentNode()
        let line = SceneBuilder.makeLineNode(from: a, to: b)
        line.opacity = 0.5
        sceneView.scene.rootNode.addChildNode(line)
        liveLineNode = line

        // Rebuild live label
        liveLabelNode?.removeFromParentNode()
        let label = SceneBuilder.buildLabel(
            text: String(format: "%.2f m", dist),
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

    private func undoLastPoint() {
        let (pointNode, lineNode) = session.undoLast()
        pointNode?.removeFromParentNode()
        lineNode?.removeFromParentNode()
        labelNodes.popLast()?.removeFromParentNode()
        removeLivePreview()

        let status = session.points.isEmpty
            ? "Press + to place first point"
            : "Point removed"
        updateHUD(status: status)
    }

    private func clearAll() {
        session.clear().forEach { $0.removeFromParentNode() }
        labelNodes.forEach { $0.removeFromParentNode() }
        labelNodes.removeAll()
        snapRing.isHidden = true
        removeLivePreview()
        updateHUD(status: "Press + to place first point")
    }

    // MARK: - HUD

    private func updateHUD(status: String) {
        hud.update(pointCount: session.points.count, status: status)
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

    // MARK: - Per-frame update (cursor + live preview)

    private func updateFrame() {
        let center = CGPoint(x: sceneView.bounds.midX, y: sceneView.bounds.midY)
        guard let worldPos = raycast(from: center) else {
            crosshair.isHidden = true
            cursorPosition = nil
            return
        }

        cursorPosition         = worldPos
        crosshair.isHidden     = false
        crosshair.position     = SCNVector3(worldPos)

        // Live preview line + label
        updateLivePreview(to: worldPos)

        // Snap ring
        if session.points.count >= 3, let first = session.points.first {
            let d = simd_distance(worldPos, first.worldPosition)
            snapRing.isHidden = d > MeasurementSession.snapRadiusMetres
            if !snapRing.isHidden {
                snapRing.position = SCNVector3(first.worldPosition)
            }
        } else {
            snapRing.isHidden = true
        }
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
        updateHUD(status: "AR Error: \(error.localizedDescription)")
    }
    func sessionWasInterrupted(_ session: ARSession) {
        updateHUD(status: "Session interrupted")
    }
    func sessionInterruptionEnded(_ session: ARSession) {
        updateHUD(status: "Session resumed — move to re-detect")
    }
}
