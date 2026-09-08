import SwiftUI

// MARK: - Shared colour

extension SleepStageDetail {
    /// One ramp, defined once. Awake sits outside it because awake is not a
    /// depth — it is the absence of one, and colouring it as "very light sleep"
    /// puts it on a scale it does not belong to.
    var colour: Color {
        switch self {
        case .wake: return Color(hex: "#F0EAE2")
        case .rem:  return Color(hex: "#BCDCF7")
        case .n1:   return Color(hex: "#74AEE4")
        case .n2:   return Color(hex: "#3F7CC0")
        case .n3:   return Color(hex: "#22508F")
        }
    }
}

/// One metric, one colour, wherever it is drawn. A trace that changes colour
/// when it moves under a different heading reads as a different measurement.
func sleepMetricColour(_ def: ActivityMetricDef) -> Color {
    switch def.techLabel {
    case "HR":     return Theme.warn
    case "RSA":    return Theme.rsa
    case "DC":     return Theme.coh
    case "DFA α1": return Theme.ulf
    case "SNS":    return Theme.domainHeavy
    case "PIP":    return Theme.breathe
    default:       return Theme.hrv
    }
}

// MARK: - Prose, folded away

/// A paragraph behind a tap.
///
/// Every explanation on this screen used to be printed in full, above the
/// thing it explained. Six of them in a row is a wall, and the effect is that
/// none get read and the measurement underneath gets scrolled past. The words
/// are still here for the one time somebody wants them; they are just not in
/// front of the number any more.
struct SleepNote: View {
    let title: String
    let body_: String
    @State private var open = false

    init(_ title: String, _ body: String) {
        self.title = title
        self.body_ = body
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.16)) { open.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(0.7)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                        .rotationEffect(.degrees(open ? 180 : 0))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(Theme.dim.opacity(0.85))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if open {
                Text(body_)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - What one channel read

/// The low, the middle and the high of one metric, and what each stage held.
///
/// This replaced the paragraph that used to sit under every overnight chart.
/// The paragraph said what the metric was for; it never said what yours did.
/// The three numbers say where the night ran, the arrow says which end is the
/// good one, and the stage bars answer the question a single night average
/// cannot — whether the body was calmer asleep than awake, and how much.
struct SleepMetricReadout: View {
    let night: PreparedNight
    let def: ActivityMetricDef

    private var tint: Color { sleepMetricColour(def) }

    private var extremes: PreparedNight.MetricExtremes? { night.extremes[def.id] }

    /// Which direction counts as better OVERNIGHT, in words — and nothing at
    /// all where that is not established.
    ///
    /// `def.direction` is the practice reading: it says which way a metric
    /// should move while you sit and breathe on purpose. Most of those hold
    /// asleep, but not all of them, and "lower is better" printed under a
    /// sleeping breath rate is a claim nobody has made. Sleep respiration is
    /// regular rather than slow, and a rate read off the beat interval is at
    /// its least reliable in exactly the stretches this would be judging. So
    /// the cue appears only for the four channels where the overnight
    /// direction is actually evidenced, and stays silent elsewhere rather
    /// than inventing a verdict.
    private var goodEnd: String? {
        switch def.metric {
        case .hr:    return "lower overnight = deeper autonomic recovery"
        case .dc:    return "higher = more vagal recovery"
        case .rmssd: return "higher = more vagal recovery"
        case .pip:   return "lower = a cleaner, less erratic signal"
        default:     return nil
        }
    }

    private static let clock: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    /// Stages in depth order, not in the order the night happened to visit
    /// them, so the eye reads a ramp rather than a shuffle.
    private var stageRows: [(SleepStageDetail, PreparedNight.StageReading)] {
        let per = night.byStage[def.id] ?? [:]
        return SleepStageDetail.allCases.compactMap { stage in
            per[stage].map { (stage, $0) }
        }
    }

    var body: some View {
        if let e = extremes {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top, spacing: 0) {
                    reading("LOW", e.low, at: e.lowAt)
                    Spacer(minLength: 6)
                    reading("TYPICAL", e.typical, at: nil)
                    Spacer(minLength: 6)
                    reading("HIGH", e.high, at: e.highAt)
                }
                if let goodEnd {
                    Text(goodEnd)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Theme.dim.opacity(0.75))
                }
                if stageRows.count >= 2 { stageBars(e) }
            }
        }
    }

    private func reading(_ label: String, _ value: Double, at date: Date?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(Theme.dim.opacity(0.8))
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(def.format(value))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.text)
                if !def.unit.isEmpty {
                    Text(def.unit)
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.dim)
                }
            }
            Text(date.map { Self.clock.string(from: $0) } ?? "median asleep")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Theme.dim.opacity(0.8))
        }
    }

    /// Each stage's median on the night's own scale, so the bars are comparable
    /// with each other and with the three numbers above them.
    private func stageBars(_ e: PreparedNight.MetricExtremes) -> some View {
        // The bars share the axis of the readings above, widened if a stage
        // median falls outside the asleep range — awake often does.
        let values = stageRows.map(\.1.value)
        let lo = min(e.low, values.min() ?? e.low)
        let hi = max(e.high, values.max() ?? e.high)
        let span = max(hi - lo, 0.000001)
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(stageRows, id: \.0) { stage, reading in
                HStack(spacing: 6) {
                    Text(stage.label)
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.dim)
                        .frame(width: 62, alignment: .leading)
                    GeometryReader { geo in
                        Capsule()
                            .fill(stage.colour)
                            .frame(width: max(3, geo.size.width * ((reading.value - lo) / span)),
                                   height: 6)
                            .frame(maxHeight: .infinity, alignment: .center)
                    }
                    .frame(height: 8)
                    Text(def.format(reading.value))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.text)
                        .frame(width: 42, alignment: .trailing)
                    // The hour is the other half of the reading. Without it
                    // these bars get compared as though the stages happened at
                    // the same time of night, and they never do.
                    Text(Self.clock.string(from: reading.at))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Theme.dim.opacity(0.8))
                        .frame(width: 38, alignment: .trailing)
                }
            }
            Text("mostly at that hour — your pulse follows the night's own curve, so compare the hours before you compare the stages")
                .font(.system(size: 9))
                .foregroundStyle(Theme.dim.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 1)
        }
    }
}

// MARK: - Highlights

/// The few things about this night worth saying out loud.
///
/// Built from the night's own numbers, not from a model: each one is a fact
/// with a clock time attached, so it can be checked against the charts below
/// it. Anything that cannot be computed is simply absent — the card shrinks
/// rather than padding itself with a sentence that is true of every night.
struct SleepHighlight: Identifiable {
    let id: String
    let icon: String
    let value: String
    let caption: String
}

enum SleepHighlights {

    private static let clock: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    static func of(_ night: PreparedNight, entry: ActivityLog) -> [SleepHighlight] {
        var out: [SleepHighlight] = []

        func def(_ metric: LiveMetric) -> ActivityMetricDef { metricDef(metric) }

        // Where the night bottomed out. The single most-used marker of an
        // autonomic night, and the one a wearable measures best.
        if let hr = night.extremes[def(.hr).id] {
            out.append(SleepHighlight(
                id: "nadir",
                icon: "arrow.down.to.line",
                value: "\(Int(hr.low.rounded())) bpm at \(clock.string(from: hr.lowAt))",
                caption: "your lowest pulse — \(Int((hr.typical - hr.low).rounded())) bpm under the night's typical"))
        }

        // The recovery window: vagal tone is the channel the autonomic score is
        // mostly built from, so its best moment is worth naming.
        if let dc = night.extremes[def(.dc).id] {
            out.append(SleepHighlight(
                id: "dc",
                icon: "leaf",
                value: "\(String(format: "%.1f", dc.high)) ms at \(clock.string(from: dc.highAt))",
                caption: "vagal tone at its strongest; it ran as low as \(String(format: "%.1f", dc.low)) ms"))
        }

        // The one the sleeper can act on, and the contrast they will notice.
        let breath = def(.breathBPM)
        if let perStage = night.byStage[breath.id],
           let deep = perStage[.n3]?.value, let wake = perStage[.wake]?.value {
            let faster = deep > wake
            out.append(SleepHighlight(
                id: "breath",
                icon: "wind",
                value: "\(breath.format(deep)) vs \(breath.format(wake)) br/min",
                caption: faster
                    ? "you breathed faster in deep sleep than during your awake stretches — sleep breathing is regular rather than slow, and the awake minutes here are lying still"
                    : "your breath ran slower in deep sleep than during your awake stretches"))
        }

        // Continuity, in the terms the section is scored in.
        if let longest = longestUnbroken(night) {
            out.append(SleepHighlight(
                id: "unbroken",
                icon: "moon.zzz",
                value: hm(Int(longest / 60)),
                caption: "your longest unbroken stretch of sleep"))
        }

        if let supine = night.supineSharePct {
            out.append(SleepHighlight(
                id: "supine",
                icon: "bed.double",
                value: "\(supine)% on your back",
                caption: "of the time your position was known"))
        }

        return out
    }

    private static func longestUnbroken(_ night: PreparedNight) -> TimeInterval? {
        var best: TimeInterval = 0
        var run: TimeInterval = 0
        for r in night.stageRuns {
            if r.stage.isAsleep {
                run += r.end.timeIntervalSince(r.start)
                best = max(best, run)
            } else {
                run = 0
            }
        }
        return best > 0 ? best : nil
    }

    private static func hm(_ minutes: Int) -> String {
        "\(minutes / 60)h \(String(format: "%02d", minutes % 60))m"
    }
}

/// The highlights, as a list you can read in one pass.
struct SleepHighlightsCard: View {
    let items: [SleepHighlight]

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: item.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(ActivityType.sleep.color)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.value)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.text)
                        Text(item.caption)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.dim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}
