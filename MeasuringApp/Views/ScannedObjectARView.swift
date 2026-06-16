import SwiftUI
import RealityKit
import ARKit
import Combine

// MARK: - SwiftUI Wrapper
struct ScannedObjectARView: View {
    let object: ScannedObject
    @Environment(\.dismiss) private var dismiss
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        Group {
            if let url = object.modelURL {
                ScannedObjectARViewControllerRepresentable(
                    modelURL: url,
                    objectName: object.name,
                    height: object.height,
                    width: object.width
                )
                .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
                    .onAppear {
                        errorMessage = "No 3D model found for \"\(object.name)\". Please scan the object first."
                        showError = true
                    }
            }
        }
        .alert("Model Not Available", isPresented: $showError) {
            Button("OK") { dismiss() }
        } message: {
            Text(errorMessage)
        }
    }
}

// MARK: - UIViewControllerRepresentable
struct ScannedObjectARViewControllerRepresentable: UIViewControllerRepresentable {
    let modelURL: URL
    let objectName: String
    let height: Double
    let width: Double

    func makeUIViewController(context: Context) -> ScannedObjectARViewController {
        ScannedObjectARViewController(
            modelURL: modelURL,
            objectName: objectName,
            height: height,
            width: width
        )
    }

    func updateUIViewController(_ uiViewController: ScannedObjectARViewController, context: Context) {}
}

// MARK: - Main AR View Controller
final class ScannedObjectARViewController: UIViewController, ARSessionDelegate {

    // MARK: - Properties
    private let modelURL: URL
    private let objectName: String
    private let height: Double
    private let width: Double

    private var arView: ARView!
    private var modelEntity: ModelEntity?
    private var anchorEntity: AnchorEntity?
    private var hasPlacedModel = false

    // Gesture state
    private var initialScale: SIMD3<Float> = .one
    private var initialRotation: Float = 0
    private var panStartPosition: SIMD3<Float> = .zero

    // UI
    private var hudHostingController: UIHostingController<ARBottomHUD>?
    private var statusLabel: UILabel!
    private var crossButton: UIButton!

    // MARK: - Init
    init(modelURL: URL, objectName: String, height: Double, width: Double) {
        self.modelURL = modelURL
        self.objectName = objectName
        self.height = height
        self.width = width
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupARView()
        setupStatusLabel()
        setupBottomHUD()
        setupCrossButton()
        setupGestures()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startARSession()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arView.session.pause()
    }

    // MARK: - AR Setup
    private func setupARView() {
        arView = ARView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.renderOptions = [.disablePersonOcclusion]
        arView.session.delegate = self
        view.addSubview(arView)
    }

    private func startARSession() {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    // MARK: - Status Label (scanning hint)
    private func setupStatusLabel() {
        statusLabel = UILabel()
        statusLabel.text = "Move iPhone to detect a surface"
        statusLabel.textColor = .white
        statusLabel.font = .systemFont(ofSize: 14, weight: .medium)
        statusLabel.textAlignment = .center
        statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        statusLabel.layer.cornerRadius = 12
        statusLabel.layer.masksToBounds = true
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            statusLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8),
            statusLabel.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        // Add padding via insets via layer
        statusLabel.layer.sublayerTransform = CATransform3DMakeTranslation(12, 0, 0)
    }

    // MARK: - Cross / Dismiss Button
    private func setupCrossButton() {
        crossButton = UIButton(type: .system)

        // Glass style configuration
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "xmark",
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .bold))
        config.baseForegroundColor = .white
        config.baseBackgroundColor = UIColor(red: 1, green: 0.18, blue: 0.18, alpha: 1)
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        crossButton.configuration = config
        crossButton.translatesAutoresizingMaskIntoConstraints = false

        // Shadow
        crossButton.layer.shadowColor = UIColor.black.cgColor
        crossButton.layer.shadowOpacity = 0.3
        crossButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        crossButton.layer.shadowRadius = 4

        crossButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        view.addSubview(crossButton)

        NSLayoutConstraint.activate([
            crossButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            crossButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            crossButton.widthAnchor.constraint(equalToConstant: 44),
            crossButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    // MARK: - Bottom HUD (name + dimensions)
    private func setupBottomHUD() {
        let hud = ARBottomHUD(objectName: objectName, height: height, width: width)
        let hostingVC = UIHostingController(rootView: hud)
        hostingVC.view.backgroundColor = .clear
        hostingVC.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(hostingVC)
        view.addSubview(hostingVC.view)
        hostingVC.didMove(toParent: self)
        hudHostingController = hostingVC

        NSLayoutConstraint.activate([
            hostingVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - Gestures
    private func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tap)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1  // ← 1 finger only, so pinch (2 fingers) won't trigger pan
        arView.addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        arView.addGestureRecognizer(pinch)

        let rotation = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        arView.addGestureRecognizer(rotation)

        tap.delegate = self
        pan.delegate = self
        pinch.delegate = self
        rotation.delegate = self
    }

    // MARK: - Gesture Handlers
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard !hasPlacedModel else { return }
        let location = gesture.location(in: arView)

        guard let result = arView.raycast(
            from: location,
            allowing: .estimatedPlane,
            alignment: .horizontal
        ).first else { return }

        placeModel(at: result.worldTransform)
    }

    // Add this property at the top of the class
    private var panStartWorldPosition: SIMD3<Float> = .zero

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard hasPlacedModel, let anchor = anchorEntity else { return }
        let location = gesture.location(in: arView)

        guard let result = arView.raycast(
            from: location,
            allowing: .estimatedPlane,
            alignment: .horizontal
        ).first else { return }

        switch gesture.state {
        case .began:
            panStartWorldPosition = anchor.position(relativeTo: nil)
        case .changed:
            anchor.setPosition(
                SIMD3<Float>(
                    result.worldTransform.columns.3.x,
                    result.worldTransform.columns.3.y,
                    result.worldTransform.columns.3.z
                ),
                relativeTo: nil
            )
        default:
            break
        }
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard hasPlacedModel, let entity = modelEntity else { return }

        switch gesture.state {
        case .began:
            initialScale = entity.scale
            gesture.scale = 1.0
        case .changed:
            let newScale = initialScale.x * Float(gesture.scale)
            let clamped = max(0.05, min(newScale, 10.0))
            entity.scale = SIMD3<Float>(repeating: clamped)
            print("📐 Scale: \(clamped)") // ← add this to verify it's firing
        case .ended, .cancelled:
            initialScale = entity.scale // ← save final scale so next pinch starts fresh
        default:
            break
        }
    }

    @objc private func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        guard hasPlacedModel, let entity = modelEntity else { return }

        switch gesture.state {
        case .began:
            initialRotation = entity.orientation.angle
            gesture.rotation = 0
        case .changed:
            let newAngle = initialRotation - Float(gesture.rotation)
            entity.orientation = simd_quatf(angle: newAngle, axis: [0, 1, 0])
        case .ended, .cancelled:
            initialRotation = entity.orientation.angle // ← save so next rotation starts fresh
        default:
            break
        }
    }

    // MARK: - Model Placement
    private func placeModel(at transform: simd_float4x4) {
        // Load model async
        Task {
            do {
                let entity = try await ModelEntity(contentsOf: modelURL)
                await MainActor.run {
                    let position = SIMD3<Float>(
                        transform.columns.3.x,
                        transform.columns.3.y,
                        transform.columns.3.z
                    )
                    let anchor = AnchorEntity(world: position)
                    entity.generateCollisionShapes(recursive: true)
                    anchor.addChild(entity)
                    arView.scene.addAnchor(anchor)

                    self.modelEntity = entity
                    self.anchorEntity = anchor
                    self.hasPlacedModel = true

                    // Update UI
                    self.statusLabel.text = "✓ Model placed — drag, pinch or rotate"
                    UIView.animate(withDuration: 0.3, delay: 2.0) {
                        self.statusLabel.alpha = 0
                    }
                }
            } catch {
                await MainActor.run {
                    self.statusLabel.text = "Failed to load 3D model"
                }
            }
        }
    }

    // MARK: - ARSessionDelegate
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard !hasPlacedModel else { return }
        switch frame.camera.trackingState {
        case .normal:
            DispatchQueue.main.async {
                self.statusLabel.text = "Tap on a surface to place model"
            }
        case .limited(.initializing), .limited(.relocalizing):
            DispatchQueue.main.async {
                self.statusLabel.text = "Move iPhone to detect a surface"
            }
        default:
            break
        }
    }

    // MARK: - Actions
    @objc private func dismissTapped() {
        dismiss(animated: true)
    }
}

// MARK: - Gesture Recognizer Delegate (simultaneous gestures)
extension ScannedObjectARViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        // Allow pinch + rotation simultaneously (common pattern)
        let isPinch = gestureRecognizer is UIPinchGestureRecognizer || other is UIPinchGestureRecognizer
        let isRotation = gestureRecognizer is UIRotationGestureRecognizer || other is UIRotationGestureRecognizer
        let isPan = gestureRecognizer is UIPanGestureRecognizer || other is UIPanGestureRecognizer

        // Pinch + Rotation: YES
        if isPinch && isRotation { return true }

        // Pan + anything else: NO (pan should be exclusive)
        if isPan { return false }

        return false
    }
}

// MARK: - Bottom HUD SwiftUI View
struct ARBottomHUD: View {
    let objectName: String
    let height: Double
    let width: Double

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                Text(objectName)
                    .font(.title2.bold())
                    .foregroundColor(.white)

                HStack(spacing: 16) {
                    Label("\(String(format: "%.1f", height)) cm", systemImage: "arrow.up.and.down")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white.opacity(0.85))

                    Label("\(String(format: "%.1f", width)) cm", systemImage: "arrow.left.and.right")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }
}
