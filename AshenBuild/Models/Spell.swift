import Foundation

enum SpellSchool: String, Codable, CaseIterable, Identifiable {
    case sorcery, miracle, pyromancy, item
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sorcery: return "Sorceries"
        case .miracle: return "Miracles"
        case .pyromancy: return "Pyromancies"
        case .item: return "Resins"
        }
    }

    var symbol: String {
        switch self {
        case .sorcery: return "sparkles"
        case .miracle: return "sun.max.fill"
        case .pyromancy: return "flame.fill"
        case .item: return "drop.fill"
        }
    }
}

/// What a weapon buff adds (SpEffectParam, as used by the community AR calculators):
/// spells add a percentage of the catalyst's spell buff as elemental damage, resins add a
/// flat amount, Blessed Weapon multiplies physical attack.
struct WeaponBuff: Codable, Hashable {
    let element: String
    var percentOfSpellBuff: Double?
    var flat: Double?
    var physicalMultiplier: Double?

    var damageType: DamageType { DamageType(rawValue: element) ?? .physical }
}

struct Spell: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let school: SpellSchool
    let fp: Int
    let slots: Int
    let int: Int
    let fth: Int
    /// attack, weapon-buff, heal, self-buff, defense, utility
    let type: String
    let element: String
    var buff: WeaponBuff?

    var isWeaponBuff: Bool { buff != nil }

    var typeLabel: String {
        switch type {
        case "attack": return "Attack"
        case "weapon-buff": return "Weapon buff"
        case "heal": return "Heal"
        case "self-buff": return "Self buff"
        case "defense": return "Defense"
        default: return "Utility"
        }
    }

    /// Can this character cast it (stats only; a catalyst of the school is checked separately)?
    func canCast(_ stats: StatBlock) -> Bool {
        stats[.intelligence] >= int && stats[.faith] >= fth
    }

    /// One-line description of the buff's effect for the menus.
    var buffSummary: String? {
        guard let buff else { return nil }
        if let p = buff.percentOfSpellBuff { return "+\(Int(p))% of spell buff as \(buff.element) damage" }
        if let f = buff.flat { return "+\(Int(f)) \(buff.element) damage" }
        if let m = buff.physicalMultiplier { return "Physical attack x\(m.formatted(.number.precision(.fractionLength(3))))" }
        return nil
    }
}
