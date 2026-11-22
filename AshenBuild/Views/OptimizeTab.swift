import SwiftUI

/// Answers "is my build optimized enough?": a verdict, what's off, the best respec at
/// Rosaria for targets you choose, the best infusion, and stronger weapons for your level.
struct OptimizeTab: View {
    @Bindable var build: SavedBuild
    @Environment(DataStore.self) private var dataStore

    enum RollChoice: String, CaseIterable, Identifiable {
        case keep = "Keep", fast = "Fast", medium = "Mid", fat = "Fat"
        var id: Self { self }
        var tier: Formulas.RollTier? {
            switch self {
            case .keep: return nil
            case .fast: return .fast
            case .medium: return .medium
            case .fat: return .fat
            }
        }
    }

    @State private var minVigor: Int?
    @State private var minEndurance: Int?
    @State private var minAttunement: Int?
    @State private var roll: RollChoice = .keep
    @State private var pendingApply: PendingChange?
    @State private var alternatives: Alternatives?

    private struct Alternatives {
        let key: String
        let infusions: [WeaponOption]
        let weapons: [WeaponOption]
    }

    private struct PendingChange: Identifiable {
        let title: String
        let stats: StatBlock
        let mainHand: WeaponSetup?
        var id: String { title }
    }

    private func goal(for spec: BuildSpec) -> RespecGoal {
        RespecGoal(minVigor: minVigor ?? spec.stats[.vigor],
                   minEndurance: minEndurance ?? spec.stats[.endurance],
                   minAttunement: minAttunement ?? spec.stats[.attunement],
                   roll: roll.tier)
    }

    var body: some View {
        let spec = build.spec
        let analysis = Optimizer.analyze(spec, data: dataStore)
        let goal = goal(for: spec)
        let respec = Optimizer.respec(spec, goal: goal, data: dataStore)
        let base = analysis.current.baseStats

        Form {
            verdictSection(analysis)

            Section("Findings") {
                ForEach(analysis.issues) { issue in
                    IssueRow(issue: issue)
                }
                if analysis.issues.isEmpty {
                    Text("Equip a weapon to get findings.").foregroundStyle(.secondary)
                }
            }

            Section {
                targetStepper("Vigor at least", value: Binding(get: { minVigor ?? spec.stats[.vigor] }, set: { minVigor = $0 }),
                              floor: base[.vigor], hint: "\(Formulas.hp(vigor: minVigor ?? spec.stats[.vigor])) HP")
                targetStepper("Endurance at least", value: Binding(get: { minEndurance ?? spec.stats[.endurance] }, set: { minEndurance = $0 }),
                              floor: base[.endurance], hint: "\(Formulas.stamina(endurance: minEndurance ?? spec.stats[.endurance])) stamina")
                targetStepper("Attunement at least", value: Binding(get: { minAttunement ?? spec.stats[.attunement] }, set: { minAttunement = $0 }),
                              floor: base[.attunement], hint: slotsText(Formulas.attunementSlots(attunement: minAttunement ?? spec.stats[.attunement])))
                VStack(alignment: .leading, spacing: 8) {
                    Text("Roll")
                    Picker("Roll", selection: $roll) {
                        ForEach(RollChoice.allCases) { choice in
                            Text(choice == .keep ? "Keep VIT" : choice.rawValue).tag(choice)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            } header: {
                Text("Respec at Rosaria · Targets")
            } footer: {
                Text("Same Soul Level and starting class. Weapon requirements are always met; every other point goes where it adds the most attack rating.")
            }

            respecResultSection(current: analysis.current, result: respec)

            alternativesSections(spec: spec, goal: goal, currentAR: analysis.current.primaryWeapon?.total)
        }
        .task(id: "\(spec.hashValue)-\(goal.hashValue)") {
            await loadAlternatives(spec: spec, goal: goal)
        }
        .confirmationDialog(pendingApply?.title ?? "", isPresented: Binding(get: { pendingApply != nil }, set: { if !$0 { pendingApply = nil } }),
                            titleVisibility: .visible, presenting: pendingApply) { change in
            Button("Apply") {
                build.statBlock = change.stats
                if let setup = change.mainHand { build.setMainHand(setup) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Your stats change to the suggested ones. In the game this costs one Pale Tongue at Rosaria.")
        }
    }

    // MARK: - Sections

    private func verdictSection(_ analysis: Analysis) -> some View {
        Section {
            HStack(spacing: 18) {
                Gauge(value: analysis.score ?? 0) {
                    EmptyView()
                } currentValueLabel: {
                    Text(analysis.score.map { "\(Int(($0 * 100).rounded(.down)))" } ?? "–")
                        .font(.title2.weight(.bold).monospacedDigit())
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(verdictColor(analysis.score))
                .scaleEffect(1.35)
                .frame(width: 76, height: 76)

                VStack(alignment: .leading, spacing: 4) {
                    Text(analysis.verdict)
                        .font(.title3.weight(.bold))
                    if let now = analysis.current.primaryWeapon, let best = analysis.best.report.primaryWeapon {
                        Text("\(now.weapon.name): \(now.total.whole) AR of \(best.total.whole) possible at SL \(analysis.current.soulLevel).")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("The score compares your attack rating with the best split of the same points.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(analysis.verdict), score \(Int(((analysis.score ?? 0) * 100).rounded(.down))) percent")
        }
    }

    @ViewBuilder
    private func respecResultSection(current: BuildReport, result: RespecResult) -> some View {
        Section {
            if !result.feasible {
                Label("These targets need \(result.shortfall) more levels at this Soul Level.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            } else {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    GridRow {
                        Text("Stat").foregroundStyle(.secondary)
                        Text("Now").foregroundStyle(.secondary).gridColumnAlignment(.trailing)
                        Text("Respec").foregroundStyle(.secondary).gridColumnAlignment(.trailing)
                        Text("").gridColumnAlignment(.trailing)
                    }
                    .font(.caption)
                    ForEach(StatType.allCases) { stat in
                        let now = build.statBlock[stat], new = result.stats[stat]
                        GridRow {
                            Text(stat.displayName)
                            Text("\(now)").monospacedDigit().foregroundStyle(.secondary)
                            Text("\(new)").monospacedDigit().fontWeight(now == new ? .regular : .semibold)
                            delta(new - now)
                        }
                        .font(.subheadline)
                    }
                }
                .padding(.vertical, 4)

                if let now = current.primaryWeapon, let new = result.report.primaryWeapon {
                    comparison("Attack Rating", now.total.whole, new.total.whole)
                }
                comparison("HP", current.hp, result.report.hp)
                comparison("Stamina", current.stamina, result.report.stamina)
                LabeledContent("Roll") {
                    Text(current.rollTier == result.report.rollTier ? current.rollTier.rawValue
                         : "\(current.rollTier.rawValue) → \(result.report.rollTier.rawValue)")
                }

                Button("Apply This Respec", systemImage: "arrow.triangle.2.circlepath") {
                    pendingApply = PendingChange(title: "Apply the respec?", stats: result.stats, mainHand: nil)
                }
                .disabled(result.stats == build.statBlock)
            }
        } header: {
            Text("Suggested Respec")
        }
    }

    @ViewBuilder
    private func alternativesSections(spec: BuildSpec, goal: RespecGoal, currentAR: Double?) -> some View {
        let key = "\(spec.hashValue)-\(goal.hashValue)"
        if let alternatives, alternatives.key == key {
            if !alternatives.infusions.isEmpty {
                Section {
                    ForEach(alternatives.infusions.prefix(4)) { option in
                        optionRow(option, title: option.setup.infusion.displayName,
                                  subtitle: option.setup.infusion == spec.mainHand.infusion ? "Current infusion, after respec" : "After respec",
                                  currentAR: currentAR, isCurrent: option.setup.infusion == spec.mainHand.infusion)
                    }
                } header: {
                    Text("Best Infusion")
                }
            }
            if !alternatives.weapons.isEmpty {
                Section {
                    ForEach(alternatives.weapons) { option in
                        optionRow(option, title: option.weapon.name,
                                  subtitle: "\(option.setup.infusion == .none ? "" : option.setup.infusion.displayName + " ")+\(option.setup.upgrade) · \(option.weapon.weight.oneDecimal) wt",
                                  currentAR: currentAR, isCurrent: option.weapon.id == spec.mainHand.weaponID)
                    }
                } header: {
                    Text("Strongest Weapons for You")
                } footer: {
                    Text("Each weapon with its best infusion and its own respec, at the same upgrade progress as your weapon. Uses your targets above.")
                }
            }
        } else if spec.mainHand.weaponID != nil {
            Section {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Trying every weapon and infusion…").foregroundStyle(.secondary)
                }
            }
        }
    }

    private func optionRow(_ option: WeaponOption, title: String, subtitle: String, currentAR: Double?, isCurrent: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                    if isCurrent {
                        Text("Current")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Color(.tertiarySystemFill), in: .capsule)
                    }
                }
                Text(subtitle).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(option.attackRating.whole)")
                    .font(.headline.monospacedDigit())
                if let currentAR {
                    let diff = option.attackRating - currentAR
                    Text(diff >= 0 ? "+\(diff.whole)" : "\(diff.whole)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(diff > 0.5 ? Color.green : Color.secondary)
                }
            }
            Menu {
                Button("Use with Respec", systemImage: "checkmark.circle") {
                    pendingApply = PendingChange(title: "Switch to \(title)?", stats: option.respec.stats, mainHand: option.setup)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
            }
            .accessibilityLabel("Options for \(title)")
        }
    }

    // MARK: - Pieces

    private func targetStepper(_ title: String, value: Binding<Int>, floor: Int, hint: String) -> some View {
        Stepper(value: value, in: floor...99) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(hint).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(value.wrappedValue)").monospacedDigit().fontWeight(.semibold)
            }
        }
    }

    private func slotsText(_ count: Int) -> String {
        count == 1 ? "1 attunement slot" : "\(count) attunement slots"
    }

    private func comparison(_ title: String, _ now: Int, _ new: Int) -> some View {
        LabeledContent(title) {
            HStack(spacing: 6) {
                Text("\(now)").foregroundStyle(.secondary)
                Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary)
                Text("\(new)").fontWeight(.semibold)
                delta(new - now)
            }
            .monospacedDigit()
        }
    }

    private func delta(_ value: Int) -> some View {
        Text(value == 0 ? "" : (value > 0 ? "+\(value)" : "\(value)"))
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(value > 0 ? Color.green : Color.orange)
            .frame(minWidth: 30, alignment: .trailing)
    }

    private func verdictColor(_ score: Double?) -> Color {
        guard let score else { return .gray }
        if score >= 0.98 { return .green }
        if score >= 0.90 { return .yellow }
        return .orange
    }

    private func loadAlternatives(spec: BuildSpec, goal: RespecGoal) async {
        guard spec.mainHand.weaponID != nil else { alternatives = nil; return }
        let key = "\(spec.hashValue)-\(goal.hashValue)"
        let data = dataStore
        let result = await Task.detached(priority: .userInitiated) {
            Alternatives(key: key,
                         infusions: Optimizer.infusionOptions(spec, goal: goal, data: data),
                         weapons: Optimizer.weaponOptions(spec, goal: goal, data: data))
        }.value
        if !Task.isCancelled { alternatives = result }
    }
}

private struct IssueRow: View {
    let issue: Issue

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(issue.title).fontWeight(.semibold)
                Text(issue.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch issue.kind {
        case .good: return "checkmark.seal.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch issue.kind {
        case .good: return .green
        case .info: return .blue
        case .warning: return .orange
        }
    }
}
