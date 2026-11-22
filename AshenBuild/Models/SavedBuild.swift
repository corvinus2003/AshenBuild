import Foundation
import SwiftData

/// A user's saved character build. Only the user's *choices* are persisted here —
/// the weapon/armor/ring/class catalogs themselves are static bundled JSON (see DataStore),
/// referenced by stable string IDs so catalog corrections never require a data migration.
@Model
final class SavedBuild {
    var id: UUID = UUID()
    var name: String = "New Build"
    var classID: String = "deprived"

    // 9 primary stats, stored as scalars for straightforward SwiftData storage.
    var vigor: Int = 10
    var attunement: Int = 10
    var endurance: Int = 10
    var vitality: Int = 10
    var strength: Int = 10
    var dexterity: Int = 10
    var intelligence: Int = 10
    var faith: Int = 10
    var luck: Int = 10

    // Weapons, spells and buff (three slots per hand, as in the game). Stored as JSON so the
    // shape can grow without SwiftData migrations; see `loadout`.
    var loadoutData: Data?

    // Legacy single-slot fields from version 0.1 builds, read once into `loadout`.
    var mainHandWeaponID: String?
    var mainHandUpgradeLevel: Int = 0
    var mainHandInfusion: String = InfusionType.none.rawValue
    var twoHanded: Bool = false

    // Off-hand weapon
    var offHandWeaponID: String?
    var offHandUpgradeLevel: Int = 0
    var offHandInfusion: String = InfusionType.none.rawValue

    // Armor
    var headArmorID: String?
    var chestArmorID: String?
    var handsArmorID: String?
    var legsArmorID: String?

    // Rings
    var ring1ID: String?
    var ring2ID: String?
    var ring3ID: String?
    var ring4ID: String?

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(name: String = "New Build", classID: String = "deprived", statBlock: StatBlock = StatBlock()) {
        self.name = name
        self.classID = classID
        self.vigor = statBlock[.vigor]
        self.attunement = statBlock[.attunement]
        self.endurance = statBlock[.endurance]
        self.vitality = statBlock[.vitality]
        self.strength = statBlock[.strength]
        self.dexterity = statBlock[.dexterity]
        self.intelligence = statBlock[.intelligence]
        self.faith = statBlock[.faith]
        self.luck = statBlock[.luck]
    }

    var statBlock: StatBlock {
        get {
            StatBlock(values: [
                .vigor: vigor, .attunement: attunement, .endurance: endurance, .vitality: vitality,
                .strength: strength, .dexterity: dexterity, .intelligence: intelligence,
                .faith: faith, .luck: luck
            ])
        }
        set {
            vigor = newValue[.vigor]
            attunement = newValue[.attunement]
            endurance = newValue[.endurance]
            vitality = newValue[.vitality]
            strength = newValue[.strength]
            dexterity = newValue[.dexterity]
            intelligence = newValue[.intelligence]
            faith = newValue[.faith]
            luck = newValue[.luck]
            updatedAt = Date()
        }
    }

    var ringIDs: [String] {
        [ring1ID, ring2ID, ring3ID, ring4ID].compactMap { $0 }
    }
}

extension SavedBuild {
    /// A new, unsaved build with the same choices, named "<name> Copy".
    func duplicate() -> SavedBuild {
        let copy = SavedBuild(name: "\(name) Copy", classID: classID, statBlock: statBlock)
        copy.loadoutData = loadoutData
        copy.mainHandWeaponID = mainHandWeaponID
        copy.mainHandUpgradeLevel = mainHandUpgradeLevel
        copy.mainHandInfusion = mainHandInfusion
        copy.twoHanded = twoHanded
        copy.offHandWeaponID = offHandWeaponID
        copy.offHandUpgradeLevel = offHandUpgradeLevel
        copy.offHandInfusion = offHandInfusion
        copy.headArmorID = headArmorID
        copy.chestArmorID = chestArmorID
        copy.handsArmorID = handsArmorID
        copy.legsArmorID = legsArmorID
        copy.ring1ID = ring1ID
        copy.ring2ID = ring2ID
        copy.ring3ID = ring3ID
        copy.ring4ID = ring4ID
        return copy
    }
}

/// One weapon slot.
struct StoredWeapon: Codable, Hashable {
    var weaponID: String?
    var upgrade: Int = 0
    var infusion: String = InfusionType.none.rawValue

    var setup: WeaponSetup {
        WeaponSetup(weaponID: weaponID, upgrade: upgrade, infusion: InfusionType(rawValue: infusion) ?? .none)
    }
}

/// Everything the character holds and casts.
struct Loadout: Codable, Hashable {
    var right: [StoredWeapon] = Array(repeating: StoredWeapon(), count: 3)
    var left: [StoredWeapon] = Array(repeating: StoredWeapon(), count: 3)
    var activeRight = 0
    var activeLeft = 0
    var twoHanded = false
    var spellIDs: [String] = []
    /// Weapon buff applied to the right-hand weapon (a spell or resin id), if any.
    var buffID: String?
}

extension SavedBuild {
    var loadout: Loadout {
        get {
            if let data = loadoutData, let value = try? JSONDecoder().decode(Loadout.self, from: data) { return value }
            var value = Loadout()
            value.right[0] = StoredWeapon(weaponID: mainHandWeaponID, upgrade: mainHandUpgradeLevel, infusion: mainHandInfusion)
            value.left[0] = StoredWeapon(weaponID: offHandWeaponID, upgrade: offHandUpgradeLevel, infusion: offHandInfusion)
            value.twoHanded = twoHanded
            return value
        }
        set {
            loadoutData = try? JSONEncoder().encode(newValue)
            updatedAt = .now
        }
    }
}
