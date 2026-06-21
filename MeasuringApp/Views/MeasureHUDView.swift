import SwiftUI

struct MeasureHUDView: View {

    let pointCount:    Int
    let status:        String
    let currentUnit:   MeasurementUnit
    var onAdd:         () -> Void
    var onUndo:        () -> Void
    var onClear:       () -> Void
    var onUnitChange:  (MeasurementUnit) -> Void

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

                // ── Three action buttons
                
                HStack(alignment: .center) {

                    // Undo — white background, red SF Symbol icon
                    Button(action: onUndo) {
                        ZStack {

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
            unitPill
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

    // ── Unit picker pill — top-leading corner ───────────────────────────────
    private var unitPill: some View {
        Menu {
            ForEach(MeasurementUnit.allCases) { unit in
                Button {
                    onUnitChange(unit)
                } label: {
                    if unit == currentUnit {
                        Label(unit.displayName, systemImage: "checkmark")
                    } else {
                        Text(unit.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(currentUnit.symbol)
                    .font(.system(size: 14, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundColor(.black.opacity(0.85))
            .frame(width: 54, height: 36)
        }
        .buttonStyle(.glassProminent)
        .tint(.white)
        .padding(.top, 16)
        .padding(.leading, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    var onAdd:        (() -> Void)?
    var onUndo:       (() -> Void)?
    var onClear:      (() -> Void)?
    var onUnitChange: ((MeasurementUnit) -> Void)?

    private var currentPointCount = 0
    private var currentStatus     = "Move iPhone to detect surfaces"
    private var currentUnit: MeasurementUnit = .meters

    init() {
        super.init(rootView: MeasureHUDView(
            pointCount:   0,
            status:       "Move iPhone to detect surfaces",
            currentUnit:  .meters,
            onAdd:        {},
            onUndo:       {},
            onClear:      {},
            onUnitChange: { _ in }
        ))
        refresh()
    }

    @MainActor required dynamic init?(coder: NSCoder) { fatalError() }

    func update(pointCount: Int, status: String) {
        currentPointCount = pointCount
        currentStatus     = status
        refresh()
    }

    /// Call this when the user picks a new unit from the pill menu.
    func updateUnit(_ unit: MeasurementUnit) {
        currentUnit = unit
        refresh()
    }

    private func refresh() {
        rootView = MeasureHUDView(
            pointCount:   currentPointCount,
            status:       currentStatus,
            currentUnit:  currentUnit,
            onAdd:        { [weak self] in self?.onAdd?() },
            onUndo:       { [weak self] in self?.onUndo?() },
            onClear:      { [weak self] in self?.onClear?() },
            onUnitChange: { [weak self] unit in self?.onUnitChange?(unit) }
        )
    }
}
