import Foundation

/// An attack boost that only applies in a situation (low HP, full HP, crits…).
struct ConditionalAttack: Codable, Hashable {
    let label: String          // "at or below 20% HP"
    let percent: Double        // +20
    var hpThreshold: Double?   // 0.20 for Red Tearstone, used to show the HP figure
}

/// One ring variant (e.g. "Havel's Ring +2"). Variants of the same ring share a `family`.
struct Ring: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let weight: Double
    let effect: String   // human-readable effect description

    // Mechanical effects the calculator applies. All optional in JSON.
    var hpMultiplier: Double = 1.0
    var staminaMultiplier: Double = 1.0
    var equipLoadMultiplier: Double = 1.0
    var poiseBonus: Double = 0
    var statBonuses: [String: Int] = [:]        // keyed by StatType.rawValue
    var absorption: [String: Double] = [:]      // percent, keyed by DamageType.rawValue
    var attackBonus: [String: Double] = [:]     // always-on percent, keyed by DamageType.rawValue
    var conditionalAttack: ConditionalAttack?
    var attunementSlots: Int = 0
    var special: String?                        // "flynn"

    enum CodingKeys: String, CodingKey {
        case id, name, weight, effect
        case hpMultiplier, staminaMultiplier, equipLoadMultiplier, poiseBonus
        case statBonuses, absorption, attackBonus, conditionalAttack, attunementSlots, special
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        weight = try c.decode(Double.self, forKey: .weight)
        effect = try c.decode(String.self, forKey: .effect)
        hpMultiplier = try c.decodeIfPresent(Double.self, forKey: .hpMultiplier) ?? 1.0
        staminaMultiplier = try c.decodeIfPresent(Double.self, forKey: .staminaMultiplier) ?? 1.0
        equipLoadMultiplier = try c.decodeIfPresent(Double.self, forKey: .equipLoadMultiplier) ?? 1.0
        poiseBonus = try c.decodeIfPresent(Double.self, forKey: .poiseBonus) ?? 0
        statBonuses = try c.decodeIfPresent([String: Int].self, forKey: .statBonuses) ?? [:]
        absorption = try c.decodeIfPresent([String: Double].self, forKey: .absorption) ?? [:]
        attackBonus = try c.decodeIfPresent([String: Double].self, forKey: .attackBonus) ?? [:]
        conditionalAttack = try c.decodeIfPresent(ConditionalAttack.self, forKey: .conditionalAttack)
        attunementSlots = try c.decodeIfPresent(Int.self, forKey: .attunementSlots) ?? 0
        special = try c.decodeIfPresent(String.self, forKey: .special)
    }

    /// "Havel's Ring +2" -> family "Havel's Ring", level 2.
    var family: String { Self.split(name).family }
    var level: Int { Self.split(name).level }

    private static func split(_ name: String) -> (family: String, level: Int) {
        if let range = name.range(of: #" \+(\d)$"#, options: .regularExpression),
           let level = Int(name[range].dropFirst(2)) {
            return (String(name[..<range.lowerBound]), level)
        }
        return (name, 0)
    }

    func statBonus(_ stat: StatType) -> Int { statBonuses[stat.rawValue] ?? 0 }
}

/// All variants of one ring, lowest level first.
struct RingFamily: Identifiable, Hashable {
    let name: String
    let variants: [Ring]
    var id: String { name }
    var base: Ring { variants[0] }
}
