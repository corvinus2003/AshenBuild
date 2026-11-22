import Foundation

/// All derived-stat math lives here. This is the one file to correct if you spot a
/// discrepancy against a trusted reference (e.g. Fextralife's DS3 wiki) — see the
/// accuracy caveat in the project plan. Every curve below is a breakpoint table +
/// linear interpolation, matching the *shape* of DS3's real soft-cap curves even
/// where an exact value might be a point or two off from the live game.
enum Formulas {

    // MARK: - Generic interpolation helper

    /// Linearly interpolates `table` (must be sorted ascending by x) at `x`, clamping
    /// to the table's first/last values outside its range.
    static func interpolate(_ table: [(x: Int, y: Double)], at x: Int) -> Double {
        guard let first = table.first else { return 0 }
        if x <= first.x { return first.y }
        guard let last = table.last else { return 0 }
        if x >= last.x { return last.y }
        for i in 0..<(table.count - 1) {
            let a = table[i], b = table[i + 1]
            if x >= a.x && x <= b.x {
                if b.x == a.x { return a.y }
                let t = Double(x - a.x) / Double(b.x - a.x)
                return a.y + t * (b.y - a.y)
            }
        }
        return last.y
    }

    // MARK: - Soul Level

    /// SL = 1 at the Deprived's all-10s base (sum of 9 stats = 90). Every point above
    /// that costs one level, matching how DS3 actually derives starting Soul Level.
    static func soulLevel(for stats: StatBlock) -> Int {
        stats.total - 89
    }

    // MARK: - Vigor -> HP

    private static let hpTable: [(x: Int, y: Double)] = [
        // Fextralife DS3 Vigor table (10-99). Below 10 is extrapolated; no class starts under 9.
        (1, 300), (10, 403), (15, 550), (20, 764), (25, 947), (27, 1000), (30, 1056),
        (35, 1141), (40, 1213), (45, 1269), (50, 1300), (55, 1312), (60, 1323),
        (70, 1346), (80, 1367), (90, 1386), (99, 1400)
    ]
    static func hp(vigor: Int) -> Int { Int(interpolate(hpTable, at: vigor).rounded()) }

    // MARK: - Attunement -> FP & attunement slots

    private static let fpTable: [(x: Int, y: Double)] = [
        // Fextralife DS3 Attunement table. Below 10 is extrapolated.
        (1, 44), (10, 93), (15, 120), (20, 150), (25, 189), (27, 206), (30, 233), (35, 280),
        (50, 324), (60, 350), (70, 377), (80, 404), (90, 430), (99, 450)
    ]
    static func fp(attunement: Int) -> Int { Int(interpolate(fpTable, at: attunement).rounded()) }

    private static let slotThresholds: [(attunement: Int, slots: Int)] = [
        (0, 0), (10, 1), (14, 2), (18, 3), (24, 4), (30, 5), (40, 6), (50, 7), (60, 8), (80, 9), (99, 10)
    ]
    static func attunementSlots(attunement: Int) -> Int {
        var slots = 0
        for entry in slotThresholds where attunement >= entry.attunement { slots = entry.slots }
        return slots
    }

    // MARK: - Endurance -> Stamina

    private static let staminaTable: [(x: Int, y: Double)] = [
        // Fextralife DS3 Endurance table (10-50). Past 50 it barely grows.
        (1, 85), (10, 94), (15, 102), (20, 112), (25, 122), (27, 127), (30, 134),
        (35, 146), (40, 160), (50, 161), (99, 170)
    ]
    static func stamina(endurance: Int) -> Int { Int(interpolate(staminaTable, at: endurance).rounded()) }

    // MARK: - Vitality -> Equip Load capacity

    private static let equipLoadTable: [(x: Int, y: Double)] = [
        // Fextralife DS3 Vitality table: +1 equip load per point from 10 to 99.
        (1, 41), (10, 50), (99, 139)
    ]
    static func equipLoadCapacity(vitality: Int) -> Double { interpolate(equipLoadTable, at: vitality) }

    static func equipLoadPercent(currentLoad: Double, vitality: Int) -> Double {
        let cap = equipLoadCapacity(vitality: vitality)
        guard cap > 0 else { return 0 }
        return currentLoad / cap
    }

    enum RollTier: String {
        case fast = "Fast Roll", medium = "Mid Roll", fat = "Fat Roll", overburdened = "Overburdened"
        var thresholdDescription: String {
            switch self {
            case .fast: return "up to 29.9% load"
            case .medium: return "30–70% load"
            case .fat: return "70.1–99.9% load"
            case .overburdened: return "100% load or more"
            }
        }
        /// Highest load fraction that still counts as this tier (nil for overburdened).
        var maxLoadFraction: Double? {
            switch self {
            case .fast: return 0.2999
            case .medium: return 0.70
            case .fat: return 0.9999
            case .overburdened: return nil
            }
        }
    }
    static func rollTier(loadPercent: Double) -> RollTier {
        // The game shows the ratio to one decimal (70.0% is still a mid roll).
        let shown = (loadPercent * 1000).rounded() / 1000
        if shown >= 1.0 { return .overburdened }
        if shown > 0.70 { return .fat }
        if shown >= 0.30 { return .medium }
        return .fast
    }

    // MARK: - Stat scaling curve (0...1 fraction of a grade's multiplierAt99, by raw stat value)

    private static let scalingCurveTable: [(x: Int, y: Double)] = [
        (1, 0.0), (20, 0.35), (40, 0.62), (60, 0.80), (80, 0.93), (99, 1.0)
    ]
    static func scalingCurve(statValue: Int) -> Double { interpolate(scalingCurveTable, at: statValue) }

    // MARK: - Weapon upgrade growth

    /// Fractional growth toward the upgrade path's max, applied to base damage.
    /// e.g. a standard +10 weapon deals roughly 2.3x its +0 base physical damage.
    static func upgradeMultiplier(level: Int, maxUpgrade: Int) -> Double {
        guard maxUpgrade > 0 else { return 1.0 }
        let fraction = Double(max(0, min(level, maxUpgrade))) / Double(maxUpgrade)
        let growthFactor = 1.3
        return 1.0 + growthFactor * fraction
    }

    // MARK: - Attack Rating

    struct WeaponInstance {
        var weapon: Weapon
        var upgradeLevel: Int = 0
        var infusion: InfusionType = .none
        var twoHanded: Bool = false
    }

    struct AttackRatingResult {
        var breakdown: [DamageType: Double]
        var total: Double
        var meetsRequirements: Bool
        var requirementRatio: Double // 1.0 = fully met, <1.0 = underleveled penalty applied
    }

    static func attackRating(for instance: WeaponInstance, stats: StatBlock) -> AttackRatingResult {
        let weapon = instance.weapon

        // Effective stats: two-handing grants 1.5x effective Strength (both for
        // requirements and scaling), matching DS3's two-handing bonus.
        var effective = stats
        if instance.twoHanded && weapon.canTwoHand {
            effective[.strength] = Int((Double(stats[.strength]) * 1.5).rounded(.down))
        }

        // Requirement penalty: ratio of effective stat to requirement, worst stat wins,
        // floored at 40% damage (DS3 never zeroes out damage for being underleveled).
        var worstRatio = 1.0
        for stat: StatType in [.strength, .dexterity, .intelligence, .faith] {
            let requirement = weapon.requirements.requirement(for: stat)
            guard requirement > 0 else { continue }
            let ratio = min(1.0, Double(effective[stat]) / Double(requirement))
            worstRatio = min(worstRatio, ratio)
        }
        let requirementMultiplier = worstRatio < 1.0 ? max(0.4, worstRatio) : 1.0

        // Base damage after upgrade level and infusion's physical multiplier / elemental split.
        let upgradeMult = upgradeMultiplier(level: instance.upgradeLevel, maxUpgrade: weapon.maxUpgrade)
        var breakdown: [DamageType: Double] = [:]
        breakdown[.physical] = weapon.baseDamage.physical * upgradeMult * instance.infusion.physicalMultiplier
        breakdown[.magic] = weapon.baseDamage.magic * upgradeMult
        breakdown[.fire] = weapon.baseDamage.fire * upgradeMult
        breakdown[.lightning] = weapon.baseDamage.lightning * upgradeMult
        breakdown[.dark] = weapon.baseDamage.dark * upgradeMult

        if weapon.infusable, let elementalType = instance.infusion.elementalType {
            let addedElemental = weapon.baseDamage.physical * instance.infusion.elementalFraction * upgradeMult
            breakdown[elementalType, default: 0] += addedElemental
        }

        // Scaling bonus, using the infusion's overridden scaling grades when present.
        let effectiveScaling = (weapon.infusable ? instance.infusion.overriddenScaling : nil) ?? weapon.scaling
        for stat: StatType in [.strength, .dexterity, .intelligence, .faith] {
            let grade = effectiveScaling.grade(for: stat)
            guard grade != .none else { continue }
            let curve = scalingCurve(statValue: effective[stat])
            let bonusFraction = grade.multiplierAt99 * curve
            let bonusAmount = weapon.baseDamage.physical * upgradeMult * bonusFraction
            switch stat {
            case .strength, .dexterity:
                breakdown[.physical, default: 0] += bonusAmount
            case .intelligence:
                breakdown[.magic, default: 0] += bonusAmount
            case .faith:
                // Add to whichever faith-adjacent elemental the weapon already carries;
                // fall back to lightning as the representative "miracle" element.
                if breakdown[.dark, default: 0] > 0 {
                    breakdown[.dark, default: 0] += bonusAmount
                } else if breakdown[.fire, default: 0] > 0 {
                    breakdown[.fire, default: 0] += bonusAmount
                } else {
                    breakdown[.lightning, default: 0] += bonusAmount
                }
            default: break
            }
        }

        for key in breakdown.keys {
            breakdown[key]! *= requirementMultiplier
        }
        let total = breakdown.values.reduce(0, +)

        return AttackRatingResult(
            breakdown: breakdown,
            total: total,
            meetsRequirements: worstRatio >= 1.0,
            requirementRatio: worstRatio
        )
    }

    // MARK: - Defenses & resistances (straight sums of equipped armor)

    static func totalPhysicalDefense(pieces: [ArmorPiece]) -> PhysicalDefense {
        pieces.reduce(into: PhysicalDefense()) { acc, piece in
            acc.standard += piece.physicalDefense.standard
            acc.strike += piece.physicalDefense.strike
            acc.slash += piece.physicalDefense.slash
            acc.thrust += piece.physicalDefense.thrust
        }
    }

    static func totalElementalDefense(pieces: [ArmorPiece]) -> ElementalDefense {
        pieces.reduce(into: ElementalDefense()) { acc, piece in
            acc.magic += piece.elementalDefense.magic
            acc.fire += piece.elementalDefense.fire
            acc.lightning += piece.elementalDefense.lightning
            acc.dark += piece.elementalDefense.dark
        }
    }

    static func totalResistances(pieces: [ArmorPiece]) -> Resistances {
        pieces.reduce(into: Resistances()) { acc, piece in
            acc.bleed += piece.resistances.bleed
            acc.poison += piece.resistances.poison
            acc.frost += piece.resistances.frost
            acc.curse += piece.resistances.curse
        }
    }

    static func totalPoise(pieces: [ArmorPiece]) -> Double {
        pieces.reduce(0) { $0 + $1.poise }
    }
}
