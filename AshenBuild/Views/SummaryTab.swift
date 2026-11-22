import SwiftUI

struct SummaryTab: View {
    @Bindable var build: SavedBuild
    @Environment(DataStore.self) private var dataStore

    var body: some View {
        let spec = build.spec
        let report = BuildCalculator.report(for: spec, data: dataStore)
        let ringEffects = BuildCalculator.ringEffects(for: spec, data: dataStore)
        Form {
            Section {
                MetricStrip(metrics: [
                    Metric(title: "Soul Level", value: "\(report.soulLevel)", emphasized: true),
                    Metric(title: "HP", value: "\(report.hp)"),
                    Metric(title: "FP", value: "\(report.fp)"),
                    Metric(title: "Stamina", value: "\(report.stamina)"),
                ])
            } footer: {
                if let cls = dataStore.startingClass(build.classID) {
                    Text("Started as \(cls.name).")
                }
            }

            Section {
                EquipLoadView(current: report.load, capacity: report.capacity, tier: report.rollTier)
            } header: {
                Text("Equip Load")
            } footer: {
                Text("\(Int((report.loadFraction * 100).rounded()))% of capacity. \(report.rollTier.rawValue) is \(report.rollTier.thresholdDescription).")
            }

            Section {
                HandSwitcher(build: build, hand: .right)
                if let main = report.mainHand { weaponRow(main, hand: "Right Hand", hp: report.hp) }
                HandSwitcher(build: build, hand: .left)
                if let off = report.offHand { weaponRow(off, hand: "Left Hand", hp: report.hp) }
            } header: {
                Text("Weapons Held")
            } footer: {
                Text("Tap a slot to hold that weapon. Attack rating, requirements and the optimizer follow it.")
            }

            Section {
                BuffPicker(build: build)
                if report.buffStatus != .none {
                    Label(buffStatusText(report), systemImage: report.buffStatus == .applied ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(report.buffStatus == .applied ? Color.green : Color.orange)
                }
            } header: {
                Text("Weapon Buff")
            }

            if !ringEffects.isEmpty {
                Section {
                    ForEach(ringEffects) { effect in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(effect.ring.name).fontWeight(.semibold)
                            ForEach(effect.lines, id: \.self) { line in
                                Text(line)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        .padding(.vertical, 2)
                        .accessibilityElement(children: .combine)
                    }
                } header: {
                    Text("Ring Effects")
                } footer: {
                    Text("Each line compares this build with and without that ring.")
                }
            }

            Section {
                DefenseGrid(percent: true, items: [
                    ("Standard", report.physicalDefense.standard), ("Strike", report.physicalDefense.strike),
                    ("Slash", report.physicalDefense.slash), ("Thrust", report.physicalDefense.thrust),
                ])
                LabeledContent("Poise") { Text(report.poise.oneDecimal).monospacedDigit() }
            } header: {
                Text("Physical Absorption")
            } footer: {
                Text("Armor absorptions multiply together, as in the game.")
            }

            Section("Elemental Absorption") {
                DefenseGrid(percent: true, items: [
                    ("Magic", report.elementalDefense.magic), ("Fire", report.elementalDefense.fire),
                    ("Lightning", report.elementalDefense.lightning), ("Dark", report.elementalDefense.dark),
                ])
            }

            Section("Resistances") {
                DefenseGrid(items: [
                    ("Bleed", report.resistances.bleed), ("Poison", report.resistances.poison),
                    ("Frost", report.resistances.frost), ("Curse", report.resistances.curse),
                ])
            }
        }
    }

    private func weaponRow(_ report: WeaponReport, hand: String, hp: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(report.weapon.name)
                    Text("+\(report.setup.upgrade)\(report.weapon.infusable ? " " + report.setup.infusion.displayName : "")\(report.setup.twoHanded && report.weapon.canTwoHand ? " · two-handed" : "")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(report.total.whole)")
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(report.result.meetsRequirements ? Color.primary : Color.orange)
                    Text(report.weapon.hasAttackTables ? "AR" : "ATK").font(.caption2).foregroundStyle(.secondary)
                }
            }
            if !report.result.meetsRequirements {
                Text("Requirements not met: far less damage in the game")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            if let buff = report.buffApplied {
                Text("\(buff.name) +\(report.buffGain.whole)")
                    .font(.footnote)
                    .foregroundStyle(.green)
            }
            ForEach(report.conditional, id: \.ring.id) { item in
                HStack {
                    Text(conditionLabel(item.ring, hp: hp))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(item.total.whole)")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.tint)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func buffStatusText(_ report: BuildReport) -> String {
        switch report.buffStatus {
        case .applied: return "Applied to \(report.mainHand?.weapon.name ?? "your weapon")"
        case .notBuffable: return "\(report.mainHand?.weapon.name ?? "This weapon") can't be buffed (it already has elemental damage, or the game doesn't allow it)"
        case .cannotCast: return "Your Intelligence or Faith is below the spell's requirement"
        case .noCatalyst: return "No equipped catalyst can cast this spell"
        case .none: return ""
        }
    }

    private func conditionLabel(_ ring: Ring, hp: Int) -> String {
        guard let boost = ring.conditionalAttack else { return ring.family }
        var text = "\(ring.family), \(boost.label)"
        if let threshold = boost.hpThreshold { text += " (≤ \(Int((Double(hp) * threshold).rounded(.down))) HP)" }
        return text
    }
}

/// Tap one of the three slots of a hand to hold it.
struct HandSwitcher: View {
    @Bindable var build: SavedBuild
    let hand: Hand
    @Environment(DataStore.self) private var dataStore

    var body: some View {
        let loadout = build.loadout
        let slots = hand == .right ? loadout.right : loadout.left
        let active = hand == .right ? loadout.activeRight : loadout.activeLeft
        VStack(alignment: .leading, spacing: 6) {
            Text(hand.rawValue).font(.footnote).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    let weapon = dataStore.weapon(slots[i].weaponID)
                    Button {
                        var l = build.loadout
                        if hand == .right { l.activeRight = i } else { l.activeLeft = i }
                        build.loadout = l
                    } label: {
                        Text(weapon?.name ?? "Empty")
                            .font(.caption.weight(.medium))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .padding(.horizontal, 4)
                            .foregroundStyle(i == active ? Color.white : (weapon == nil ? Color.secondary : Color.primary))
                            .background(i == active ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color(.tertiarySystemFill)),
                                        in: .rect(cornerRadius: 9, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(weapon == nil && i != active)
                    .accessibilityAddTraits(i == active ? .isSelected : [])
                }
            }
        }
        .padding(.vertical, 2)
        .sensoryFeedback(.selection, trigger: active)
    }
}

/// Choose the weapon buff (spells that buff weapons, and resins).
struct BuffPicker: View {
    @Bindable var build: SavedBuild
    @Environment(DataStore.self) private var dataStore

    var body: some View {
        let buffs = dataStore.spells.filter(\.isWeaponBuff)
        Picker("Buff", selection: Binding(
            get: { build.loadout.buffID ?? "" },
            set: { v in var l = build.loadout; l.buffID = v.isEmpty ? nil : v; build.loadout = l }
        )) {
            Text("None").tag("")
            ForEach(SpellSchool.allCases) { school in
                let list = buffs.filter { $0.school == school }
                if !list.isEmpty {
                    Section(school.displayName) {
                        ForEach(list) { Text($0.name).tag($0.id) }
                    }
                }
            }
        }
    }
}
