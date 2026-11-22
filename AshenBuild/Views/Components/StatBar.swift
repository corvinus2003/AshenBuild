import SwiftUI

/// One figure in a `MetricStrip`: a large number with a small caption under it.
struct Metric: Identifiable {
    let title: String
    let value: String
    var emphasized: Bool = false
    var id: String { title }
}

/// A row of headline numbers (Soul Level, HP, FP, Stamina), styled like the summary
/// strips in Apple's Fitness and Health apps. Sits inside a Form/List section.
struct MetricStrip: View {
    let metrics: [Metric]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                if index > 0 {
                    Divider().frame(height: 32)
                }
                VStack(spacing: 2) {
                    Text(metric.value)
                        .font(.title2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(metric.emphasized ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(metric.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(metric.title)
                .accessibilityValue(metric.value)
            }
        }
        .padding(.vertical, 6)
    }
}

/// Equip load readout: roll tier, weight used over capacity, and a capacity gauge.
struct EquipLoadView: View {
    let current: Double
    let capacity: Double
    let tier: Formulas.RollTier

    private var fraction: Double { capacity > 0 ? current / capacity : 0 }

    var tierColor: Color {
        switch tier {
        case .fast: return .green
        case .medium: return .yellow
        case .fat: return .orange
        case .overburdened: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label {
                    Text(tier.rawValue).fontWeight(.semibold)
                } icon: {
                    Circle().fill(tierColor).frame(width: 10, height: 10)
                }
                Spacer()
                Text("\(current, format: .number.precision(.fractionLength(1))) / \(capacity, format: .number.precision(.fractionLength(1)))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Gauge(value: min(fraction, 1)) {
                EmptyView()
            }
            .gaugeStyle(.linearCapacity)
            .tint(tierColor)
            .animation(.snappy, value: fraction)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Equip load")
        .accessibilityValue("\(tier.rawValue), \(Int((fraction * 100).rounded())) percent")
    }
}
