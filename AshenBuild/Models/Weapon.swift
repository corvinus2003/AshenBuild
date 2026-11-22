import Foundation

enum WeaponCategory: String, Codable, CaseIterable, Identifiable {
    case dagger, straightSword, greatsword, ultraGreatsword, curvedSword, katana
    case thrustingSword, axe, greataxe, hammer, greatHammer, spear, halberd
    case whip, fist, bow, greatbow, crossbow
    case sorceryStaff, talisman, chime, pyromancyFlame
    case smallShield, greatshield

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dagger: return "Dagger"
        case .straightSword: return "Straight Sword"
        case .greatsword: return "Greatsword"
        case .ultraGreatsword: return "Ultra Greatsword"
        case .curvedSword: return "Curved Sword"
        case .katana: return "Katana"
        case .thrustingSword: return "Thrusting Sword"
        case .axe: return "Axe"
        case .greataxe: return "Greataxe"
        case .hammer: return "Hammer"
        case .greatHammer: return "Great Hammer"
        case .spear: return "Spear"
        case .halberd: return "Halberd"
        case .whip: return "Whip"
        case .fist: return "Fist Weapon"
        case .bow: return "Bow"
        case .greatbow: return "Greatbow"
        case .crossbow: return "Crossbow"
        case .sorceryStaff: return "Sorcery Catalyst"
        case .talisman: return "Talisman"
        case .chime: return "Chime"
        case .pyromancyFlame: return "Pyromancy Flame"
        case .smallShield: return "Small Shield"
        case .greatshield: return "Greatshield"
        }
    }

    /// Casting tools don't get a meaningful two-handing bonus the way melee weapons do.
    var isCastingTool: Bool {
        switch self {
        case .sorceryStaff, .talisman, .chime, .pyromancyFlame: return true
        default: return false
        }
    }

    var isShield: Bool {
        self == .smallShield || self == .greatshield
    }
}

enum ScalingGrade: String, Codable, CaseIterable {
    case s = "S", a = "A", b = "B", c = "C", d = "D", e = "E", none = "-"

    /// Fraction of a stat's max scaling bonus granted at 99 points in that stat.
    /// These approximate DS3's real per-grade scaling curves (soft-capped, S > A > B > C > D > E).
    var multiplierAt99: Double {
        switch self {
        case .s: return 1.10
        case .a: return 0.90
        case .b: return 0.70
        case .c: return 0.50
        case .d: return 0.30
        case .e: return 0.15
        case .none: return 0.0
        }
    }
}

enum DamageType: String, Codable, CaseIterable, Identifiable {
    case physical, magic, fire, lightning, dark
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum InfusionType: String, Codable, CaseIterable, Identifiable {
    case none = "Normal", heavy = "Heavy", sharp = "Sharp", refined = "Refined"
    case raw = "Raw", crystal = "Crystal", simple = "Simple", fire = "Fire"
    case chaos = "Chaos", lightning = "Lightning", deep = "Deep", dark = "Dark"
    case poison = "Poison", blood = "Blood", blessed = "Blessed", hollow = "Hollow"

    var id: String { rawValue }
    var displayName: String { rawValue }

    /// Physical damage multiplier applied by this infusion (most infusions trade some
    /// physical damage for an elemental split or a scaling change).
    var physicalMultiplier: Double {
        switch self {
        case .none, .heavy, .sharp, .refined, .crystal, .blood, .hollow: return 1.0
        case .raw: return 0.90
        case .simple: return 0.90
        case .fire, .chaos, .lightning, .dark, .deep, .poison, .blessed: return 0.75
        }
    }

    /// Elemental damage this infusion adds, expressed as a fraction of the weapon's
    /// *unmodified* base physical damage (a simplified stand-in for the real per-weapon tables).
    var elementalFraction: Double {
        switch self {
        case .fire, .chaos, .lightning, .dark, .poison, .blessed, .deep: return 0.55
        default: return 0.0
        }
    }

    var elementalType: DamageType? {
        switch self {
        case .fire, .chaos: return .fire
        case .lightning: return .lightning
        case .dark, .deep: return .dark
        default: return nil
        }
    }

    /// The full replacement STR/DEX/INT/FAI scaling grades once this infusion is applied.
    /// `.none` (the "Normal" infusion) returns nil, meaning "keep the weapon's own scaling".
    /// These are simplified stand-ins for DS3's real per-infusion scaling tables.
    var overriddenScaling: WeaponScaling? {
        switch self {
        case .none: return nil
        case .heavy: return WeaponScaling(strength: .a, dexterity: .none, intelligence: .none, faith: .none)
        case .sharp: return WeaponScaling(strength: .none, dexterity: .a, intelligence: .none, faith: .none)
        case .refined: return WeaponScaling(strength: .b, dexterity: .b, intelligence: .none, faith: .none)
        case .raw: return WeaponScaling(strength: .none, dexterity: .none, intelligence: .none, faith: .none)
        case .crystal: return WeaponScaling(strength: .b, dexterity: .b, intelligence: .none, faith: .none)
        case .simple: return WeaponScaling(strength: .none, dexterity: .none, intelligence: .d, faith: .none)
        case .fire: return WeaponScaling(strength: .none, dexterity: .none, intelligence: .none, faith: .none)
        case .chaos: return WeaponScaling(strength: .none, dexterity: .none, intelligence: .none, faith: .none)
        case .lightning: return WeaponScaling(strength: .none, dexterity: .none, intelligence: .none, faith: .c)
        case .deep: return WeaponScaling(strength: .none, dexterity: .none, intelligence: .none, faith: .c)
        case .dark: return WeaponScaling(strength: .none, dexterity: .none, intelligence: .c, faith: .c)
        case .poison: return WeaponScaling(strength: .none, dexterity: .none, intelligence: .none, faith: .none)
        case .blood: return WeaponScaling(strength: .none, dexterity: .d, intelligence: .none, faith: .none)
        case .blessed: return WeaponScaling(strength: .none, dexterity: .none, intelligence: .none, faith: .b)
        case .hollow: return WeaponScaling(strength: .none, dexterity: .b, intelligence: .none, faith: .none)
        }
    }
}

struct WeaponRequirements: Codable, Hashable {
    var strength: Int = 0
    var dexterity: Int = 0
    var intelligence: Int = 0
    var faith: Int = 0

    func requirement(for stat: StatType) -> Int {
        switch stat {
        case .strength: return strength
        case .dexterity: return dexterity
        case .intelligence: return intelligence
        case .faith: return faith
        default: return 0
        }
    }

    // Custom decoding: the bundled JSON omits zero-valued requirement keys for brevity,
    // so every key is optional and defaults to 0.
    enum CodingKeys: String, CodingKey { case strength, dexterity, intelligence, faith }
    init(strength: Int = 0, dexterity: Int = 0, intelligence: Int = 0, faith: Int = 0) {
        self.strength = strength
        self.dexterity = dexterity
        self.intelligence = intelligence
        self.faith = faith
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        strength = try c.decodeIfPresent(Int.self, forKey: .strength) ?? 0
        dexterity = try c.decodeIfPresent(Int.self, forKey: .dexterity) ?? 0
        intelligence = try c.decodeIfPresent(Int.self, forKey: .intelligence) ?? 0
        faith = try c.decodeIfPresent(Int.self, forKey: .faith) ?? 0
    }
}

struct WeaponScaling: Codable, Hashable {
    var strength: ScalingGrade = .none
    var dexterity: ScalingGrade = .none
    var intelligence: ScalingGrade = .none
    var faith: ScalingGrade = .none

    func grade(for stat: StatType) -> ScalingGrade {
        switch stat {
        case .strength: return strength
        case .dexterity: return dexterity
        case .intelligence: return intelligence
        case .faith: return faith
        default: return .none
        }
    }

    // Custom decoding: the bundled JSON omits "-"-grade scaling keys for brevity,
    // so every key is optional and defaults to .none.
    enum CodingKeys: String, CodingKey { case strength, dexterity, intelligence, faith }
    init(strength: ScalingGrade = .none, dexterity: ScalingGrade = .none, intelligence: ScalingGrade = .none, faith: ScalingGrade = .none) {
        self.strength = strength
        self.dexterity = dexterity
        self.intelligence = intelligence
        self.faith = faith
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        strength = try c.decodeIfPresent(ScalingGrade.self, forKey: .strength) ?? .none
        dexterity = try c.decodeIfPresent(ScalingGrade.self, forKey: .dexterity) ?? .none
        intelligence = try c.decodeIfPresent(ScalingGrade.self, forKey: .intelligence) ?? .none
        faith = try c.decodeIfPresent(ScalingGrade.self, forKey: .faith) ?? .none
    }
}

struct WeaponDamage: Codable, Hashable {
    var physical: Double = 0
    var magic: Double = 0
    var fire: Double = 0
    var lightning: Double = 0
    var dark: Double = 0

    func value(for type: DamageType) -> Double {
        switch type {
        case .physical: return physical
        case .magic: return magic
        case .fire: return fire
        case .lightning: return lightning
        case .dark: return dark
        }
    }

    // Custom decoding: the bundled JSON only lists non-zero damage types.
    enum CodingKeys: String, CodingKey { case physical, magic, fire, lightning, dark }
    init(physical: Double = 0, magic: Double = 0, fire: Double = 0, lightning: Double = 0, dark: Double = 0) {
        self.physical = physical
        self.magic = magic
        self.fire = fire
        self.lightning = lightning
        self.dark = dark
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        physical = try c.decodeIfPresent(Double.self, forKey: .physical) ?? 0
        magic = try c.decodeIfPresent(Double.self, forKey: .magic) ?? 0
        fire = try c.decodeIfPresent(Double.self, forKey: .fire) ?? 0
        lightning = try c.decodeIfPresent(Double.self, forKey: .lightning) ?? 0
        dark = try c.decodeIfPresent(Double.self, forKey: .dark) ?? 0
    }
}

struct Weapon: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: WeaponCategory
    let weight: Double
    let requirements: WeaponRequirements
    let scaling: WeaponScaling
    let baseDamage: WeaponDamage   // at +0, Normal (uninfused)
    let maxUpgrade: Int            // 10 for standard titanite path, 5 for special/raw-only weapons
    let infusable: Bool
    let poiseDamage: Double        // stagger-relevant base poise damage, flavor stat

    var canTwoHand: Bool { !category.isCastingTool && !category.isShield }
}
