import XCTest
@testable import AshenBuild

final class FormulaTests: XCTestCase {

    private let data = DataStore.shared

    private func stats(_ values: [StatType: Int], default fill: Int = 10) -> StatBlock {
        var s = StatBlock(values: Dictionary(uniqueKeysWithValues: StatType.allCases.map { ($0, fill) }))
        for (k, v) in values { s[k] = v }
        return s
    }

    private func ar(_ id: String, _ infusion: InfusionType = .none, upgrade: Int, _ st: StatBlock, twoHanded: Bool = false) -> Formulas.AttackRatingResult {
        Formulas.attackRating(for: .init(weapon: data.weapon(id)!, upgradeLevel: upgrade, infusion: infusion, twoHanded: twoHanded), stats: st)
    }

    // MARK: - Soul Level

    func testDeprivedAllTensIsLevel1() {
        XCTAssertEqual(Formulas.soulLevel(for: stats([:])), 1)
    }

    func testOnePointAboveDeprivedIsLevel2() {
        XCTAssertEqual(Formulas.soulLevel(for: stats([.vigor: 11])), 2)
    }

    // MARK: - Interpolation, stat tables, roll

    func testInterpolate() {
        let table: [(x: Int, y: Double)] = [(10, 100), (20, 200)]
        XCTAssertEqual(Formulas.interpolate(table, at: 5), 100)
        XCTAssertEqual(Formulas.interpolate(table, at: 30), 200)
        XCTAssertEqual(Formulas.interpolate(table, at: 15), 150)
    }

    func testStatTablesMatchTheWiki() {
        XCTAssertEqual(Formulas.hp(vigor: 27), 1000)
        XCTAssertEqual(Formulas.hp(vigor: 11), 427)      // Mercenary
        XCTAssertEqual(Formulas.hp(vigor: 33), 1109)
        XCTAssertEqual(Formulas.fp(attunement: 12), 103)
        XCTAssertEqual(Formulas.stamina(endurance: 11), 95)
        XCTAssertEqual(Formulas.stamina(endurance: 32), 139)
        XCTAssertEqual(Formulas.stamina(endurance: 40), 160)
        XCTAssertEqual(Formulas.equipLoadCapacity(vitality: 30), 70)
        XCTAssertEqual(Formulas.fp(attunement: 30), 233)
        XCTAssertEqual(Formulas.attunementSlots(attunement: 14), 2)
    }

    func testRollTierBoundaries() {
        XCTAssertEqual(Formulas.rollTier(loadPercent: 0.10), .fast)
        XCTAssertEqual(Formulas.rollTier(loadPercent: 0.30), .medium)
        XCTAssertEqual(Formulas.rollTier(loadPercent: 0.70), .medium)
        XCTAssertEqual(Formulas.rollTier(loadPercent: 0.701), .fat)
        XCTAssertEqual(Formulas.rollTier(loadPercent: 1.0), .overburdened)
    }

    // MARK: - Game data

    func testCatalogSizes() {
        XCTAssertEqual(data.weapons.filter { $0.kind == .melee }.count, 178)
        XCTAssertGreaterThan(data.armor.count, 350)
        XCTAssertGreaterThan(data.spells.count, 100)
    }

    func testStartingClassSoulLevelsMatchTheGame() {
        let expected = ["knight": 9, "mercenary": 8, "warrior": 7, "herald": 9, "thief": 5,
                        "assassin": 10, "sorcerer": 6, "pyromancer": 8, "cleric": 7, "deprived": 1]
        for cls in data.startingClasses {
            XCTAssertEqual(Formulas.soulLevel(for: cls.statBlock), expected[cls.id], cls.name)
        }
    }

    func testStartingGearIsTheGamesOwn() {
        XCTAssertEqual(data.startingClass("mercenary")?.rightHand, ["sellsword_twinblades"])
        XCTAssertEqual(data.startingClass("sorcerer")?.leftHand, ["leather_shield", "sorcerer_s_staff"])
        for cls in data.startingClasses {
            for id in cls.rightHand + cls.leftHand { XCTAssertNotNil(data.weapon(id), "\(cls.name): \(id)") }
            for id in cls.startingArmorIDs { XCTAssertNotNil(data.armorPiece(id), "\(cls.name): \(id)") }
            for id in cls.spellIDs { XCTAssertNotNil(data.spell(id), "\(cls.name): \(id)") }
        }
    }

    func testRingVariantsAreGroupedIntoFamilies() {
        let havel = data.ringFamilies.first { $0.name == "Havel's Ring" }
        XCTAssertEqual(havel?.variants.map(\.level), [0, 1, 2, 3])
        XCTAssertEqual(havel?.variants.last?.equipLoadMultiplier ?? 0, 1.19, accuracy: 0.0001)
    }

    // MARK: - Attack rating (regulation 1.35 params)

    func testLongswordBaseValues() {
        let w = data.weapon("longsword")!
        XCTAssertEqual(w.variant(.none)?.baseDamage(at: 0).first, 110)
        XCTAssertEqual(w.variant(.none)?.baseDamage(at: 10).first, 220)
        XCTAssertEqual(w.requirements(.none), WeaponRequirements(strength: 10, dexterity: 10))
        XCTAssertEqual(w.infusions.count, 16)
    }

    func testLongswordAttackRating() {
        XCTAssertEqual(ar("longsword", upgrade: 10, stats([.strength: 40, .dexterity: 40])).total.whole, 416)
        XCTAssertEqual(ar("longsword", .sharp, upgrade: 10, stats([.strength: 18, .dexterity: 40, .luck: 7])).total.whole, 406)
    }

    func testTwoHandingRaisesStrengthWeapons() {
        let st = stats([.strength: 20, .dexterity: 13])
        XCTAssertGreaterThan(ar("claymore", upgrade: 10, st, twoHanded: true).total, ar("claymore", upgrade: 10, st).total)
    }

    func testMissingRequirementsAreReported() {
        let result = ar("greatsword", upgrade: 0, stats([:]))
        XCTAssertFalse(result.meetsRequirements)
        XCTAssertTrue(result.missing.contains(.strength))
    }

    func testUniqueWeaponsStopAtPlusFive() {
        XCTAssertEqual(data.weapon("moonlight_greatsword")?.maxUpgrade, 5)
    }

    // MARK: - Catalysts (checked in game by the data's source)

    func testSpellBuffMatchesInGameValues() {
        let flame = data.weapon("pyromancy_flame")!
        XCTAssertEqual(Formulas.spellBuff(of: flame, upgrade: 10, stats: stats([.intelligence: 10, .faith: 10])), 116)
        XCTAssertEqual(Formulas.spellBuff(of: flame, upgrade: 10, stats: stats([.intelligence: 40, .faith: 40])), 207)
        XCTAssertEqual(Formulas.spellBuff(of: flame, upgrade: 10, stats: stats([.intelligence: 60, .faith: 60])), 221)
        let saints = data.weapon("saint_s_talisman")!
        XCTAssertEqual(Formulas.spellBuff(of: saints, upgrade: 10, stats: stats([.faith: 45])), 187)
        XCTAssertEqual(Formulas.spellBuff(of: saints, upgrade: 10, stats: stats([.faith: 60])), 242)
    }

    // MARK: - Buffs

    private func spec(right: [StoredWeapon], left: [StoredWeapon] = [], stats st: StatBlock, buff: String? = nil, cls: String = "knight") -> BuildSpec {
        var l = Loadout()
        for (i, w) in right.enumerated() { l.right[i] = w }
        for (i, w) in left.enumerated() { l.left[i] = w }
        l.buffID = buff
        return BuildSpec(classID: cls, stats: st, loadout: l)
    }

    func testLightningBladeAddsToAPlainWeapon() {
        let st = stats([.strength: 20, .dexterity: 20, .faith: 40])
        let withBuff = BuildCalculator.report(for: spec(right: [StoredWeapon(weaponID: "longsword", upgrade: 10)],
                                                        left: [StoredWeapon(weaponID: "saint_s_talisman", upgrade: 10)],
                                                        stats: st, buff: "lightning_blade"), data: data)
        let without = BuildCalculator.report(for: spec(right: [StoredWeapon(weaponID: "longsword", upgrade: 10)],
                                                       left: [StoredWeapon(weaponID: "saint_s_talisman", upgrade: 10)],
                                                       stats: st), data: data)
        XCTAssertEqual(withBuff.buffStatus, .applied)
        let sb = Double(withBuff.spellBuffs[.miracle]!.value)
        XCTAssertEqual(withBuff.mainHand!.total - without.mainHand!.total, 0.95 * sb, accuracy: 0.01)
    }

    func testElementalInfusionsCannotBeBuffed() {
        let st = stats([.strength: 20, .dexterity: 20, .faith: 40])
        let report = BuildCalculator.report(for: spec(right: [StoredWeapon(weaponID: "longsword", upgrade: 10, infusion: "Fire")],
                                                      left: [StoredWeapon(weaponID: "saint_s_talisman", upgrade: 10)],
                                                      stats: st, buff: "lightning_blade"), data: data)
        XCTAssertEqual(report.buffStatus, .notBuffable)
    }

    func testSwitchingTheHeldSlotChangesTheReport() {
        var s = spec(right: [StoredWeapon(weaponID: "longsword", upgrade: 5), StoredWeapon(weaponID: "claymore", upgrade: 5)],
                     stats: stats([.strength: 20, .dexterity: 20]))
        XCTAssertEqual(BuildCalculator.report(for: s, data: data).mainHand?.weapon.id, "longsword")
        s.loadout.activeRight = 1
        XCTAssertEqual(BuildCalculator.report(for: s, data: data).mainHand?.weapon.id, "claymore")
    }

    func testAllSlotsCountTowardLoad() {
        let s = spec(right: [StoredWeapon(weaponID: "longsword"), StoredWeapon(weaponID: "claymore")],
                     left: [StoredWeapon(weaponID: "knight_shield")], stats: stats([:]))
        XCTAssertEqual(BuildCalculator.report(for: s, data: data).load, 3 + 9 + 4.5, accuracy: 0.001)
    }

    // MARK: - Defenses

    func testAbsorptionsMultiply() {
        XCTAssertEqual(Formulas.combinedAbsorption([10, 10]), 19, accuracy: 0.0001)
    }

    // MARK: - Rings and optimizer

    private func knightSpec() -> BuildSpec {
        var st = data.startingClass("knight")!.statBlock
        st[.vigor] = 27
        st[.intelligence] = 20   // wasted on a Longsword
        st[.luck] = 15           // wasted too
        return spec(right: [StoredWeapon(weaponID: "longsword", upgrade: 10)], left: [StoredWeapon(weaponID: "knight_shield")], stats: st)
    }

    func testRedTearstoneAddsTwentyPercentWhenConditionMet() {
        var s = knightSpec()
        s.ringIDs = ["red_tearstone_ring"]
        let main = BuildCalculator.report(for: s, data: data).mainHand!
        XCTAssertEqual(main.conditional.first?.total ?? 0, main.total * 1.2, accuracy: 0.001)
    }

    func testKnightsRingRaisesEffectiveStrengthButNotSoulLevel() {
        var s = knightSpec()
        let before = BuildCalculator.report(for: s, data: data)
        s.ringIDs = ["knights_ring"]
        let after = BuildCalculator.report(for: s, data: data)
        XCTAssertEqual(after.effectiveStats[.strength], before.effectiveStats[.strength] + 5)
        XCTAssertEqual(after.soulLevel, before.soulLevel)
    }

    func testRespecKeepsSoulLevelAndNeverLowersAttack() {
        let s = knightSpec()
        let current = BuildCalculator.report(for: s, data: data)
        let result = Optimizer.respec(s, goal: .keepingSurvivability(of: s), data: data)
        XCTAssertTrue(result.feasible)
        XCTAssertEqual(result.stats.total, s.stats.total)
        XCTAssertGreaterThan(result.report.mainHand!.total, current.mainHand!.total)
        XCTAssertEqual(result.stats[.vigor], 27)
        XCTAssertTrue(result.report.mainHand!.result.meetsRequirements)
    }

    func testAnalysisFlagsWastedPoints() {
        let analysis = Optimizer.analyze(knightSpec(), data: data)
        XCTAssertLessThan(analysis.score ?? 1, 0.98)
        XCTAssertTrue(analysis.issues.contains { $0.title.contains("Intelligence") })
        XCTAssertTrue(analysis.issues.contains { $0.title.contains("Luck") })
    }

    func testBestArmorStaysWithinTheRoll() {
        let sets = Optimizer.bestArmor(knightSpec(), goal: .poise, roll: .medium, minPoise: 0, data: data)
        XCTAssertFalse(sets.isEmpty)
        for set in sets { XCTAssertNotEqual(Formulas.rollTier(loadPercent: set.loadFraction), .fat) }
        XCTAssertGreaterThanOrEqual(sets[0].value, sets.last!.value)
    }

    func testWeaponOptionsAreSortedAndFeasible() {
        let s = knightSpec()
        let options = Optimizer.weaponOptions(s, goal: .keepingSurvivability(of: s), data: data)
        XCTAssertFalse(options.isEmpty)
        XCTAssertEqual(options.map(\.attackRating), options.map(\.attackRating).sorted(by: >))
    }
}
