import SwiftUI

enum Hand: String, Identifiable {
    case right = "Right Hand", left = "Left Hand"
    var id: Self { self }
}

/// Three slots per hand, as in the game. Empty slots are fine. The active slot of each
/// hand is the one the Summary and Optimize screens use; switch it in Summary or here.
struct WeaponsTab: View {
    @Bindable var build: SavedBuild
    @Environment(DataStore.self) private var dataStore

    var body: some View {
        let spec = build.spec
        let report = BuildCalculator.report(for: spec, data: dataStore)
        Form {
            handSection(.right, spec: spec, report: report)
            handSection(.left, spec: spec, report: report)

            Section {
                LabeledContent("Weapons") {
                    Text(spec.allWeapons.reduce(0.0) { $0 + (dataStore.weapon($1.weaponID)?.weight ?? 0) }.oneDecimal).monospacedDigit()
                }
                LabeledContent("Total load") {
                    Text("\(report.load.oneDecimal) of \(report.capacity.oneDecimal) · \(report.rollTier.rawValue)").monospacedDigit()
                }
            } header: {
                Text("Weight")
            } footer: {
                Text("All six slots count toward equip load, as in the game.")
            }
        }
    }

    @ViewBuilder
    private func handSection(_ hand: Hand, spec: BuildSpec, report: BuildReport) -> some View {
        let slots = hand == .right ? spec.loadout.right : spec.loadout.left
        let active = hand == .right ? spec.loadout.activeRight : spec.loadout.activeLeft
        Section {
            ForEach(0..<3, id: \.self) { index in
                NavigationLink {
                    WeaponSlotView(build: build, hand: hand, index: index)
                } label: {
                    SlotRow(index: index, stored: slots[index], active: index == active, stats: report.effectiveStats,
                            twoHanded: hand == .right && spec.loadout.twoHanded && index == active)
                }
                .swipeActions(edge: .leading) {
                    if index != active && slots[index].weaponID != nil {
                        Button("Use", systemImage: "hand.point.up.left.fill") { setActive(hand, index) }
                            .tint(.accentColor)
                    }
                }
                .contextMenu {
                    if slots[index].weaponID != nil {
                        Button("Hold This Weapon", systemImage: "hand.point.up.left.fill") { setActive(hand, index) }
                        Button("Empty Slot", systemImage: "xmark.circle", role: .destructive) { clear(hand, index) }
                    }
                }
            }
            if hand == .right, let weapon = dataStore.weapon(spec.mainHand.weaponID), weapon.canTwoHand {
                Toggle("Two-Handed", isOn: Binding(
                    get: { build.loadout.twoHanded },
                    set: { var l = build.loadout; l.twoHanded = $0; build.loadout = l }
                ))
            }
        } header: {
            Text(hand.rawValue)
        } footer: {
            if hand == .right {
                Text("Swipe right on a slot, or use Summary, to change which weapon you hold. Two-handing counts Strength x1.5.")
            }
        }
    }

    private func setActive(_ hand: Hand, _ index: Int) {
        var l = build.loadout
        if hand == .right { l.activeRight = index } else { l.activeLeft = index }
        build.loadout = l
    }

    private func clear(_ hand: Hand, _ index: Int) {
        var l = build.loadout
        if hand == .right { l.right[index] = StoredWeapon() } else { l.left[index] = StoredWeapon() }
        build.loadout = l
    }
}

private struct SlotRow: View {
    let index: Int
    let stored: StoredWeapon
    let active: Bool
    let stats: StatBlock
    let twoHanded: Bool
    @Environment(DataStore.self) private var dataStore

    var body: some View {
        if let weapon = dataStore.weapon(stored.weaponID) {
            HStack(spacing: 12) {
                WeaponBadge(weapon: weapon, compact: true)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(weapon.name).lineLimit(1)
                        if active {
                            Text("Held")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 1)
                                .background(Color.accentColor, in: .capsule)
                        }
                    }
                    Text(detail(weapon))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                if let value = headline(weapon) {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(value.0)").font(.headline.monospacedDigit())
                        Text(value.1).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityElement(children: .combine)
        } else {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle")
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 36)
                Text("Slot \(index + 1) · Empty")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func detail(_ weapon: Weapon) -> String {
        var parts = ["+\(stored.upgrade)"]
        if weapon.infusable { parts.append(stored.infusion) }
        parts.append(weapon.category)
        return parts.joined(separator: " · ")
    }

    private func headline(_ weapon: Weapon) -> (Int, String)? {
        if weapon.kind == .catalyst {
            return (Formulas.spellBuff(of: weapon, upgrade: stored.upgrade, stats: stats), "SB")
        }
        let result = Formulas.attackRating(
            for: .init(weapon: weapon, upgradeLevel: stored.upgrade, infusion: InfusionType(rawValue: stored.infusion) ?? .none,
                       twoHanded: twoHanded),
            stats: stats)
        return (result.total.whole, weapon.hasAttackTables ? "AR" : "ATK")
    }
}

/// One slot: choose the weapon, type its upgrade level (0 to its maximum), pick an infusion,
/// and see what it does with this character's stats.
struct WeaponSlotView: View {
    @Bindable var build: SavedBuild
    let hand: Hand
    let index: Int

    @Environment(DataStore.self) private var dataStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var upgradeFocused: Bool

    private var stored: StoredWeapon {
        hand == .right ? build.loadout.right[index] : build.loadout.left[index]
    }

    private func update(_ change: (inout StoredWeapon) -> Void) {
        var l = build.loadout
        if hand == .right { change(&l.right[index]) } else { change(&l.left[index]) }
        build.loadout = l
    }

    private var isActive: Bool {
        hand == .right ? build.loadout.activeRight == index : build.loadout.activeLeft == index
    }

    var body: some View {
        let spec = build.spec
        let report = BuildCalculator.report(for: spec, data: dataStore)
        let weapon = dataStore.weapon(stored.weaponID)
        let infusion = InfusionType(rawValue: stored.infusion) ?? .none
        Form {
            Section {
                NavigationLink {
                    WeaponGridPicker(title: "\(hand.rawValue) · Slot \(index + 1)", spec: spec,
                                     setup: WeaponSetup(weaponID: stored.weaponID, upgrade: stored.upgrade, infusion: infusion)) { newID, upgrade in
                        guard newID != stored.weaponID else { return }
                        update {
                            $0.weaponID = newID
                            $0.upgrade = upgrade   // the level the card's attack rating was shown at
                            $0.infusion = InfusionType.none.rawValue
                        }
                    }
                } label: {
                    if let weapon {
                        HStack(spacing: 12) {
                            WeaponBadge(weapon: weapon, compact: true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(weapon.name)
                                Text("\(weapon.category) · \(weapon.weight.oneDecimal) wt")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Label("Choose a Weapon", systemImage: "plus.circle")
                    }
                }

                if let weapon {
                    NumberFieldStepper(title: "Upgrade", prefix: "+", value: Binding(
                        get: { stored.upgrade },
                        set: { v in update { $0.upgrade = max(0, min(weapon.maxUpgrade, v)) } }
                    ), range: 0...weapon.maxUpgrade, focus: $upgradeFocused)

                    if weapon.infusable {
                        Picker("Infusion", selection: Binding(
                            get: { infusion },
                            set: { v in update { $0.infusion = v.rawValue } }
                        )) {
                            ForEach(weapon.infusions) { Text($0.displayName).tag($0) }
                        }
                    }

                    if !isActive {
                        Button("Hold This Weapon", systemImage: "hand.point.up.left.fill") {
                            var l = build.loadout
                            if hand == .right { l.activeRight = index } else { l.activeLeft = index }
                            build.loadout = l
                        }
                    }
                }
            } header: {
                Text("\(hand.rawValue) · Slot \(index + 1)")
            } footer: {
                if let weapon, weapon.maxUpgrade == 5 {
                    Text("Unique weapons go to +5 (twinkling titanite).")
                }
            }

            if let weapon {
                details(weapon: weapon, infusion: infusion, report: report, spec: spec)

                Section {
                    Button("Empty This Slot", systemImage: "xmark.circle", role: .destructive) {
                        update { $0 = StoredWeapon() }
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(weapon?.name ?? "Slot \(index + 1)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { upgradeFocused = false }.fontWeight(.semibold)
            }
        }
    }

    @ViewBuilder
    private func details(weapon: Weapon, infusion: InfusionType, report: BuildReport, spec: BuildSpec) -> some View {
        let stats = report.effectiveStats
        let twoHanded = hand == .right && isActive && spec.loadout.twoHanded
        let result = Formulas.attackRating(
            for: .init(weapon: weapon, upgradeLevel: stored.upgrade, infusion: infusion, twoHanded: twoHanded), stats: stats)
        let mainReport = hand == .right && isActive ? report.mainHand : nil

        Section {
            if weapon.kind == .catalyst || weapon.catalyst != nil {
                LabeledContent("Spell Buff") {
                    Text("\(Formulas.spellBuff(of: weapon, upgrade: stored.upgrade, stats: stats))")
                        .font(.title2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.tint)
                }
                if let cat = weapon.catalyst {
                    LabeledContent("Casts") {
                        Text([SpellSchool.sorcery, .miracle, .pyromancy].filter { cat.casts($0) }.map(\.displayName).joined(separator: ", "))
                    }
                }
            }
            if weapon.kind != .catalyst {
                HStack(alignment: .firstTextBaseline) {
                    Text(weapon.hasAttackTables ? "Attack Rating" : "Base Attack")
                    Spacer()
                    Text("\((mainReport?.total ?? result.total).whole)")
                        .font(.title2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.tint)
                }
                ForEach(DamageType.allCases.filter { ((mainReport?.result.breakdown ?? result.breakdown)[$0] ?? 0) > 0.5 }) { type in
                    LabeledContent(type.displayName) {
                        Text("\(((mainReport?.result.breakdown ?? result.breakdown)[type] ?? 0).whole)").monospacedDigit()
                    }
                }
                if let buff = mainReport?.buffApplied, let gain = mainReport?.buffGain {
                    LabeledContent("Includes \(buff.name)") { Text("+\(gain.whole)").monospacedDigit().foregroundStyle(.green) }
                }
            }
            if let variant = weapon.variant(infusion) {
                LabeledContent("Scaling") {
                    HStack(spacing: 8) {
                        ForEach([StatType.strength, .dexterity, .intelligence, .faith, .luck], id: \.self) { stat in
                            let g = variant.grade(stat, at: stored.upgrade)
                            if g != .none { Text("\(stat.shortName) \(g.rawValue)") }
                        }
                    }
                    .font(.subheadline.monospacedDigit())
                }
                LabeledContent("Weapon Buffs") {
                    Text(variant.isBuffable(at: stored.upgrade) ? "Can be buffed" : "Can't be buffed")
                        .foregroundStyle(variant.isBuffable(at: stored.upgrade) ? Color.green : Color.secondary)
                }
                let base = variant.level(stored.upgrade)
                if base[10] > 0 { LabeledContent("Bleed buildup") { Text("\(base[10].whole)").monospacedDigit() } }
                if base[11] > 0 { LabeledContent("Frost buildup") { Text("\(base[11].whole)").monospacedDigit() } }
            }
            if let absorption = weapon.absorption {
                LabeledContent("Physical block") { Text("\(absorption.whole)%").monospacedDigit() }
            }
            if let stability = weapon.stability {
                LabeledContent("Stability") { Text("\(stability.whole)").monospacedDigit() }
            }
            RequirementsRow(requirements: weapon.requirements(infusion), stats: stats, twoHanded: twoHanded)
        } header: {
            Text(weapon.kind == .catalyst ? "Catalyst" : "Damage")
        } footer: {
            if !result.meetsRequirements {
                Label("Below the requirements this weapon deals far less damage in the game. The number shown assumes they are met.",
                      systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            } else if !weapon.hasAttackTables && weapon.kind != .catalyst {
                Text("Shields and ranged weapons show their listed base attack; scaling isn't modelled for them yet.")
            }
        }
    }
}

/// "Requirements  STR 13  DEX 12" with each value turning red when the build falls short.
struct RequirementsRow: View {
    let requirements: WeaponRequirements
    let stats: StatBlock
    let twoHanded: Bool

    private var entries: [(stat: StatType, required: Int, met: Bool)] {
        Optimizer.damageStats.compactMap { stat in
            let required = requirements.requirement(for: stat)
            guard required > 0 else { return nil }
            var have = stats[stat]
            if stat == .strength && twoHanded { have = Int((Double(have) * 1.5).rounded(.down)) }
            return (stat, required, have >= required)
        }
    }

    var body: some View {
        if !entries.isEmpty {
            LabeledContent("Requirements") {
                HStack(spacing: 10) {
                    ForEach(entries, id: \.stat) { entry in
                        Text("\(entry.stat.shortName) \(entry.required)")
                            .monospacedDigit()
                            .foregroundStyle(entry.met ? Color.secondary : Color.red)
                    }
                }
                .font(.subheadline)
            }
        }
    }
}
