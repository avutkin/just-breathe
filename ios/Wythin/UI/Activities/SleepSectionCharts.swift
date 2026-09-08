import SwiftUI

// MARK: - Charts, grouped under the section they explain
//
// The nine overnight traces used to sit in one undifferentiated strip below the
// hypnogram, in the order they happened to be declared. That put deceleration
// capacity — the metric the autonomic score is now mostly built from — nine
// scrolls away from the autonomic score itself, next to metrics that explain
// nothing about it.
//
// Each group here answers "what is this section made of", which is the only
// question a chart under a score needs to answer. Two sections have no
// per-tick trace at all and say so rather than borrowing one: timing is a fact
// about a fortnight of bedtimes, and duration is a single total against a
// need. Neither is a line through the night, and drawing one would imply a
// measurement that was never taken.

/// Which overnight traces belong under which section.
enum SleepSectionCharts {

    /// Metric labels, as declared in `activityMetricDefs`.
    static func metrics(for section: SleepSection) -> [String] {
        switch section {
        case .timing, .duration:
            // Nothing per-tick. Said out loud rather than padded.
            return []
        case .continuity:
            // Breath steadiness is one of continuity's three inputs, so the
            // breath trace belongs here rather than under a section of its own.
            return ["Breath Rate"]
        case .autonomic:
            // In the order the score reads them: how far the pulse fell, then
            // the vagal channels behind it, DC first because it carries the
            // larger share and is the one that survived FDR correction.
            return ["Pulse", "Vagal Tone", "Calm Power", "Inner Noise"]
        }
    }

    /// Everything not claimed by a section. Shown last, unscored, so the traces
    /// remain readable without implying they feed the number.
    static var unscored: [String] {
        let claimed = Set(SleepSection.allCases.flatMap { metrics(for: $0) })
        return activityMetricDefs.map(\.label).filter { !claimed.contains($0) }
    }

    /// One line on what the section is made of, for the header.
    static func madeOf(_ section: SleepSection) -> String {
        switch section {
        case .timing:
            return "The spread of your sleep onset across the nights recorded — not a trace through this one."
        case .duration:
            return "Time asleep against your need. A total, not a curve."
        case .continuity:
            return "Longest unbroken stretch, how many times it broke, and how steadily you breathed."
        case .autonomic:
            return "How far the pulse fell and when, then vagal tone against your own recent nights."
        }
    }
}

/// The traces for one section, on the night's shared clock.
struct SleepSectionChartGroup: View {
    let night: PreparedNight
    let section: SleepSection
    let startedAt: Date
    let endedAt: Date
    @Binding var selectedX: Date?

    private var labels: [String] { SleepSectionCharts.metrics(for: section) }

    var body: some View {
        if !labels.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(SleepSectionCharts.madeOf(section))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.dim)
                SleepMetricTraces(night: night, labels: labels,
                                  startedAt: startedAt, endedAt: endedAt,
                                  selectedX: $selectedX)
            }
        }
    }
}

/// A run of overnight metric traces, on the night's clock and sharing one
/// crosshair with every other channel on the screen.
///
/// Deliberately the same `MetricChartCard` the Live screen uses, configured the
/// same way the montage configured it — the point of the split is where the
/// charts sit, not how they look.
struct SleepMetricTraces: View {
    let night: PreparedNight
    let labels: [String]
    let startedAt: Date
    let endedAt: Date
    @Binding var selectedX: Date?

    @State private var pan: TimeInterval = 0

    private var defs: [ActivityMetricDef] {
        labels.compactMap { label in activityMetricDefs.first { $0.label == label } }
    }

    /// Kept in step with `SleepMontageChart.colour(_:)`. One metric, one colour,
    /// wherever it is drawn — a trace that changes colour when it moves under a
    /// different heading reads as a different measurement.
    private func colour(_ def: ActivityMetricDef) -> Color {
        switch def.techLabel {
        case "HR":     return Theme.warn
        case "RSA":    return Theme.rsa
        case "DC":     return Theme.coh
        case "DFA α1": return Theme.ulf
        case "SNS %":  return Theme.domainHeavy
        case "PIP":    return Theme.breathe
        default:       return Theme.hrv
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(defs) { def in
                MetricChartCard(
                    title: def.label,
                    technicalName: def.techFull.isEmpty ? def.techLabel : def.techFull,
                    subtitle: def.why,
                    yLabel: def.unit,
                    color: colour(def),
                    windows: [],
                    refs: [],
                    yDomain: 0...1,          // only read when the metric has no values at all
                    win: .h24,               // unused: `night` pins the span
                    night: startedAt...endedAt,
                    selectedX: $selectedX,
                    panOffset: $pan,
                    smooth: true,
                    dynamicY: true,
                    history: night.points,
                    rawHistory: night.points,
                    date: endedAt,
                    extract: def.extract
                )
            }
        }
    }
}
