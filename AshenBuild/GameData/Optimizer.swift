import Foundation

/// What a respec must keep. Points not needed here go into damage, then survivability.
struct RespecGoal: Hashable {
    var minVigor: Int
    var minEndurance: Int
    var minAttunement: Int
    /// Roll to keep with the build's gear. nil keeps the current Vitality as it is.
    var roll: Formulas.RollTier?

    /// "Keep everything except the damage stats", used for the verdict.
    static func keepingSurvivability(of spec: BuildSpec) -> RespecGoal {
        RespecGoal(minVigor: spec.stats[.vigor], minEndurance: spec.stats[.endurance],
                   minAttunement: spec.stats[.attunement], roll: nil)
    }
}

struct RespecResult {
    let stats: StatBlock
    let report: BuildReport
    /// Levels missing to satisfy the goal at this Soul Level (0 when it fits).
    let shortfall: Int
    var feasible: Bool { shortfall == 0 }
}

struct Issue: Identifiable, Hashable {
    enum Kind { case good, info, warning }
    let kind: Kind
    let title: String
    let detail: String
    var id: String { title }
}

struct Analysis {
    let current: BuildReport
    let best: RespecResult
    /// current AR / best AR at the same Soul Level and survivability, nil without a weapon.
    let score: Double?
    let issues: [Issue]

    var verdict: String {
        guard let score else { return "Equip a weapon to rate this build" }
        switch score {
        case 0.98...: return "Optimized"
        case 0.90..<0.98: return "Nearly optimized"
        default: return "Room to improve"
        }
    }
}

struct WeaponOption: Identifiable {
    let setup: WeaponSetup
    let weapon: Weapon
    let respec: RespecResult
    var id: String { "\(weapon.id)-\(setup.infusion.rawValue)" }
    var attackRating: Double { respec.report.mainHand?.total ?? 0 }
}

enum ArmorGoal: String, CaseIterable, Identifiable {
    case poise = "Poise"
    case physical = "Physical"
    case strike = "Strike"
    case slash = "Slash"
    case thrust = "Thrust"
    case magic = "Magic"
    case fire = "Fire"
    case lightning = "Lightning"
    case dark = "Dark"
    case elemental = "All Elements"
    case bleed = "Bleed"
    case poison = "Poison"
    case frost = "Frost"
    case curse = "Curse"

    var id: Self { self }

    /// Absorptions combine multiplicatively in the game; poise and resistances add up.
    var isAbsorption: Bool {
        switch self {
        case .poise, .bleed, .poison, .frost, .curse: return false
        default: return true
        }
    }

    func total(_ pieces: [ArmorPiece]) -> Double {
        isAbsorption ? Formulas.combinedAbsorption(pieces.map(value)) : pieces.reduce(0) { $0 + value($1) }
    }

    func value(_ piece: ArmorPiece) -> Double {
        switch self {
        case .poise: return piece.poise
        case .physical: return piece.physicalDefense.standard
        case .strike: return piece.physicalDefense.strike
        case .slash: return piece.physicalDefense.slash
        case .thrust: return piece.physicalDefense.thrust
        case .magic: return piece.elementalDefense.magic
        case .fire: return piece.elementalDefense.fire
        case .lightning: return piece.elementalDefense.lightning
        case .dark: return piece.elementalDefense.dark
        case .elemental:
            let e = piece.elementalDefense
            return (e.magic + e.fire + e.lightning + e.dark) / 4
        case .bleed: return piece.resistances.bleed
        case .poison: return piece.resistances.poison
        case .frost: return piece.resistances.frost
        case .curse: return piece.resistances.curse
        }
    }
}

struct ArmorSet: Identifiable {
    let pieces: [ArmorSlot: ArmorPiece]
    let weight: Double
    let value: Double
    let poise: Double
    let loadFraction: Double
    var id: String { ArmorSlot.allCases.map { pieces[$0]?.id ?? "-" }.joined(separator: "|") }
}

enum Optimizer {

    static let damageStats: [StatType] = [.strength, .dexterity, .intelligence, .faith]

    // MARK: - Respec (Rosaria's Bed Chamber)

    /// Redistributes the build's points at the same Soul Level and starting class.
    ///
    /// 1. Floors: class base, the goal's Vigor/Endurance/Attunement, enough Vitality for
    ///    the roll, and the stat requirements of both weapons (ring bonuses counted).
    /// 2. Each remaining point goes to the damage stat that adds the most attack rating.
    ///    Scaling curves only flatten as a stat rises (diminishing returns) and each stat's
    ///    contribution adds up independently, so this greedy pass finds the best split.
    /// 3. Points that add (almost) no damage go to Vigor, then Endurance, then Vitality.
    static func respec(_ spec: BuildSpec, goal: RespecGoal, data: DataStore) -> RespecResult {
        let base = data.startingClass(spec.classID)?.statBlock ?? StatBlock()
        let rings = spec.ringIDs.compactMap { data.ring($0) }
        let bonus = Dictionary(uniqueKeysWithValues: StatType.allCases.map { s in (s, rings.reduce(0) { $0 + $1.statBonus(s) }) })
        let budget = spec.stats.total

        var stats = base
        stats[.vigor] = max(base[.vigor], goal.minVigor)
        stats[.endurance] = max(base[.endurance], goal.minEndurance)
        stats[.attunement] = max(base[.attunement], goal.minAttunement)
        if let roll = goal.roll {
            stats[.vitality] = vitalityNeeded(for: roll, spec: spec, data: data) ?? 99
        } else {
            stats[.vitality] = max(base[.vitality], spec.stats[.vitality])
        }

        // Weapon requirements (two-handing counts Strength 1.5x for the main hand).
        for (setup, isMain) in [(spec.mainHand, true), (spec.offHand, false)] {
            guard let weapon = data.weapon(setup.weaponID) else { continue }
            for stat in damageStats {
                let required = weapon.requirements(setup.infusion).requirement(for: stat)
                guard required > 0 else { continue }
                var needed = required - bonus[stat, default: 0]
                if stat == .strength && isMain && setup.twoHanded && weapon.canTwoHand {
                    needed = Int((Double(required) / 1.5).rounded(.up)) - bonus[stat, default: 0]
                    // floor(x * 1.5) can still fall one short; nudge until it meets.
                    while Int((Double(needed + bonus[stat, default: 0]) * 1.5).rounded(.down)) < required { needed += 1 }
                }
                stats[stat] = max(stats[stat], min(99, needed))
            }
        }

        // A weapon-buff spell must stay castable.
        if let buff = data.spell(spec.loadout.buffID), buff.school != .item {
            stats[.intelligence] = max(stats[.intelligence], min(99, buff.int - bonus[.intelligence, default: 0]))
            stats[.faith] = max(stats[.faith], min(99, buff.fth - bonus[.faith, default: 0]))
        }

        var remaining = budget - stats.total
        if remaining < 0 {
            var short = spec
            short.stats = stats
            return RespecResult(stats: stats, report: BuildCalculator.report(for: short, data: data), shortfall: -remaining)
        }

        // Greedy damage allocation on the primary weapon.
        let primary = spec.mainHand.weaponID != nil ? spec.mainHand : spec.offHand
        let load = BuildCalculator.totalWeight(spec: spec, rings: rings,
                                               pieces: ArmorSlot.allCases.compactMap { data.armorPiece(spec.armor[$0]) }, data: data)
        let buff = data.spell(spec.loadout.buffID)
        func attack(_ s: StatBlock) -> Double {
            let effective = BuildCalculator.effectiveStats(s, rings: rings)
            let spellBuffs = BuildCalculator.spellBuffs(spec: spec, stats: effective, data: data)
            return BuildCalculator.weaponReportWithBuff(primary, buff: primary == spec.mainHand ? buff : nil, effective: effective,
                                                        rings: rings, load: load, spellBuffs: spellBuffs, data: data).0?.total ?? 0
        }
        var currentAR = attack(stats)
        while remaining > 0 {
            var bestStat: StatType?
            var bestGain = 0.25   // below this a point is better spent on HP
            for stat in damageStats where stats[stat] < 99 {
                var trial = stats
                trial[stat] += 1
                let gain = attack(trial) - currentAR
                if gain > bestGain { bestGain = gain; bestStat = stat }
            }
            guard let stat = bestStat else { break }
            stats[stat] += 1
            currentAR += bestGain
            remaining -= 1
        }

        // Leftovers: Vigor to 50, Endurance to 40, Vitality, then Vigor to 99.
        for (stat, cap) in [(StatType.vigor, 50), (.endurance, 40), (.vitality, 99), (.vigor, 99)] where remaining > 0 {
            let add = min(remaining, max(0, cap - stats[stat]))
            stats[stat] += add
            remaining -= add
        }

        var result = spec
        result.stats = stats
        return RespecResult(stats: stats, report: BuildCalculator.report(for: result, data: data), shortfall: 0)
    }

    /// Lowest Vitality (at or above the class base) that keeps this gear within `roll`.
    static func vitalityNeeded(for roll: Formulas.RollTier, spec: BuildSpec, data: DataStore) -> Int? {
        let base = data.startingClass(spec.classID)?.statBlock[.vitality] ?? 1
        var trial = spec
        for vit in base...99 {
            trial.stats[.vitality] = vit
            if rank(BuildCalculator.report(for: trial, data: data).rollTier) <= rank(roll) { return vit }
        }
        return nil
    }

    static func rank(_ tier: Formulas.RollTier) -> Int {
        switch tier {
        case .fast: return 0
        case .medium: return 1
        case .fat: return 2
        case .overburdened: return 3
        }
    }

    // MARK: - Verdict

    static func analyze(_ spec: BuildSpec, data: DataStore) -> Analysis {
        let current = BuildCalculator.report(for: spec, data: data)
        let best = respec(spec, goal: .keepingSurvivability(of: spec), data: data)
        var issues: [Issue] = []

        var score: Double?
        if let now = current.primaryWeapon?.total, let top = best.report.primaryWeapon?.total, top > 0 {
            score = min(1, now / top)
            if now + 0.5 < top {
                issues.append(Issue(kind: .warning, title: "Respec could add \(Int((top - now).rounded())) AR",
                                    detail: "Same Soul Level, same Vigor, Endurance, Attunement and Vitality: \(current.primaryWeapon!.weapon.name) goes from \(now.whole) to \(top.whole)."))
            } else {
                issues.append(Issue(kind: .good, title: "Damage stats are well spent",
                                    detail: "No other split of your Strength, Dexterity, Intelligence, Faith and Luck gives more attack rating."))
            }
        }

        // Requirements.
        for report in [current.mainHand, current.offHand].compactMap({ $0 }) where !report.result.meetsRequirements {
            let missing = damageStats.compactMap { stat -> String? in
                let req = report.weapon.requirements(report.setup.infusion).requirement(for: stat)
                var have = current.effectiveStats[stat]
                if stat == .strength && report.setup.twoHanded && report.weapon.canTwoHand {
                    have = Int((Double(have) * 1.5).rounded(.down))
                }
                return req > have ? "\(stat.shortName) \(req) (you have \(have))" : nil
            }
            issues.append(Issue(kind: .warning, title: "\(report.weapon.name) is under-levelled",
                                detail: "Needs " + missing.joined(separator: ", ") + ". Below the requirements the weapon deals far less damage in the game."))
        }

        // Points in stats nothing uses.
        let equipped = spec.allWeapons.compactMap { setup -> (Weapon, WeaponSetup)? in
            data.weapon(setup.weaponID).map { ($0, setup) }
        }
        let attuned = spec.loadout.spellIDs.compactMap { data.spell($0) } + [data.spell(spec.loadout.buffID)].compactMap { $0 }
        let weapons = equipped
        for stat in damageStats {
            let scales = equipped.contains { w, setup in
                if let v = w.variant(setup.infusion), v.grade(stat, at: setup.upgrade) != .none { return true }
                if let cat = w.catalyst {
                    let k = cat.spellBuff[safe: setup.upgrade] ?? cat.spellBuff.last ?? [0, 0]
                    return (stat == .intelligence && k[0] > 0) || (stat == .faith && k[1] > 0)
                }
                return false
            }
            let spellNeed = attuned.map { stat == .intelligence ? $0.int : stat == .faith ? $0.fth : 0 }.max() ?? 0
            let need = max(spellNeed, equipped.map { $0.0.requirements($0.1.infusion).requirement(for: stat) }.max() ?? 0)
            let floor = max(current.baseStats[stat], need)
            let extra = spec.stats[stat] - floor
            if !scales && extra > 0 && !weapons.isEmpty {
                issues.append(Issue(kind: .info, title: "\(extra) points in \(stat.displayName) do nothing",
                                    detail: "Nothing you equip scales with \(stat.displayName), and the highest requirement (weapons and spells) is \(need)."))
            }
        }
        let luckExtra = spec.stats[.luck] - current.baseStats[.luck]
        if luckExtra > 0 {
            issues.append(Issue(kind: .info, title: "\(luckExtra) points in Luck",
                                detail: "Luck only helps bleed, poison and Hollow builds and item discovery; it adds no attack rating here."))
        }

        // Soft caps.
        if spec.stats[.vigor] > 50 {
            issues.append(Issue(kind: .info, title: "Vigor past 50",
                                detail: "From 51 to 99 Vigor adds only about 100 HP in total."))
        }
        if spec.stats[.endurance] > 40 {
            issues.append(Issue(kind: .info, title: "Endurance past 40",
                                detail: "Stamina barely grows after 40 (160 at 40, 161 at 50)."))
        }
        if spec.stats[.attunement] > 35 && current.attunementSlots < 6 {
            issues.append(Issue(kind: .info, title: "Attunement past 35",
                                detail: "FP gains slow down after 35. Worth it only for heavy casting."))
        }
        if current.soulLevel >= 50 && spec.stats[.vigor] < 25 {
            issues.append(Issue(kind: .info, title: "Low Vigor for SL \(current.soulLevel)",
                                detail: "\(current.hp) HP. 27 Vigor gives 1000 HP, a common target by this level."))
        }

        // Roll.
        switch current.rollTier {
        case .overburdened:
            issues.append(Issue(kind: .warning, title: "Overburdened",
                                detail: "You can't roll properly. " + rollFix(to: .fat, spec: spec, current: current, data: data)))
        case .fat:
            issues.append(Issue(kind: .warning, title: "Fat Roll",
                                detail: rollFix(to: .medium, spec: spec, current: current, data: data)))
        case .medium, .fast:
            if let needed = vitalityNeeded(for: current.rollTier, spec: spec, data: data), needed < spec.stats[.vitality] {
                issues.append(Issue(kind: .info, title: "\(spec.stats[.vitality] - needed) spare Vitality",
                                    detail: "Your gear keeps a \(current.rollTier.rawValue) with \(needed) Vitality. The extra points only help if you plan heavier gear."))
            }
        }

        // Starting class (new characters only: Rosaria can't change class).
        if let bestClass = data.startingClasses.min(by: { levelsNeeded(spec.stats, $0) < levelsNeeded(spec.stats, $1) }) {
            let saved = current.soulLevel - levelsNeeded(spec.stats, bestClass)
            if saved > 0 && bestClass.id != spec.classID {
                issues.append(Issue(kind: .info, title: "\(bestClass.name) reaches these stats \(saved) levels sooner",
                                    detail: "For a new character. Rosaria can reallocate points but can't change your starting class."))
            }
        }

        return Analysis(current: current, best: best, score: score, issues: issues)
    }

    private static func rollFix(to target: Formulas.RollTier, spec: BuildSpec, current: BuildReport, data: DataStore) -> String {
        let maxLoad = current.capacity * (target.maxLoadFraction ?? 1)
        let drop = max(0, current.load - maxLoad)
        var text = "Drop \(drop.oneDecimal) weight"
        if let vit = vitalityNeeded(for: target, spec: spec, data: data) {
            text += " or raise Vitality to \(vit) (+\(vit - spec.stats[.vitality]))"
        }
        return text + " for a \(target.rawValue)."
    }

    /// Soul Level needed to reach `stats` from a class (points under its base are wasted).
    static func levelsNeeded(_ stats: StatBlock, _ cls: StartingClass) -> Int {
        let base = cls.statBlock
        return StatType.allCases.reduce(0) { $0 + max(stats[$1], base[$1]) } - 89
    }

    // MARK: - Alternatives

    /// Every infusion of the main-hand weapon, each with its best respec.
    static func infusionOptions(_ spec: BuildSpec, goal: RespecGoal, data: DataStore) -> [WeaponOption] {
        guard let weapon = data.weapon(spec.mainHand.weaponID), weapon.infusable else { return [] }
        return weapon.infusions.map { infusion in
            var trial = spec
            trial.mainHand.infusion = infusion
            return WeaponOption(setup: trial.mainHand, weapon: weapon, respec: respec(trial, goal: goal, data: data))
        }
        .sorted { $0.attackRating > $1.attackRating }
    }

    /// The strongest main-hand weapons for this character after a respec, each with its
    /// best infusion, at the same upgrade progress as the current weapon.
    static func weaponOptions(_ spec: BuildSpec, goal: RespecGoal, data: DataStore, limit: Int = 6) -> [WeaponOption] {
        let current = data.weapon(spec.mainHand.weaponID)
        let progress = current.map { Double(spec.mainHand.upgrade) / Double(max(1, $0.maxUpgrade)) } ?? 1
        // A heavier weapon must not silently cost the build its roll: keep the current
        // roll (paying for any Vitality it needs) unless the goal names one.
        var goal = goal
        if goal.roll == nil {
            let tier = BuildCalculator.report(for: spec, data: data).rollTier
            goal.roll = tier == .overburdened ? .fat : tier
        }

        let candidates = data.weapons.filter { w in
            w.hasAttackTables && w.kind == .melee
        }
        let options = candidates.compactMap { weapon -> WeaponOption? in
            let upgrade = Int((progress * Double(weapon.maxUpgrade)).rounded())
            let infusions = weapon.infusions
            return infusions.map { infusion -> WeaponOption in
                var trial = spec
                trial.mainHand = WeaponSetup(weaponID: weapon.id, upgrade: upgrade, infusion: infusion,
                                             twoHanded: spec.mainHand.twoHanded && weapon.canTwoHand)
                return WeaponOption(setup: trial.mainHand, weapon: weapon, respec: respec(trial, goal: goal, data: data))
            }
            .filter { $0.respec.feasible }
            .max { $0.attackRating < $1.attackRating }
        }
        return Array(options.sorted { $0.attackRating > $1.attackRating }.prefix(limit))
    }

    // MARK: - Armor min-maxing

    /// Best armor sets for `goal` that keep the build within `roll`, optionally with a
    /// poise floor. Exhaustive over the four slots after dropping pieces another piece in
    /// the same slot beats on weight, the goal and poise at once.
    static func bestArmor(_ spec: BuildSpec, goal: ArmorGoal, roll: Formulas.RollTier, minPoise: Double,
                          data: DataStore, limit: Int = 5) -> [ArmorSet] {
        var naked = spec
        naked.armor = [:]
        let base = BuildCalculator.report(for: naked, data: data)
        let maxFraction = roll.maxLoadFraction ?? 10
        let budget = base.capacity * maxFraction - base.load
        guard budget >= 0 else { return [] }
        let ringPoise = base.poise

        func options(_ slot: ArmorSlot) -> [ArmorPiece?] {
            let pieces = data.armor(in: slot).filter { $0.weight <= budget + 0.0001 }
            let kept = pieces.filter { p in
                !pieces.contains { q in
                    q.id != p.id && q.weight <= p.weight && goal.value(q) >= goal.value(p) && q.poise >= p.poise &&
                    (q.weight < p.weight || goal.value(q) > goal.value(p) || q.poise > p.poise)
                }
            }
            return [nil] + kept
        }
        let head = options(.head), chest = options(.chest), hands = options(.hands), legs = options(.legs)

        var results: [ArmorSet] = []
        for h in head { for c in chest { for g in hands { for l in legs {
            let set = [h, c, g, l].compactMap { $0 }
            let weight = set.reduce(0) { $0 + $1.weight }
            guard weight <= budget + 0.0001 else { continue }
            let poise = set.reduce(0) { $0 + $1.poise } + ringPoise
            guard poise >= minPoise else { continue }
            let fraction = (base.load + weight) / base.capacity
            guard rank(Formulas.rollTier(loadPercent: fraction)) <= rank(roll) else { continue }
            var pieces: [ArmorSlot: ArmorPiece] = [:]
            for p in set { pieces[p.slot] = p }
            results.append(ArmorSet(pieces: pieces, weight: weight, value: goal.total(set),
                                    poise: poise, loadFraction: fraction))
        }}}}
        results.sort { ($0.value, -$0.weight) > ($1.value, -$1.weight) }
        return Array(results.prefix(limit))
    }
}
