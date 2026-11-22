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
        // Fextralife DS3 Vigor table, every level 10-99. No class starts below Vigor 9.
        (1, 300), (10, 403), (11, 427), (12, 454), (13, 483), (14, 515), (15, 550), (16, 594), (17, 638),
        (18, 681), (19, 723), (20, 764), (21, 804), (22, 842), (23, 879), (24, 914), (25, 947),
        (26, 977), (27, 1000), (28, 1019), (29, 1038), (30, 1056), (31, 1074), (32, 1092), (33, 1109),
        (34, 1125), (35, 1141), (36, 1157), (37, 1172), (38, 1186), (39, 1200), (40, 1213), (41, 1226),
        (42, 1238), (43, 1249), (44, 1260), (45, 1269), (46, 1278), (47, 1285), (48, 1292), (49, 1297),
        (50, 1300), (51, 1302), (52, 1304), (53, 1307), (54, 1309), (55, 1312), (56, 1314), (57, 1316),
        (58, 1319), (59, 1321), (60, 1323), (61, 1326), (62, 1328), (63, 1330), (64, 1333), (65, 1335),
        (66, 1337), (67, 1340), (68, 1342), (69, 1344), (70, 1346), (71, 1348), (72, 1351), (73, 1353),
        (74, 1355), (75, 1357), (76, 1359), (77, 1361), (78, 1363), (79, 1365), (80, 1367), (81, 1369),
        (82, 1371), (83, 1373), (84, 1375), (85, 1377), (86, 1379), (87, 1381), (88, 1383), (89, 1385),
        (90, 1386), (91, 1388), (92, 1390), (93, 1391), (94, 1393), (95, 1395), (96, 1396), (97, 1397),
        (98, 1399), (99, 1400)
    ]
    static func hp(vigor: Int) -> Int { Int(interpolate(hpTable, at: vigor).rounded()) }

    // MARK: - Attunement -> FP & attunement slots

    private static let fpTable: [(x: Int, y: Double)] = [
        // Fextralife DS3 Attunement table: every level 10-35, then the listed points.
        (1, 44), (10, 93), (11, 98), (12, 103), (13, 109), (14, 114), (15, 120), (16, 124), (17, 130),
        (18, 136), (19, 143), (20, 150), (21, 157), (22, 165), (23, 173), (24, 181), (25, 189),
        (26, 198), (27, 206), (28, 215), (29, 224), (30, 233), (31, 242), (32, 251), (33, 260),
        (34, 270), (35, 280),
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
        // Fextralife DS3 Endurance table, every level 9-41; flat to 49, then +10 by 99.
        (1, 85), (9, 92), (10, 94), (11, 95), (12, 97), (13, 98), (14, 100), (15, 102), (16, 104),
        (17, 106), (18, 108), (19, 110), (20, 112), (21, 114), (22, 116), (23, 118), (24, 120),
        (25, 122), (26, 125), (27, 127), (28, 129), (29, 132), (30, 134), (31, 136), (32, 139),
        (33, 141), (34, 144), (35, 146), (36, 149), (37, 152), (38, 154), (39, 157), (40, 160),
        (41, 160),
        (49, 160), (50, 161), (99, 170)
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

    // MARK: - Attack Rating (game params, regulation 1.35)

    /// CalcCorrectGraph curves by id, 0...99 -> percent of the correction that applies.
    static var curves: [Int: [Double]] { DataStore.shared.curves }

    static func curveValue(_ id: Int, _ stat: Int) -> Double {
        guard let curve = curves[id] else { return 0 }
        return curve[max(0, min(curve.count - 1, stat))] / 100
    }

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
        /// Stats below the weapon's requirements (two-handing counted).
        var missing: [StatType]
    }

    /// Attack rating as the game computes it from EquipParamWeapon, ReinforceParamWeapon and
    /// CalcCorrectGraph: each damage type = base x (1 + sum of correction x curve(stat)).
    /// Physical scales with STR, DEX (and Luck for Hollow; Faith for Blessed), magic with INT,
    /// fire with INT and FTH, lightning with FTH, dark with INT and FTH. Two-handing counts
    /// Strength x1.5. The number assumes the requirements are met; `missing` says when not.
    static func attackRating(for instance: WeaponInstance, stats: StatBlock) -> AttackRatingResult {
        let weapon = instance.weapon
        let twoHand = instance.twoHanded && weapon.canTwoHand
        let str = twoHand ? min(Int((Double(stats[.strength]) * 1.5).rounded(.down)), 99) : stats[.strength]
        let req = weapon.requirements(instance.infusion)
        var missing: [StatType] = []
        if str < req.strength { missing.append(.strength) }
        if stats[.dexterity] < req.dexterity { missing.append(.dexterity) }
        if stats[.intelligence] < req.intelligence { missing.append(.intelligence) }
        if stats[.faith] < req.faith { missing.append(.faith) }

        guard let variant = weapon.variant(instance.infusion) else {
            // Shields, bows, crossbows: only the listed base physical attack.
            let base = (weapon.baseAttack ?? 0)
            return AttackRatingResult(breakdown: [.physical: base], total: base, meetsRequirements: missing.isEmpty, missing: missing)
        }
        let L = variant.level(instance.upgradeLevel)
        let g = variant.curves
        let c = { (i: Int) in L[5 + i] / 100 }
        let dex = stats[.dexterity], int = stats[.intelligence], fth = stats[.faith], lck = stats[.luck]
        var physScale = c(0) * curveValue(g[0], str) + c(1) * curveValue(g[0], dex) + c(4) * curveValue(g[0], lck)
        if variant.infusion == .blessed { physScale += c(3) * curveValue(g[0], fth) }
        let parts: [Double] = [
            L[0] * (1 + physScale),
            L[1] * (1 + c(2) * curveValue(g[1], int)),
            L[2] * (1 + c(2) * curveValue(g[2], int) + c(3) * curveValue(g[2], fth)),
            L[3] * (1 + c(3) * curveValue(g[3], fth)),
            L[4] * (1 + c(2) * curveValue(g[4], int) + c(3) * curveValue(g[4], fth)),
        ]
        var breakdown: [DamageType: Double] = [:]
        for (i, type) in DamageType.allCases.enumerated() where parts[i] > 0 { breakdown[type] = parts[i] }
        return AttackRatingResult(breakdown: breakdown, total: parts.reduce(0, +), meetsRequirements: missing.isEmpty, missing: missing)
    }

    // MARK: - Spell buff (catalysts)

    /// Spell buff = 100 x (1 + (INT correction x curve(INT) + FTH correction x curve(FTH)) / 10000), rounded down.
    /// Archdeacon's Great Staff counts as 100 for weapon buffs.
    static func spellBuff(of weapon: Weapon, upgrade: Int, stats: StatBlock) -> Int {
        guard let cat = weapon.catalyst else { return 0 }
        if weapon.name == "Archdeacon's Great Staff" { return 100 }
        let k = cat.spellBuff[max(0, min(cat.spellBuff.count - 1, upgrade))]
        let s = k[0] * curveValue(cat.curves[0], stats[.intelligence]) * 100 + k[1] * curveValue(cat.curves[1], stats[.faith]) * 100
        return Int((100 * (1 + s / 10000)).rounded(.down))
    }

    // MARK: - Defenses (armor values are absorption percentages; they stack multiplicatively)

    static func combinedAbsorption(_ values: [Double]) -> Double {
        (1 - values.reduce(1.0) { $0 * (1 - $1 / 100) }) * 100
    }

    static func totalPhysicalDefense(pieces: [ArmorPiece]) -> PhysicalDefense {
        PhysicalDefense(standard: combinedAbsorption(pieces.map(\.physicalDefense.standard)),
                        strike: combinedAbsorption(pieces.map(\.physicalDefense.strike)),
                        slash: combinedAbsorption(pieces.map(\.physicalDefense.slash)),
                        thrust: combinedAbsorption(pieces.map(\.physicalDefense.thrust)))
    }

    static func totalElementalDefense(pieces: [ArmorPiece]) -> ElementalDefense {
        ElementalDefense(magic: combinedAbsorption(pieces.map(\.elementalDefense.magic)),
                         fire: combinedAbsorption(pieces.map(\.elementalDefense.fire)),
                         lightning: combinedAbsorption(pieces.map(\.elementalDefense.lightning)),
                         dark: combinedAbsorption(pieces.map(\.elementalDefense.dark)))
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
