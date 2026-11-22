import Foundation
import Observation

/// Loads the static, bundled game-data catalogs (classes, weapons, armor, rings) once at
/// launch and exposes them for lookup by ID. This data never changes at runtime.
@Observable
final class DataStore {
    static let shared = DataStore()

    let startingClasses: [StartingClass]
    let weapons: [Weapon]
    let armor: [ArmorPiece]
    let rings: [Ring]
    /// One entry per ring, with its +1/+2/+3 variants grouped, sorted by name.
    let ringFamilies: [RingFamily]
    let spells: [Spell]
    /// CalcCorrectGraph curves (stat 0...99 -> % of correction) by graph id.
    let curves: [Int: [Double]]

    private let classByID: [String: StartingClass]
    private let weaponByID: [String: Weapon]
    private let armorByID: [String: ArmorPiece]
    private let ringByID: [String: Ring]
    private let spellByID: [String: Spell]

    private init() {
        let decoder = JSONDecoder()

        func load<T: Decodable>(_ type: T.Type, from filename: String) -> T {
            guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
                fatalError("Missing bundled game data file: \(filename).json")
            }
            do {
                let data = try Data(contentsOf: url)
                return try decoder.decode(T.self, from: data)
            } catch {
                fatalError("Failed to decode \(filename).json: \(error)")
            }
        }

        let classes = load([StartingClass].self, from: "StartingClasses")
        let weaponList = load([Weapon].self, from: "Weapons")
        let armorList = load([ArmorPiece].self, from: "Armor")
        let ringList = load([Ring].self, from: "Rings")
        let spellList = load([Spell].self, from: "Spells")
        let curveTable = load([String: [Double]].self, from: "Curves")

        self.startingClasses = classes
        self.weapons = weaponList
        self.armor = armorList
        self.rings = ringList
        self.spells = spellList
        self.curves = Dictionary(uniqueKeysWithValues: curveTable.compactMap { k, v in Int(k).map { ($0, v) } })
        self.spellByID = Dictionary(uniqueKeysWithValues: spellList.map { ($0.id, $0) })
        self.ringFamilies = Dictionary(grouping: ringList, by: \.family)
            .map { RingFamily(name: $0.key, variants: $0.value.sorted { $0.level < $1.level }) }
            .sorted { $0.name < $1.name }

        self.classByID = Dictionary(uniqueKeysWithValues: classes.map { ($0.id, $0) })
        self.weaponByID = Dictionary(uniqueKeysWithValues: weaponList.map { ($0.id, $0) })
        self.armorByID = Dictionary(uniqueKeysWithValues: armorList.map { ($0.id, $0) })
        self.ringByID = Dictionary(uniqueKeysWithValues: ringList.map { ($0.id, $0) })
    }

    func startingClass(_ id: String?) -> StartingClass? {
        guard let id else { return nil }
        return classByID[id]
    }

    func weapon(_ id: String?) -> Weapon? {
        guard let id else { return nil }
        return weaponByID[id]
    }

    func armorPiece(_ id: String?) -> ArmorPiece? {
        guard let id else { return nil }
        return armorByID[id]
    }

    func ring(_ id: String?) -> Ring? {
        guard let id else { return nil }
        return ringByID[id]
    }

    func ringFamily(of ring: Ring?) -> RingFamily? {
        guard let ring else { return nil }
        return ringFamilies.first { $0.name == ring.family }
    }

    func spell(_ id: String?) -> Spell? {
        guard let id else { return nil }
        return spellByID[id]
    }

    /// Weapon categories in a stable order: melee by type, then catalysts, shields, ranged.
    var weaponCategories: [String] {
        var seen: [String] = []
        for kind in WeaponKind.allCases {
            for w in weapons where w.kind == kind && !seen.contains(w.category) { seen.append(w.category) }
        }
        return seen
    }

    func armor(in slot: ArmorSlot) -> [ArmorPiece] {
        armor.filter { $0.slot == slot }.sorted { $0.name < $1.name }
    }
}
