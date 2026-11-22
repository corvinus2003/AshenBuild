import SwiftUI

struct WeaponsTab: View {
    @Bindable var build: SavedBuild
    @Environment(DataStore.self) private var dataStore

    var body: some View {
        let spec = build.spec
        let report = BuildCalculator.report(for: spec, data: dataStore)
        Form {
            WeaponSlotEditor(
                title: "Main Hand",
                spec: spec,
                weaponReport: report.mainHand,
                effectiveStats: report.effectiveStats,
                hp: report.hp,
                weaponID: $build.mainHandWeaponID,
                upgradeLevel: $build.mainHandUpgradeLevel,
                infusionRaw: $build.mainHandInfusion,
                twoHanded: $build.twoHanded,
                allowsTwoHanding: true
            )
            WeaponSlotEditor(
                title: "Off Hand",
                spec: spec,
                weaponReport: report.offHand,
                effectiveStats: report.effectiveStats,
                hp: report.hp,
                weaponID: $build.offHandWeaponID,
                upgradeLevel: $build.offHandUpgradeLevel,
                infusionRaw: $build.offHandInfusion,
                twoHanded: .constant(false),
                allowsTwoHanding: false
            )
        }
    }
}

/// One hand's weapon: choice, upgrade, infusion, two-handing and the resulting attack rating.
private struct WeaponSlotEditor: View {
    let title: String
    let spec: BuildSpec
    let weaponReport: WeaponReport?
    let effectiveStats: StatBlock
    let hp: Int
    @Binding var weaponID: String?
    @Binding var upgradeLevel: Int
    @Binding var infusionRaw: String
    @Binding var twoHanded: Bool
    let allowsTwoHanding: Bool

    @Environment(DataStore.self) private var dataStore

    private var weapon: Weapon? { dataStore.weapon(weaponID) }
    private var infusion: InfusionType { InfusionType(rawValue: infusionRaw) ?? .none }

    var body: some View {
        Section {
            NavigationLink {
                WeaponGridPicker(
                    title: "\(title) Weapon",
                    spec: spec,
                    setup: WeaponSetup(weaponID: weaponID, upgrade: upgradeLevel, infusion: infusion,
                                       twoHanded: allowsTwoHanding && twoHanded)
                ) { newID in
                    guard newID != weaponID else { return }
                    weaponID = newID
                    if let new = dataStore.weapon(newID) { upgradeLevel = min(upgradeLevel, new.maxUpgrade) }
                    infusionRaw = InfusionType.none.rawValue
                }
            } label: {
                if let weapon {
                    HStack(spacing: 12) {
                        Text(weapon.category.abbreviation)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 26)
                            .background(weapon.category.tint.gradient, in: .rect(cornerRadius: 6, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(weapon.name)
                            Text(weapon.category.displayName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("Choose Weapon")
                        .foregroundStyle(.secondary)
                }
            }

            if let weapon {
                Stepper(value: $upgradeLevel, in: 0...weapon.maxUpgrade) {
                    LabeledContent("Upgrade") {
                        Text("+\(upgradeLevel)").monospacedDigit()
                    }
                }

                if weapon.infusable {
                    Picker("Infusion", selection: Binding(
                        get: { infusion },
                        set: { infusionRaw = $0.rawValue }
                    )) {
                        ForEach(InfusionType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }

                if allowsTwoHanding && weapon.canTwoHand {
                    Toggle("Two-Handed", isOn: $twoHanded)
                }
            }
        } header: {
            Text(title)
        } footer: {
            if allowsTwoHanding, let weapon, weapon.canTwoHand {
                Text("Two-handing raises effective Strength by 50%.")
            }
        }

        if let report = weaponReport {
            attackRatingSection(report)
        }
    }

    @ViewBuilder
    private func attackRatingSection(_ report: WeaponReport) -> some View {
        let result = report.result
        Section {
            HStack(alignment: .firstTextBaseline) {
                Text("Attack Rating")
                Spacer()
                Text("\(report.total.whole)")
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.tint)
                    .contentTransition(.numericText(value: report.total))
                    .animation(.snappy, value: report.total)
            }
            .accessibilityElement(children: .combine)

            ForEach(DamageType.allCases.filter { (result.breakdown[$0] ?? 0) > 0.5 }) { type in
                LabeledContent(type.displayName) {
                    Text("\((result.breakdown[type] ?? 0).whole)").monospacedDigit()
                }
            }

            ForEach(report.conditional, id: \.ring.id) { item in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        Label(item.ring.family, systemImage: "circle.circle")
                        Spacer()
                        Text("\(item.total.whole)")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(.tint)
                    }
                    Text(conditionText(item.ring))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }

            RequirementsRow(requirements: report.weapon.requirements, stats: effectiveStats,
                            twoHanded: report.setup.twoHanded && report.weapon.canTwoHand)

            LabeledContent("Weight") {
                Text(report.weapon.weight.oneDecimal).monospacedDigit()
            }
        } footer: {
            if !result.meetsRequirements {
                Label("Below the stat requirements, damage drops to \(Int(result.requirementRatio * 100))%.",
                      systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }

    private func conditionText(_ ring: Ring) -> String {
        guard let boost = ring.conditionalAttack else { return "" }
        var text = "+\(Int(boost.percent))% \(boost.label)"
        if let threshold = boost.hpThreshold {
            text += ": \(Int((Double(hp) * threshold).rounded(.down))) HP or less"
        }
        return text
    }
}

/// "Requirements  STR 13  DEX 12" with each value turning red when the build falls short.
private struct RequirementsRow: View {
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
