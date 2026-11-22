import SwiftUI

struct ClassLevelTab: View {
    @Bindable var build: SavedBuild
    @Environment(DataStore.self) private var dataStore
    @FocusState private var focusedStat: StatType?

    private var startingClass: StartingClass? { dataStore.startingClass(build.classID) }
    private var baseStats: StatBlock { startingClass?.statBlock ?? StatBlock() }
    private var report: BuildReport { BuildCalculator.report(for: build.spec, data: dataStore) }

    var body: some View {
        let report = self.report
        Form {
            Section {
                MetricStrip(metrics: [
                    Metric(title: "Soul Level", value: "\(report.soulLevel)", emphasized: true),
                    Metric(title: "HP", value: "\(report.hp)"),
                    Metric(title: "FP", value: "\(report.fp)"),
                    Metric(title: "Stamina", value: "\(report.stamina)"),
                ])
            }

            Section {
                Picker("Starting Class", selection: $build.classID) {
                    ForEach(dataStore.startingClasses) { cls in
                        Label(cls.name, systemImage: cls.symbolName).tag(cls.id)
                    }
                }
                .onChange(of: build.classID) {
                    // Raise any stat currently below the new class's floor.
                    var raised = build.statBlock
                    for stat in StatType.allCases {
                        raised[stat] = max(raised[stat], baseStats[stat])
                    }
                    build.statBlock = raised
                }
                Button("Reset to Class Base", systemImage: "arrow.counterclockwise") {
                    build.statBlock = baseStats
                }
                .disabled(build.statBlock == baseStats)
            } footer: {
                if let flavor = startingClass?.flavor {
                    Text(flavor)
                }
            }

            Section {
                ForEach(StatType.allCases) { stat in
                    StatStepper(
                        stat: stat,
                        value: Binding(
                            get: { build.statBlock[stat] },
                            set: { newValue in
                                var updated = build.statBlock
                                updated[stat] = newValue
                                build.statBlock = updated
                            }
                        ),
                        minimum: baseStats[stat],
                        className: startingClass?.name ?? "This class",
                        focus: $focusedStat
                    )
                }
            } header: {
                HStack {
                    Text("Attributes")
                    Spacer()
                    let spent = build.statBlock - baseStats
                    if spent > 0 {
                        Text("\(spent) points spent")
                            .textCase(nil)
                            .monospacedDigit()
                    }
                }
            } footer: {
                Text("Tap a number to type it. Stats can't go below \(startingClass?.name ?? "the class")'s starting values.")
            }

            if report.effectiveStats != build.statBlock {
                Section {
                    ForEach(StatType.allCases.filter { report.effectiveStats[$0] != build.statBlock[$0] }) { stat in
                        LabeledContent(stat.displayName) {
                            Text("\(build.statBlock[stat]) → \(report.effectiveStats[stat])").monospacedDigit()
                        }
                    }
                } header: {
                    Text("With Rings")
                } footer: {
                    Text("Ring bonuses count for weapon requirements and scaling but not for Soul Level.")
                }
            }

            Section("Derived") {
                LabeledContent("Attunement Slots") {
                    Text("\(report.attunementSlots)").monospacedDigit()
                }
                LabeledContent("Equip Load Capacity") {
                    Text(report.capacity.oneDecimal).monospacedDigit()
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button("Previous", systemImage: "chevron.up") { moveFocus(-1) }
                    .disabled(focusedStat == StatType.allCases.first)
                Button("Next", systemImage: "chevron.down") { moveFocus(1) }
                    .disabled(focusedStat == StatType.allCases.last)
                Spacer()
                Button("Done") { focusedStat = nil }
                    .fontWeight(.semibold)
            }
        }
    }

    private func moveFocus(_ step: Int) {
        guard let current = focusedStat, let index = StatType.allCases.firstIndex(of: current) else { return }
        let next = index + step
        if StatType.allCases.indices.contains(next) { focusedStat = StatType.allCases[next] }
    }
}
