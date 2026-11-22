import SwiftUI

/// What a weapon is used for. Only melee weapons carry the full attack-rating tables.
enum WeaponKind: String, Codable, CaseIterable {
    case melee, catalyst, shield, bow, greatbow, crossbow

    var displayName: String {
        switch self {
        case .melee: return "Melee"
        case .catalyst: return "Catalyst"
        case .shield: return "Shield"
        case .bow: return "Bow"
        case .greatbow: return "Greatbow"
        case .crossbow: return "Crossbow"
        }
    }
}

/// Scaling grade as the game's equipment screen shows it, from the correction value.
enum ScalingGrade: String {
    case s = "S", a = "A", b = "B", c = "C", d = "D", e = "E", none = "-"

    init(correction value: Double) {
        switch value {
        case 175...: self = .s
        case 140..<175: self = .a
        case 90..<140: self = .b
        case 60..<90: self = .c
        case 25..<60: self = .d
        case 0.5..<25: self = .e
        default: self = .none
        }
    }
}

enum DamageType: String, Codable, CaseIterable, Identifiable {
    case physical, magic, fire, lightning, dark
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    var index: Int { DamageType.allCases.firstIndex(of: self)! }
}

enum InfusionType: String, Codable, CaseIterable, Identifiable {
    case none = "Normal", heavy = "Heavy", sharp = "Sharp", refined = "Refined"
    case simple = "Simple", crystal = "Crystal", fire = "Fire", chaos = "Chaos"
    case lightning = "Lightning", deep = "Deep", dark = "Dark", poison = "Poison"
    case blood = "Blood", raw = "Raw", blessed = "Blessed", hollow = "Hollow"

    var id: String { rawValue }
    var displayName: String { rawValue }
}

struct WeaponRequirements: Codable, Hashable {
    var strength = 0, dexterity = 0, intelligence = 0, faith = 0

    init(strength: Int = 0, dexterity: Int = 0, intelligence: Int = 0, faith: Int = 0) {
        self.strength = strength; self.dexterity = dexterity; self.intelligence = intelligence; self.faith = faith
    }
    init(_ values: [Int]) {
        self.init(strength: values[safe: 0] ?? 0, dexterity: values[safe: 1] ?? 0,
                  intelligence: values[safe: 2] ?? 0, faith: values[safe: 3] ?? 0)
    }

    func requirement(for stat: StatType) -> Int {
        switch stat {
        case .strength: return strength
        case .dexterity: return dexterity
        case .intelligence: return intelligence
        case .faith: return faith
        default: return 0
        }
    }
}

/// One infusion of a melee weapon, straight from the game's params (regulation 1.35):
/// `levels[upgrade]` = [physical, magic, fire, lightning, dark base attack,
///                      STR, DEX, INT, FTH, LCK correction, bleed, frost, status rate].
/// `curves` = CalcCorrectGraph id per damage type.
struct WeaponVariant: Codable, Hashable {
    let infusion: InfusionType
    let requirements: WeaponRequirements
    let curves: [Int]
    let levels: [[Double]]
    let notBuffable: Bool

    enum CodingKeys: String, CodingKey { case infusion, req, sat, lv, nb }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        infusion = InfusionType(rawValue: try c.decode(String.self, forKey: .infusion)) ?? .none
        requirements = WeaponRequirements(try c.decode([Int].self, forKey: .req))
        curves = try c.decode([Int].self, forKey: .sat)
        levels = try c.decode([[Double]].self, forKey: .lv)
        notBuffable = try c.decodeIfPresent(Bool.self, forKey: .nb) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(infusion.rawValue, forKey: .infusion)
        try c.encode([requirements.strength, requirements.dexterity, requirements.intelligence, requirements.faith], forKey: .req)
        try c.encode(curves, forKey: .sat)
        try c.encode(levels, forKey: .lv)
        try c.encode(notBuffable, forKey: .nb)
    }

    func level(_ upgrade: Int) -> [Double] { levels[max(0, min(levels.count - 1, upgrade))] }

    func baseDamage(at upgrade: Int) -> [Double] { Array(level(upgrade)[0..<5]) }

    func grade(_ stat: StatType, at upgrade: Int) -> ScalingGrade {
        let index: Int
        switch stat {
        case .strength: index = 5
        case .dexterity: index = 6
        case .intelligence: index = 7
        case .faith: index = 8
        case .luck: index = 9
        default: return .none
        }
        return ScalingGrade(correction: level(upgrade)[index])
    }

    /// Weapons with elemental base damage can't take weapon buffs, nor can rows the game marks.
    func isBuffable(at upgrade: Int) -> Bool {
        guard !notBuffable else { return false }
        let base = level(upgrade)
        return base[1] == 0 && base[2] == 0 && base[3] == 0 && base[4] == 0
    }
}

/// How a catalyst turns Intelligence / Faith into spell buff (EquipParamWeapon + ReinforceParamWeapon).
struct CatalystInfo: Codable, Hashable {
    /// [sorcery, miracle, pyromancy]
    let schools: [Int]
    /// CalcCorrectGraph ids for Intelligence and Faith.
    let curves: [Int]
    /// Per upgrade level: [Intelligence correction, Faith correction].
    let spellBuff: [[Double]]

    func casts(_ school: SpellSchool) -> Bool {
        switch school {
        case .sorcery: return schools[safe: 0] == 1
        case .miracle: return schools[safe: 1] == 1
        case .pyromancy: return schools[safe: 2] == 1
        case .item: return false
        }
    }
}

struct Weapon: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let kind: WeaponKind
    let category: String
    let weight: Double
    let maxUpgrade: Int
    let paired: Bool
    let variants: [WeaponVariant]
    let catalyst: CatalystInfo?
    /// Non-melee items only.
    let flatRequirements: WeaponRequirements?
    let baseAttack: Double?
    let absorption: Double?
    let stability: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, kind, category, weight, maxUpgrade, paired, variants, catalyst, req, baseAttack, absorption, stability
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        kind = try c.decode(WeaponKind.self, forKey: .kind)
        category = try c.decode(String.self, forKey: .category)
        weight = try c.decode(Double.self, forKey: .weight)
        maxUpgrade = try c.decode(Int.self, forKey: .maxUpgrade)
        paired = try c.decodeIfPresent(Bool.self, forKey: .paired) ?? false
        variants = try c.decodeIfPresent([WeaponVariant].self, forKey: .variants) ?? []
        catalyst = try c.decodeIfPresent(CatalystInfo.self, forKey: .catalyst)
        flatRequirements = try c.decodeIfPresent([Int].self, forKey: .req).map(WeaponRequirements.init)
        baseAttack = try c.decodeIfPresent(Double.self, forKey: .baseAttack)
        absorption = try c.decodeIfPresent(Double.self, forKey: .absorption)
        stability = try c.decodeIfPresent(Double.self, forKey: .stability)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(name, forKey: .name); try c.encode(kind, forKey: .kind)
        try c.encode(category, forKey: .category); try c.encode(weight, forKey: .weight); try c.encode(maxUpgrade, forKey: .maxUpgrade)
    }

    static func == (a: Weapon, b: Weapon) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var hasAttackTables: Bool { !variants.isEmpty }
    var infusable: Bool { variants.count > 1 }
    var infusions: [InfusionType] { variants.map(\.infusion) }
    var isCastingTool: Bool { catalyst != nil }
    var isShield: Bool { kind == .shield }
    var canTwoHand: Bool { kind != .catalyst && kind != .shield }

    func variant(_ infusion: InfusionType) -> WeaponVariant? {
        variants.first { $0.infusion == infusion } ?? variants.first
    }

    func requirements(_ infusion: InfusionType) -> WeaponRequirements {
        variant(infusion)?.requirements ?? flatRequirements ?? WeaponRequirements()
    }

    /// Short community abbreviation shown on weapon cards.
    var abbreviation: String {
        switch category {
        case "Dagger": return "DGR"
        case "Straight Sword": return "SS"
        case "Greatsword": return "GS"
        case "Ultra Greatsword": return "UGS"
        case "Curved Sword": return "CS"
        case "Curved Greatsword": return "CGS"
        case "Katana": return "KAT"
        case "Thrusting Sword": return "TS"
        case "Axe": return "AXE"
        case "Greataxe": return "GA"
        case "Hammer": return "HAM"
        case "Great Hammer": return "GH"
        case "Spear": return "SPR"
        case "Pike": return "PIK"
        case "Halberd": return "HAL"
        case "Reaper": return "RPR"
        case "Whip": return "WHP"
        case "Fist": return "FST"
        case "Claw": return "CLW"
        case "Torch": return "TCH"
        case "Staff": return "STF"
        case "Sacred Chime": return "CHM"
        case "Talisman": return "TAL"
        case "Pyromancy Flame": return "PYR"
        case "Small Shield": return "SH"
        case "Medium Shield": return "SH"
        case "Greatshield": return "GSH"
        case "Bow": return "BOW"
        case "Greatbow": return "GB"
        case "Crossbow": return "XBW"
        default: return String(category.prefix(3)).uppercased()
        }
    }

    var tint: Color {
        switch kind {
        case .melee: return catalyst != nil ? .purple : .accentColor
        case .catalyst: return .purple
        case .shield: return .gray
        case .bow, .greatbow, .crossbow: return .teal
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
