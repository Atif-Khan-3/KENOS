import SwiftUI

// MARK: - MeasureHUDView (SwiftUI)

struct MeasureHUDView: View {

    let pointCount: Int
    let status:     String
    var onAdd:   () -> Void   // + button
    var onUndo:  () -> Void
    var onClear: () -> Void

    var body: some View {
        VStack(spacing: 12) {

            // Status text
            Text(status)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity)

            HStack(spacing: 10) {

                // ── Undo button ──────────────────────────────
                // Change style here freely
                Button(action: onUndo) {
                    Text("Undo")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(pointCount > 0 ? .white : .white.opacity(0.3))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.15))
                        )
                }
                .disabled(pointCount == 0)

                // ── + Add Point button ───────────────────────
                // Change style here freely
                Button(action: onAdd) {
                    Text("+")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color.white))
                }

                // ── Clear All button ─────────────────────────
                // Change style here freely
                Button(action: onClear) {
                    Text("Clear")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(pointCount > 0
                            ? Color(red: 1, green: 0.5, blue: 0.5)
                            : Color(red: 1, green: 0.5, blue: 0.5).opacity(0.3))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(red: 1, green: 0.23, blue: 0.19).opacity(0.35))
                        )
                }
                .disabled(pointCount == 0)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.72))
        )
    }
}

// MARK: - MeasureHUDHostingController

final class MeasureHUDHostingController: UIHostingController<MeasureHUDView> {

    var onAdd:   (() -> Void)?
    var onUndo:  (() -> Void)?
    var onClear: (() -> Void)?

    init() {
        super.init(rootView: MeasureHUDView(
            pointCount: 0,
            status: "Press + to place first point",
            onAdd: {}, onUndo: {}, onClear: {}
        ))
        refresh(pointCount: 0, status: "Press + to place first point")
    }

    @MainActor required dynamic init?(coder: NSCoder) { fatalError() }

    func update(pointCount: Int, status: String) {
        refresh(pointCount: pointCount, status: status)
    }

    private func refresh(pointCount: Int, status: String) {
        rootView = MeasureHUDView(
            pointCount: pointCount,
            status:     status,
            onAdd:      { [weak self] in self?.onAdd?() },
            onUndo:     { [weak self] in self?.onUndo?() },
            onClear:    { [weak self] in self?.onClear?() }
        )
    }
}
