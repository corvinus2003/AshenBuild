import Foundation

/// One of the 10 starting classes. Base stats determine both the class's
/// starting Soul Level (derived, see `Formulas.soulLevel`) and act as the
/// floor a build editor won't let you drop a stat below.
struct StartingClass: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let flavor: String
    let baseStats: [String: Int]      // keyed by StatType.rawValue for easy JSON
    /// Starting equipment as in the game (slots 1-3 of each hand).
    let rightHand: [String]
    let leftHand: [String]
    let startingArmorIDs: [String]
    let spellIDs: [String]
    let ringIDs: [String]

    var statBlock: StatBlock {
        var values: [StatType: Int] = [:]
        for (key, value) in baseStats {
            if let stat = StatType(rawValue: key) {
                values[stat] = value
            }
        }
        return StatBlock(values: values)
    }
}

extension StartingClass {
    /// SF Symbol shown next to the class in lists and pickers.
    var symbolName: String {
        switch id {
        case "knight": return "shield.fill"
        case "mercenary": return "figure.fencing"
        case "warrior": return "figure.martial.arts"
        case "herald": return "sun.max.fill"
        case "thief": return "eye.fill"
        case "assassin": return "moon.stars.fill"
        case "sorcerer": return "sparkles"
        case "pyromancer": return "flame.fill"
        case "cleric": return "hands.sparkles.fill"
        default: return "circle.dashed"
        }
    }
}
