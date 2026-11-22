import XCTest
@testable import AshenBuild

final class FormulaTests: XCTestCase {

    // MARK: - Soul Level

    func testDeprivedAllTensIsLevel1() {
        let stats = StatBlock(values: Dictionary(uniqueKeysWithValues: StatType.allCases.map { ($0, 10) }))
        XCTAssertEqual(Formulas.soulLevel(for: stats), 1)
    }

    func testOnePointAboveDeprivedIsLevel2() {
        var stats = StatBlock(values: Dictionary(uniqueKeysWithValues: StatType.allCases.map { ($0, 10) }))
        stats[.vigor] = 11
        XCTAssertEqual(Formulas.soulLevel(for: stats), 2)
    }

    // MARK: - Interpolation helper

    func testInterpolateClampsBelowRange() {
        let table: [(x: Int, y: Double)] = [(10, 100), (20, 200)]
        XCTAssertEqual(Formulas.interpolate(table, at: 5), 100)
    }

    func testInterpolateClampsAboveRange() {
        let table: [(x: Int, y: Double)] = [(10, 100), (20, 200)]
        XCTAssertEqual(Formulas.interpolate(table, at: 30), 200)
    }

    func testInterpolateMidpointIsLinear() {
        let table: [(x: Int, y: Double)] = [(10, 100), (20, 200)]
        XCTAssertEqual(Formulas.interpolate(table, at: 15), 150)
    }

    // MARK: - Vigor -> HP is monotonically increasing

    func testHPIncreasesWithVigor() {
        let low = Formulas.hp(vigor: 10)
        let mid = Formulas.hp(vigor: 30)
        let high = Formulas.hp(vigor: 60)
        XCTAssertLessThan(low, mid)
        XCTAssertLessThan(mid, high)
    }

    // MARK: - Attunement slots are monotonic non-decreasing and start at 0

    func testAttunementSlotsStartAtZero() {
        XCTAssertEqual(Formulas.attunementSlots(attunement: 5), 0)
    }

    func testAttunementSlotsIncreaseAtKnownBreakpoint() {
        XCTAssertEqual(Formulas.attunementSlots(attunement: 10), 1)
        XCTAssertEqual(Formulas.attunementSlots(attunement: 14), 2)
    }

    // MARK: - Equip load / roll tiers

    func testRollTierBoundaries() {
        XCTAssertEqual(Formulas.rollTier(loadPercent: 0.10), .fast)
        XCTAssertEqual(Formulas.rollTier(loadPercent: 0.30), .medium)
        XCTAssertEqual(Formulas.rollTier(loadPercent: 0.69), .medium)
        XCTAssertEqual(Formulas.rollTier(loadPercent: 0.70), .medium)
        XCTAssertEqual(Formulas.rollTier(loadPercent: 0.701), .fat)
        XCTAssertEqual(Formulas.rollTier(loadPercent: 0.99), .fat)
        XCTAssertEqual(Formulas.rollTier(loadPercent: 1.0), .overburdened)
        XCTAssertEqual(Formulas.rollTier(loadPercent: 1.5), .overburdened)
    }

    // MARK: - Attack Rating sanity checks

    func testAttackRatingIncreasesWithUpgradeLevel() {
        let weapon = Weapon(
            id: "test_sword", name: "Test Sword", category: .straightSword, weight: 3,
            requirements: WeaponRequirements(), scaling: WeaponScaling(strength: .d, dexterity: .d),
            baseDamage: WeaponDamage(physical: 100), maxUpgrade: 10, infusable: true, poiseDamage: 20
        )
        let stats = StatBlock(values: Dictionary(uniqueKeysWithValues: StatType.allCases.map { ($0, 20) }))
        let plusZero = Formulas.attackRating(for: .init(weapon: weapon, upgradeLevel: 0, infusion: .none, twoHanded: false), stats: stats)
        let plusTen = Formulas.attackRating(for: .init(weapon: weapon, upgradeLevel: 10, infusion: .none, twoHanded: false), stats: stats)
        XCTAssertGreaterThan(plusTen.total, plusZero.total)
    }

    func testAttackRatingIncreasesWithScalingStat() {
        let weapon = Weapon(
            id: "test_sword2", name: "Test Sword 2", category: .straightSword, weight: 3,
            requirements: WeaponRequirements(strength: 10, dexterity: 10), scaling: WeaponScaling(strength: .d, dexterity: .d),
            baseDamage: WeaponDamage(physical: 100), maxUpgrade: 10, infusable: true, poiseDamage: 20
        )
        var lowStats = StatBlock(values: Dictionary(uniqueKeysWithValues: StatType.allCases.map { ($0, 10) }))
        var highStats = lowStats
        highStats[.strength] = 40
        highStats[.dexterity] = 40
        lowStats[.strength] = 10
        lowStats[.dexterity] = 10

        let low = Formulas.attackRating(for: .init(weapon: weapon, upgradeLevel: 0, infusion: .none, twoHanded: false), stats: lowStats)
        let high = Formulas.attackRating(for: .init(weapon: weapon, upgradeLevel: 0, infusion: .none, twoHanded: false), stats: highStats)
        XCTAssertGreaterThan(high.total, low.total)
    }

    func testUnderRequirementAppliesPenalty() {
        let weapon = Weapon(
            id: "heavy_sword", name: "Heavy Sword", category: .greatsword, weight: 8,
            requirements: WeaponRequirements(strength: 40), scaling: WeaponScaling(strength: .d),
            baseDamage: WeaponDamage(physical: 150), maxUpgrade: 10, infusable: true, poiseDamage: 40
        )
        let underleveled = StatBlock(values: Dictionary(uniqueKeysWithValues: StatType.allCases.map { ($0, 10) }))
        let result = Formulas.attackRating(for: .init(weapon: weapon, upgradeLevel: 0, infusion: .none, twoHanded: false), stats: underleveled)
        XCTAssertFalse(result.meetsRequirements)
        XCTAssertLessThan(result.requirementRatio, 1.0)
    }

    func testTwoHandingBoostsEffectiveStrengthAndDamage() {
        let weapon = Weapon(
            id: "str_sword", name: "STR Sword", category: .greatsword, weight: 8,
            requirements: WeaponRequirements(strength: 20), scaling: WeaponScaling(strength: .c),
            baseDamage: WeaponDamage(physical: 150), maxUpgrade: 10, infusable: true, poiseDamage: 40
        )
        var stats = StatBlock(values: Dictionary(uniqueKeysWithValues: StatType.allCases.map { ($0, 10) }))
        stats[.strength] = 20
        let oneHanded = Formulas.attackRating(for: .init(weapon: weapon, upgradeLevel: 0, infusion: .none, twoHanded: false), stats: stats)
        let twoHanded = Formulas.attackRating(for: .init(weapon: weapon, upgradeLevel: 0, infusion: .none, twoHanded: true), stats: stats)
        XCTAssertGreaterThan(twoHanded.total, oneHanded.total)
    }

    // MARK: - Defenses are pure sums

    func testTotalPhysicalDefenseSumsPieces() {
        let a = ArmorPiece(id: "a", name: "A", slot: .head, weight: 1, poise: 1,
                            physicalDefense: PhysicalDefense(standard: 10, strike: 8, slash: 9, thrust: 9),
                            elementalDefense: ElementalDefense(), resistances: Resistances())
        let b = ArmorPiece(id: "b", name: "B", slot: .chest, weight: 2, poise: 2,
                            physicalDefense: PhysicalDefense(standard: 20, strike: 16, slash: 18, thrust: 18),
                            elementalDefense: ElementalDefense(), resistances: Resistances())
        let total = Formulas.totalPhysicalDefense(pieces: [a, b])
        XCTAssertEqual(total.standard, 30)
        XCTAssertEqual(total.strike, 24)
    }

    // MARK: - Game data

    func testStartingClassSoulLevelsMatchTheGame() {
        let expected = ["knight": 9, "mercenary": 8, "warrior": 7, "herald": 9, "thief": 5,
                        "assassin": 10, "sorcerer": 6, "pyromancer": 8, "cleric": 7, "deprived": 1]
        for cls in DataStore.shared.startingClasses {
            XCTAssertEqual(Formulas.soulLevel(for: cls.statBlock), expected[cls.id], cls.name)
        }
    }

    func testRingVariantsAreGroupedIntoFamilies() {
        let havel = DataStore.shared.ringFamilies.first { $0.name == "Havel's Ring" }
        XCTAssertEqual(havel?.variants.map(\.level), [0, 1, 2, 3])
        XCTAssertEqual(havel?.variants.last?.equipLoadMultiplier ?? 0, 1.19, accuracy: 0.0001)
    }

    // MARK: - Calculator and optimizer

    private func knightSpec() -> BuildSpec {
        let data = DataStore.shared
        let knight = data.startingClass("knight")!
        var stats = knight.statBlock
        stats[.vigor] = 27
        stats[.intelligence] = 20   // wasted on a Longsword
        stats[.luck] = 15           // wasted too
        return BuildSpec(classID: "knight", stats: stats,
                         mainHand: WeaponSetup(weaponID: "longsword", upgrade: 10),
                         offHand: WeaponSetup(weaponID: "heater_shield"))
    }

    func testRedTearstoneAddsTwentyPercentWhenConditionMet() {
        var spec = knightSpec()
        spec.ringIDs = ["red_tearstone_ring"]
        let report = BuildCalculator.report(for: spec, data: .shared)
        let main = try! XCTUnwrap(report.mainHand)
        XCTAssertEqual(main.conditional.first?.total ?? 0, main.total * 1.2, accuracy: 0.001)
    }

    func testKnightsRingRaisesEffectiveStrengthButNotSoulLevel() {
        var spec = knightSpec()
        let before = BuildCalculator.report(for: spec, data: .shared)
        spec.ringIDs = ["knights_ring"]
        let after = BuildCalculator.report(for: spec, data: .shared)
        XCTAssertEqual(after.effectiveStats[.strength], before.effectiveStats[.strength] + 5)
        XCTAssertEqual(after.soulLevel, before.soulLevel)
    }

    func testRespecKeepsSoulLevelAndNeverLowersAttack() {
        let spec = knightSpec()
        let current = BuildCalculator.report(for: spec, data: .shared)
        let result = Optimizer.respec(spec, goal: .keepingSurvivability(of: spec), data: .shared)
        XCTAssertTrue(result.feasible)
        XCTAssertEqual(result.stats.total, spec.stats.total)
        XCTAssertGreaterThan(result.report.mainHand!.total, current.mainHand!.total)
        XCTAssertEqual(result.stats[.vigor], 27)
        XCTAssertEqual(result.stats[.luck], DataStore.shared.startingClass("knight")!.statBlock[.luck])
        XCTAssertTrue(result.report.mainHand!.result.meetsRequirements)
    }

    func testAnalysisFlagsWastedPoints() {
        let analysis = Optimizer.analyze(knightSpec(), data: .shared)
        XCTAssertLessThan(analysis.score ?? 1, 0.98)
        XCTAssertTrue(analysis.issues.contains { $0.title.contains("Intelligence") })
        XCTAssertTrue(analysis.issues.contains { $0.title.contains("Luck") })
    }

    func testBestArmorStaysWithinTheRoll() {
        let spec = knightSpec()
        let sets = Optimizer.bestArmor(spec, goal: .poise, roll: .medium, minPoise: 0, data: .shared)
        XCTAssertFalse(sets.isEmpty)
        for set in sets {
            XCTAssertNotEqual(Formulas.rollTier(loadPercent: set.loadFraction), .fat)
        }
        XCTAssertGreaterThanOrEqual(sets[0].value, sets.last!.value)
    }

    func testWeaponOptionsAreSortedAndFeasible() {
        let options = Optimizer.weaponOptions(knightSpec(), goal: .keepingSurvivability(of: knightSpec()), data: .shared)
        XCTAssertFalse(options.isEmpty)
        XCTAssertEqual(options.map(\.attackRating), options.map(\.attackRating).sorted(by: >))
    }
}
