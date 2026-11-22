import Foundation

/// One hand's weapon choice.
struct WeaponSetup: Hashable {
    var weaponID: String?
    var upgrade: Int = 0
    var infusion: InfusionType = .none
    var twoHanded: Bool = false
}

/// A value-type snapshot of a build, so calculations and the optimizer can try
/// variations without touching the SwiftData object.
struct BuildSpec: Hashable {
    var classID: String
    var stats: StatBlock                 // points the player allocated (drives Soul Level)
    var mainHand = WeaponSetup()
    var offHand = WeaponSetup()
    var armor: [ArmorSlot: String] = [:]
    var ringIDs: [String] = []
}

/// Attack rating for one hand, with ring effects applied.
struct WeaponReport {
    let weapon: Weapon
    let setup: WeaponSetup
    let result: Formulas.AttackRatingResult   // breakdown includes always-on ring boosts
    let total: Double
    /// Situational totals, one per ring with a conditional boost (Red Tearstone, Lloyd's…).
    let conditional: [(ring: Ring, total: Double)]
}

/// Everything the app shows about a build, computed in one place.
struct BuildReport {
    let spec: BuildSpec
    let rings: [Ring]
    let armorPieces: [ArmorPiece]
    let baseStats: StatBlock         // the starting class floor
    let effectiveStats: StatBlock    // allocated + ring bonuses (Knight's Ring, Prisoner's Chain…)
    let soulLevel: Int
    let hp: Int
    let fp: Int
    let stamina: Int
    let attunementSlots: Int
    let capacity: Double
    let load: Double
    let poise: Double
    let physicalDefense: PhysicalDefense
    let elementalDefense: ElementalDefense
    let resistances: Resistances
    /// Ring absorption bonuses in percent (negative for Carthus Bloodring, clutch rings).
    let absorption: [DamageType: Double]
    let mainHand: WeaponReport?
    let offHand: WeaponReport?

    var loadFraction: Double { capacity > 0 ? load / capacity : 0 }
    var rollTier: Formulas.RollTier { Formulas.rollTier(loadPercent: loadFraction) }
    /// The hand the optimizer and verdict focus on: main hand, or off hand if the main is empty.
    var primaryWeapon: WeaponReport? { mainHand ?? offHand }
}

enum BuildCalculator {

    static func report(for spec: BuildSpec, data: DataStore) -> BuildReport {
        let rings = spec.ringIDs.compactMap { data.ring($0) }
        let pieces = ArmorSlot.allCases.compactMap { data.armorPiece(spec.armor[$0]) }
        let base = data.startingClass(spec.classID)?.statBlock ?? StatBlock()
        let effective = effectiveStats(spec.stats, rings: rings)

        let hpMultiplier = rings.reduce(1.0) { $0 * $1.hpMultiplier }
        let staminaMultiplier = rings.reduce(1.0) { $0 * $1.staminaMultiplier }
        let loadMultiplier = rings.reduce(1.0) { $0 * $1.equipLoadMultiplier }

        let load = totalWeight(spec: spec, rings: rings, pieces: pieces, data: data)

        var absorption: [DamageType: Double] = [:]
        for ring in rings {
            for (key, value) in ring.absorption {
                if let type = DamageType(rawValue: key) { absorption[type, default: 0] += value }
            }
        }

        return BuildReport(
            spec: spec,
            rings: rings,
            armorPieces: pieces,
            baseStats: base,
            effectiveStats: effective,
            soulLevel: Formulas.soulLevel(for: spec.stats),
            hp: Int((Double(Formulas.hp(vigor: effective[.vigor])) * hpMultiplier).rounded()),
            fp: Formulas.fp(attunement: effective[.attunement]),
            stamina: Int((Double(Formulas.stamina(endurance: effective[.endurance])) * staminaMultiplier).rounded()),
            attunementSlots: Formulas.attunementSlots(attunement: effective[.attunement]) + rings.reduce(0) { $0 + $1.attunementSlots },
            capacity: Formulas.equipLoadCapacity(vitality: effective[.vitality]) * loadMultiplier,
            load: load,
            poise: Formulas.totalPoise(pieces: pieces) + rings.reduce(0) { $0 + $1.poiseBonus },
            physicalDefense: Formulas.totalPhysicalDefense(pieces: pieces),
            elementalDefense: Formulas.totalElementalDefense(pieces: pieces),
            resistances: Formulas.totalResistances(pieces: pieces),
            absorption: absorption,
            mainHand: weaponReport(spec.mainHand, effective: effective, rings: rings, load: load, data: data),
            offHand: weaponReport(WeaponSetup(weaponID: spec.offHand.weaponID, upgrade: spec.offHand.upgrade,
                                              infusion: spec.offHand.infusion, twoHanded: false),
                                  effective: effective, rings: rings, load: load, data: data)
        )
    }

    static func effectiveStats(_ allocated: StatBlock, rings: [Ring]) -> StatBlock {
        var effective = allocated
        for stat in StatType.allCases {
            let bonus = rings.reduce(0) { $0 + $1.statBonus(stat) }
            if bonus != 0 { effective[stat] = allocated[stat] + bonus }
        }
        return effective
    }

    static func totalWeight(spec: BuildSpec, rings: [Ring], pieces: [ArmorPiece], data: DataStore) -> Double {
        let weapons = (data.weapon(spec.mainHand.weaponID)?.weight ?? 0) + (data.weapon(spec.offHand.weaponID)?.weight ?? 0)
        return weapons + pieces.reduce(0) { $0 + $1.weight } + rings.reduce(0) { $0 + $1.weight }
    }

    static func weaponReport(_ setup: WeaponSetup, effective: StatBlock, rings: [Ring], load: Double, data: DataStore) -> WeaponReport? {
        guard let weapon = data.weapon(setup.weaponID) else { return nil }
        var result = Formulas.attackRating(
            for: Formulas.WeaponInstance(
                weapon: weapon,
                upgradeLevel: setup.upgrade,
                infusion: weapon.infusable ? setup.infusion : .none,
                twoHanded: setup.twoHanded && weapon.canTwoHand
            ),
            stats: effective
        )

        // Always-on ring boosts: clutch rings (per element) and Flynn's Ring (physical, by weight).
        for ring in rings {
            for (key, percent) in ring.attackBonus {
                if let type = DamageType(rawValue: key), let value = result.breakdown[type] {
                    result.breakdown[type] = value * (1 + percent / 100)
                }
            }
            if ring.special == "flynn", let physical = result.breakdown[.physical] {
                result.breakdown[.physical] = physical * (1 + flynnBonus(load: load) / 100)
            }
        }
        result.total = result.breakdown.values.reduce(0, +)

        let conditional = rings.compactMap { ring -> (Ring, Double)? in
            guard let boost = ring.conditionalAttack else { return nil }
            return (ring, result.total * (1 + boost.percent / 100))
        }
        return WeaponReport(weapon: weapon, setup: setup, result: result, total: result.total, conditional: conditional)
    }

    /// Flynn's Ring physical bonus in percent by carried weight (Fextralife: ~15% under 2.4,
    /// ~7.5% near 10, ~3.5% near 20, none by 30).
    static func flynnBonus(load: Double) -> Double {
        let table: [(Double, Double)] = [(0, 15), (2.4, 15), (10, 7.5), (20, 3.5), (30, 0)]
        if load >= 30 { return 0 }
        for i in 0..<(table.count - 1) where load >= table[i].0 && load <= table[i + 1].0 {
            let t = (load - table[i].0) / (table[i + 1].0 - table[i].0)
            return table[i].1 + t * (table[i + 1].1 - table[i].1)
        }
        return 0
    }

    // MARK: - What each ring does for this build

    struct RingEffect: Identifiable {
        let ring: Ring
        let lines: [String]
        var id: String { ring.id }
    }

    /// Compares the build with and without each worn ring, so the numbers are specific
    /// to this character ("HP 1000 → 1060", "AR 412 → 494 at or below 20% HP").
    static func ringEffects(for spec: BuildSpec, data: DataStore) -> [RingEffect] {
        let with = report(for: spec, data: data)
        return with.rings.map { ring in
            var without = spec
            without.ringIDs.removeAll { $0 == ring.id }
            let base = report(for: without, data: data)
            var lines: [String] = []

            for stat in StatType.allCases where ring.statBonus(stat) != 0 {
                lines.append("\(stat.displayName) \(base.effectiveStats[stat]) → \(with.effectiveStats[stat])")
            }
            if base.hp != with.hp { lines.append("HP \(base.hp) → \(with.hp)") }
            if base.stamina != with.stamina { lines.append("Stamina \(base.stamina) → \(with.stamina)") }
            if abs(base.capacity - with.capacity) > 0.05 {
                var line = "Equip load capacity \(base.capacity.oneDecimal) → \(with.capacity.oneDecimal)"
                if base.rollTier != with.rollTier { line += " (\(base.rollTier.rawValue) → \(with.rollTier.rawValue))" }
                lines.append(line)
            } else if base.rollTier != with.rollTier {
                lines.append("Its weight changes your roll: \(base.rollTier.rawValue) → \(with.rollTier.rawValue)")
            }
            if abs(base.poise - with.poise) > 0.05 { lines.append("Poise \(base.poise.oneDecimal) → \(with.poise.oneDecimal)") }
            if with.attunementSlots != base.attunementSlots {
                lines.append("Attunement slots \(base.attunementSlots) → \(with.attunementSlots)")
            }
            for (key, value) in ring.absorption.sorted(by: { $0.key < $1.key }) {
                let sign = value >= 0 ? "+" : ""
                lines.append("\(key.capitalized) absorption \(sign)\(Int(value))%")
            }
            if let w = with.primaryWeapon, let b = base.primaryWeapon, abs(w.total - b.total) >= 0.5 {
                lines.append("\(w.weapon.name) AR \(b.total.whole) → \(w.total.whole)")
            }
            if let boost = ring.conditionalAttack, let w = with.primaryWeapon,
               let boosted = w.conditional.first(where: { $0.ring.id == ring.id })?.total {
                var line = "\(w.weapon.name) AR \(w.total.whole) → \(boosted.whole) \(boost.label)"
                if let threshold = boost.hpThreshold {
                    line += " (≤ \(Int((Double(with.hp) * threshold).rounded(.down))) HP)"
                }
                lines.append(line)
            }
            if lines.isEmpty { lines.append(ring.effect + " (not part of the numbers)") }
            return RingEffect(ring: ring, lines: lines)
        }
    }
}

extension SavedBuild {
    var spec: BuildSpec {
        BuildSpec(
            classID: classID,
            stats: statBlock,
            mainHand: WeaponSetup(weaponID: mainHandWeaponID, upgrade: mainHandUpgradeLevel,
                                  infusion: InfusionType(rawValue: mainHandInfusion) ?? .none, twoHanded: twoHanded),
            offHand: WeaponSetup(weaponID: offHandWeaponID, upgrade: offHandUpgradeLevel,
                                 infusion: InfusionType(rawValue: offHandInfusion) ?? .none),
            armor: [.head: headArmorID, .chest: chestArmorID, .hands: handsArmorID, .legs: legsArmorID].compactMapValues { $0 },
            ringIDs: ringIDs
        )
    }

    func setArmor(_ id: String?, for slot: ArmorSlot) {
        switch slot {
        case .head: headArmorID = id
        case .chest: chestArmorID = id
        case .hands: handsArmorID = id
        case .legs: legsArmorID = id
        }
        updatedAt = .now
    }

    func setMainHand(_ setup: WeaponSetup) {
        mainHandWeaponID = setup.weaponID
        mainHandUpgradeLevel = setup.upgrade
        mainHandInfusion = setup.infusion.rawValue
        twoHanded = setup.twoHanded
        updatedAt = .now
    }
}

extension Double {
    var whole: Int { Int(rounded()) }
    var oneDecimal: String { formatted(.number.precision(.fractionLength(1))) }
}
