import Foundation

/// The 8 (well, 9 counting Luck) primary attributes in Dark Souls III.
enum StatType: String, CaseIterable, Codable, Identifiable {
    case vigor, attunement, endurance, vitality
    case strength, dexterity, intelligence, faith, luck

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .vigor: return "VIG"
        case .attunement: return "ATT"
        case .endurance: return "END"
        case .vitality: return "VIT"
        case .strength: return "STR"
        case .dexterity: return "DEX"
        case .intelligence: return "INT"
        case .faith: return "FAI"
        case .luck: return "LUK"
        }
    }

    var displayName: String {
        switch self {
        case .vigor: return "Vigor"
        case .attunement: return "Attunement"
        case .endurance: return "Endurance"
        case .vitality: return "Vitality"
        case .strength: return "Strength"
        case .dexterity: return "Dexterity"
        case .intelligence: return "Intelligence"
        case .faith: return "Faith"
        case .luck: return "Luck"
        }
    }

    /// What the stat governs, shown as helper text in the UI.
    var blurb: String {
        switch self {
        case .vigor: return "HP"
        case .attunement: return "Focus Points & attunement slots"
        case .endurance: return "Stamina & equip load"
        case .vitality: return "Equip load capacity"
        case .strength: return "STR scaling & requirements"
        case .dexterity: return "DEX scaling & requirements"
        case .intelligence: return "Sorcery & INT scaling"
        case .faith: return "Miracles & FAI scaling"
        case .luck: return "Item discovery & bleed/poison buildup"
        }
    }
}

/// A full set of the 9 primary attributes, keyed by StatType.
struct StatBlock: Codable, Hashable {
    var values: [StatType: Int]

    init(values: [StatType: Int] = [:]) {
        var full = values
        for stat in StatType.allCases where full[stat] == nil {
            full[stat] = 1
        }
        self.values = full
    }

    subscript(stat: StatType) -> Int {
        get { values[stat] ?? 1 }
        set { values[stat] = max(1, min(99, newValue)) }
    }

    /// Sum of all 9 stat points, used for Soul Level math.
    var total: Int {
        StatType.allCases.reduce(0) { $0 + self[$1] }
    }

    static func - (lhs: StatBlock, rhs: StatBlock) -> Int {
        StatType.allCases.reduce(0) { $0 + (lhs[$1] - rhs[$1]) }
    }
}
