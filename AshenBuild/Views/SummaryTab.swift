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

            Section("Attack Rating") {
                if let main = report.mainHand { weaponRow(main, hand: "Main Hand", hp: report.hp) }
                if let off = report.offHand { weaponRow(off, hand: "Off Hand", hp: report.hp) }
                if report.mainHand == nil && report.offHand == nil {
                    Text("No weapons equipped").foregroundStyle(.secondary)
                }
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

            Section("Physical Defense") {
                DefenseGrid(items: [
                    ("Standard", report.physicalDefense.standard), ("Strike", report.physicalDefense.strike),
                    ("Slash", report.physicalDefense.slash), ("Thrust", report.physicalDefense.thrust),
                    ("Poise", report.poise),
                ])
            }

            Section("Elemental Defense") {
                DefenseGrid(items: [
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
                    Text(hand)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(report.total.whole)")
                    .font(.title3.weight(.semibold).monospacedDigit())
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

    private func conditionLabel(_ ring: Ring, hp: Int) -> String {
        guard let boost = ring.conditionalAttack else { return ring.family }
        var text = "\(ring.family), \(boost.label)"
        if let threshold = boost.hpThreshold { text += " (≤ \(Int((Double(hp) * threshold).rounded(.down))) HP)" }
        return text
    }
}
