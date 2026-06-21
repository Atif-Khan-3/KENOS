import Foundation

// MARK: - MeasurementUnit
// All distances inside MeasurementSession / ARKit are stored in metres
// (ARKit's native unit). This enum converts + formats them for display
// in whichever unit the user has picked from the HUD's unit pill.

enum MeasurementUnit: String, CaseIterable, Identifiable {
    case meters
    case centimeters
    case millimeters
    case feet
    case inches
    case yards

    var id: String { rawValue }

    /// Short symbol shown in the unit pill and appended to distance labels.
    var symbol: String {
        switch self {
        case .meters:      return "m"
        case .centimeters: return "cm"
        case .millimeters: return "mm"
        case .feet:        return "ft"
        case .inches:      return "in"
        case .yards:       return "yd"
        }
    }

    /// Full display name, used inside the unit picker menu.
    var displayName: String {
        switch self {
        case .meters:      return "Meters"
        case .centimeters: return "Centimeters"
        case .millimeters: return "Millimeters"
        case .feet:        return "Feet"
        case .inches:      return "Inches"
        case .yards:       return "Yards"
        }
    }

    /// Converts a value given in metres (ARKit's native unit) into this unit.
    func convert(fromMetres metres: Float) -> Float {
        switch self {
        case .meters:      return metres
        case .centimeters: return metres * 100
        case .millimeters: return metres * 1000
        case .feet:        return metres * 3.28084
        case .inches:      return metres * 39.3701
        case .yards:       return metres * 1.09361
        }
    }

    /// Decimal places appropriate for this unit's typical precision.
    private var decimalPlaces: Int {
        switch self {
        case .meters, .feet, .yards: return 2
        case .centimeters, .inches:  return 1
        case .millimeters:           return 0
        }
    }

    /// Formats a distance given in metres into this unit, e.g. "1.84 m" or "72.4 in".
    func format(metres: Float) -> String {
        let value = convert(fromMetres: metres)
        return String(format: "%.\(decimalPlaces)f %@", value, symbol)
    }
}
