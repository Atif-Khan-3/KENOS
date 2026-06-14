import ARKit
import SceneKit

enum SceneBuilder {

    // MARK: - Colors / Sizes
    private static let dotColor   = UIColor.white
    private static let lineColor  = UIColor.white
    private static let labelColor = UIColor.white
    private static let dotRadius:  CGFloat = 0.006
    private static let lineRadius: CGFloat = 0.002

    // MARK: - Dot Node
    static func makeDotNode(at position: SIMD3<Float>) -> SCNNode {
        let sphere = SCNSphere(radius: dotRadius)
        sphere.firstMaterial?.diffuse.contents   = dotColor
        sphere.firstMaterial?.emission.contents  = UIColor.white.withAlphaComponent(0.6)
        sphere.firstMaterial?.lightingModel      = .constant

        let node = SCNNode(geometry: sphere)
        node.position = SCNVector3(position)
        return node
    }

    // MARK: - Line / Tube Node
    static func makeLineNode(from a: SIMD3<Float>, to b: SIMD3<Float>) -> SCNNode {
        let vector = b - a
        let length = simd_length(vector)
        guard length > 0 else { return SCNNode() }

        let cylinder = SCNCylinder(radius: lineRadius, height: CGFloat(length))
        cylinder.firstMaterial?.diffuse.contents  = lineColor
        cylinder.firstMaterial?.lightingModel     = .constant

        let lineNode = SCNNode(geometry: cylinder)
        let mid = (a + b) * 0.5
        lineNode.position = SCNVector3(mid)

        let yAxis = SIMD3<Float>(0, 1, 0)
        let dir   = simd_normalize(vector)
        let cross = simd_cross(yAxis, dir)
        let dot   = simd_dot(yAxis, dir)
        let angle = acos(dot)

        if simd_length(cross) > 0.0001 {
            lineNode.rotation = SCNVector4(cross.x, cross.y, cross.z, angle)
        } else if dot < 0 {
            lineNode.rotation = SCNVector4(1, 0, 0, Float.pi)
        }

        return lineNode
    }

    // MARK: - Distance Label Node (fixed segment)
    static func makeLabelNode(
        between a: SIMD3<Float>,
        and b: SIMD3<Float>,
        distanceMetres: Float
    ) -> SCNNode {
        return buildLabel(
            text: String(format: "%.2f m", distanceMetres),
            midpoint: (a + b) * 0.5
        )
    }

    // MARK: - Live Label Node (updated every frame)
    // Returns a node whose SCNText geometry you can mutate directly.
    static func makeLiveLabelNode(at midpoint: SIMD3<Float>) -> SCNNode {
        return buildLabel(text: "0.00 m", midpoint: midpoint)
    }

    // MARK: - Shared label builder
    static func buildLabel(text: String, midpoint: SIMD3<Float>) -> SCNNode {
        let scnText = SCNText(string: text, extrusionDepth: 0)
        scnText.font      = UIFont.systemFont(ofSize: 6, weight: .semibold)
        scnText.flatness  = 0.1
        scnText.firstMaterial?.diffuse.contents  = labelColor
        scnText.firstMaterial?.lightingModel     = .constant
        scnText.firstMaterial?.isDoubleSided     = true

        let textNode = SCNNode(geometry: scnText)
        let scale: Float = 0.003
        textNode.scale = SCNVector3(scale, scale, scale)

        // Centre horizontally
        let (minB, maxB) = textNode.boundingBox
        let textWidth = Float(maxB.x - minB.x) * scale
        textNode.position.x -= textWidth / 2

        let wrapper = SCNNode()
        wrapper.position = SCNVector3(midpoint.x, midpoint.y + 0.015, midpoint.z)
        wrapper.addChildNode(textNode)

        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        wrapper.constraints = [billboard]

        return wrapper
    }

    // MARK: - Crosshair ring
    static func makeCrosshairNode() -> SCNNode {
        let ring = SCNTorus(ringRadius: 0.012, pipeRadius: 0.001)
        ring.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.8)
        ring.firstMaterial?.lightingModel    = .constant
        return SCNNode(geometry: ring)
    }

    // MARK: - Snap indicator ring (yellow pulse)
    static func makeSnapRingNode() -> SCNNode {
        let ring = SCNTorus(ringRadius: 0.02, pipeRadius: 0.001)
        ring.firstMaterial?.diffuse.contents = UIColor.yellow.withAlphaComponent(0.9)
        ring.firstMaterial?.lightingModel    = .constant

        let node = SCNNode(geometry: ring)
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue    = 1.0
        pulse.toValue      = 0.2
        pulse.duration     = 0.6
        pulse.autoreverses = true
        pulse.repeatCount  = .infinity
        node.addAnimation(pulse, forKey: "pulse")
        node.isHidden = true
        return node
    }
}
