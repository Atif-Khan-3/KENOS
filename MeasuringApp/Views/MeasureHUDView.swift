import SwiftUI

// MARK: - MeasureHUDView  (matches Apple Measure app UI)
//
// Layout (bottom of screen, safe-area aware):
//
//   [status text — centred above buttons]
//
//   [ Undo (white bg / red icon) ]   [ + (large white circle) ]   [ Delete (red bg / trash icon) ]
//
//   ─────────────────────────────────────────────────────────────
//   |  ▥  Measure   |   ⊟  Level  |        ← tab bar
//   ─────────────────────────────────────────────────────────────

struct MeasureHUDView: View {

    let pointCount:    Int
    let status:        String
    var onAdd:         () -> Void
    var onUndo:        () -> Void
    var onClear:       () -> Void

    // Tab state (Measure is always selected in this VC; Level is a stub)
    @State private var selectedTab: Int = 0

    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
       
        ZStack(alignment: .topTrailing){
                   
            VStack(spacing: 0) {

                // ── Status label ──────────────────────────────────────────────
                Text(status)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.6), radius: 3, x: 0, y: 1)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 14)

                // ── Three action buttons ──────────────────────────────────────
                HStack(alignment: .center) {

                    // Undo — white background, red SF Symbol icon
                    Button(action: onUndo) {
                        ZStack {
    //                        Circle()
    //                            .fill(Color.white)
    //                            .frame(width: 56, height: 56)
    //                            .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)

                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 20, weight: .semibold))
                                .frame(width: 40, height: 50)
                                .foregroundColor(
                                    pointCount > 0
                                        ? Color(red: 1, green: 0.18, blue: 0.18)
                                        : Color(red: 1, green: 0.18, blue: 0.18).opacity(0.3)
                                )
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.white)
                    .disabled(pointCount == 0)

                    Spacer()

                    // + (Add Point) — large white circle, black +
                    Button(action: onAdd) {
                        ZStack {
    //                        Circle()
    //                            .fill(Color.white)
    //                            .frame(width: 72, height: 72)
    //                            .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)

                            Image(systemName: "plus")
                                .font(.system(size: 30, weight: .bold))
                                .frame(width: 60, height: 70)
                                .cornerRadius(50)
                                .foregroundColor(.white)
                        }
                        
                        
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.customPurple)
                    Spacer()

                    // Delete / Clear — red background, white trash icon
                    Button(action: onClear) {
                        ZStack {
    //                        Circle()
    //                            .fill(
    //                                pointCount > 0
    //                                    ? Color(red: 1, green: 0.18, blue: 0.18)
    //                                    : Color(red: 1, green: 0.18, blue: 0.18).opacity(0.35)
    //                            )
    //                            .frame(width: 56, height: 56)
    //                            .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)

                            Image(systemName: "trash")
                                .font(.system(size: 20, weight: .semibold))
                                .frame(width: 40, height: 50)
                                .foregroundColor(
                                    pointCount > 0
                                        ? .white
                                        : .white.opacity(0.4)
                                )
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.red)
                    .disabled(pointCount == 0)
                }
                .padding(.horizontal, 44)

                // ── Tab bar (Measure / Level) — matching Apple Measure app ────
            }
            .padding(.top, 12)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
           dismissButton
        }
          // safe area padding is added by the parent constraint
    }

    private var dismissButton: some View {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .scaledToFill()
                    .bold()
                    .frame(width: 30, height: 40)
                    .cornerRadius(70)
            }
            .buttonStyle(.glassProminent)
            .tint(.customRed)
            .padding(.top, 16)
            .padding(.trailing, 20)
        }
    
    // ── Tab button helper ─────────────────────────────────────────────────
    @ViewBuilder
    private func tabButton(iconName: String, label: String, index: Int) -> some View {
        let isSelected = selectedTab == index
        Button {
            selectedTab = index
        } label: {
            VStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.45))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
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
            status:     "Move iPhone to detect surfaces",
            onAdd:  {},
            onUndo: {},
            onClear: {}
        ))
        refresh(pointCount: 0, status: "Move iPhone to detect surfaces")
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
