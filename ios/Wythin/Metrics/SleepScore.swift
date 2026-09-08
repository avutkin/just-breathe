import Foundation

// MARK: - Sections

/// The five sections a night is scored on, ordered by the strength of the
/// evidence behind them — which is also the order of their weights.
///
/// Notably absent: stage percentages. They are what every consumer product
/// leads with and they have the weakest link to outcomes of anything here,
/// measured on hardware that agrees with polysomnography at κ 0.21–0.53. A
/// number precise enough to be believed and wrong often enough to mislead does
/// not belong in a score.
/// Four sections, not five.
///
/// Breathing was scored as its own axis and was not one. What it measured is
/// the steadiness of the breath *rate* — and `SleepBreathing`'s own
/// documentation calls that "the single best wake/sleep discriminator", with
/// the identical signal feeding the wake classifier. So it was a second
/// measurement of whether you were asleep, sitting beside continuity, which
/// measures the same thing. Two of five sections, 30% of the number, one
/// construct. On a real night they read 100 and 3 across the same eleven hours.
///
/// It is now an input to continuity, which is what it was all along.
///
/// The airway — apnea and hypopnea events, the thing that would earn a
/// breathing section outright — is not built. When it is, it takes a fifth
/// share and these fall to 20%.
enum SleepSection: String, CaseIterable, Codable {
    case timing, duration, continuity, autonomic

    /// Fixed, visible, and equal.
    ///
    /// Equal is a deliberate admission rather than a shrug: the true weights
    /// are not known. Regularity has the strongest outcome evidence, duration
    /// the clearest dose–response, autonomic the only overnight metrics that
    /// survived FDR correction in HypnoLaus, and continuity the weakest
    /// measurement of the four. Nobody has published the exchange rate between
    /// them. Four quarters a reader can check beats five numbers implying a
    /// precision that does not exist.
    var weight: Double { 0.25 }

    /// Band wording for a night. The exercise vocabulary ("act on it", "keep
    /// doing this") reads as instructions about a workout you chose; nobody
    /// chooses how a night went, and being told to act on your continuity at
    /// breakfast is neither actionable nor kind.
    static func verdict(for value: Int) -> String {
        switch IndexBand.of(value) {
        case .act:     return "below your usual"
        case .improve: return "about usual"
        case .keep:    return "a good night for you"
        }
    }

    var name: String {
        switch self {
        case .timing:     return "Timing"
        case .duration:   return "Duration"
        case .continuity: return "Continuity"
        case .autonomic:  return "Autonomic"
        }
    }

    /// What the section measures, the evidence for weighting it, and the limit
    /// worth knowing — the three things somebody asking "what is this number"
    /// actually wants.
    ///
    /// Held here rather than in the view because it belongs beside the weight
    /// it justifies. A weight whose reasoning lives in another file drifts away
    /// from it, and the reasoning is the only thing making a fixed weight
    /// honest rather than arbitrary.
    ///
    /// Every limit is a real one this app has, stated plainly. A section that
    /// only explains why it is good is marketing.
    var explanation: (measures: String, evidence: String, limit: String) {
        switch self {
        case .timing:
            return (
                "Two things: which hour you went to sleep, and how tightly your bedtimes cluster across every night recorded. Gaps between nights cost nothing — three nights months apart count the same as three in a row.",
                "In 60,977 people the most regular quintile carried an all-cause mortality hazard of 0.70 against the least regular. Head to head it beat duration: adding hours slept to a model that already knew your regularity added nothing measurable. So consistency carries most of this, and the hour itself the rest.",
                "The hour is scored against a 22:00–23:00 window, and both ends count — very early nights are associated with raised risk much as late ones are, so this is not \"earlier is always better\". That evidence is weaker than the regularity evidence. Consistency needs three nights; until then the hour is scored on its own."
            )
        case .duration:
            return (
                "Time actually asleep, against the sleep you need.",
                "Fourteen nights at six hours leaves you performing like someone awake for a day and a night, and the deficit keeps growing rather than levelling off. People cannot feel it — at six hours they rate themselves about as sleepy as at four, while their measured performance keeps falling.",
                "Sleep need varies by about ±0.7 h between people and is a fixed figure here rather than yours. Sleeping longer than your need is not scored as a fault."
            )
        case .continuity:
            return (
                "The longest stretch you held, how many times it broke, and how steadily you breathed.",
                "One four-hour block is not eight thirty-minute ones at the same total. Fragmenting sleep degrades next-day function even when the hours are unchanged.",
                "Wake is the weakest thing any wearable measures — specificity runs 29–52% — and arousals shorter than a minute are smoothed away entirely. Read this as a description of the night, not a count."
            )
        case .autonomic:
            return (
                "How far your pulse fell overnight and when it bottomed out, then your vagal tone against your own recent nights.",
                "Of every heart-rate-variability measure tested against cardiovascular events in 1,784 people, only deceleration capacity and heart-rate fragmentation survived correction — every classical HRV number did not. So DC carries more of this than RMSSD does.",
                "Vagal tone is read inside quiet sleep only: it drops through REM, so a whole-night average is partly a measure of how much REM you had. Needs a few nights before there is a baseline to compare against."
            )
        }
    }
}

// MARK: - Input

/// Everything the score needs, already measured. Optional throughout: a
/// section with no input is **absent**, never zero.
struct SleepScoreInput {
    /// Circular SD of sleep onset, in minutes. Lower is steadier. Needs three
    /// nights, which need not be consecutive — see `BedtimeConsistency`.
    var bedtimeSDMin: Double?
    /// Minutes this night's onset fell outside the 22:00–23:00 window, zero
    /// when inside — see `BedtimePlacement`. Available from a single night,
    /// which is what keeps Timing from being blank for somebody who wears the
    /// strap three times rather than every night.
    var bedtimeOutsideMin: Double?
    var asleepSec: Double?
    var needSec: Double             // this wearer's own need, not a population figure
    var wakeBouts: Int?
    var longestUnbrokenSec: Double?
    var hrNadirDip: Float?          // bpm below the settled-onset rate
    var hrNadirFraction: Double?    // where in the night the nadir fell, 0–1
    /// Vagal tone inside quiet sleep, and this sleeper's own recent median of
    /// the same measurement. Both are needed: the pair is scored as a ratio,
    /// because the level is trait and only the deviation is the night.
    ///
    /// RMSSD falls steeply with age and varies several-fold between healthy
    /// people — the old absolute 22–62 ms ramp meant a healthy sixty-year-old
    /// could not score well on it however they slept, which measured identity
    /// rather than sleep and contradicted the rule the rest of this file keeps.
    var quietRMSSD: Float?
    var quietRMSSDBaseline: Float?
    /// Deceleration capacity, same treatment. Better evidenced than RMSSD as a
    /// risk marker — in HypnoLaus, after FDR correction DC survived and every
    /// time- and frequency-domain HRV parameter did not — so it carries the
    /// larger share of the pair.
    var quietDC: Float?
    var quietDCBaseline: Float?
    var steadyFraction: Double?     // share of the night breathing read as steady
}

// MARK: - Score

struct SleepScore {
    let sections: [SleepSection: Int]
    let overall: Int?
    /// The arithmetic, spelled out. The exercise research condemned opaque
    /// composites — none of fourteen consumer composite scores survived
    /// independent validation — so this one shows its working or it does not
    /// ship.
    let arithmetic: String

    static func compute(_ input: SleepScoreInput) -> SleepScore {
        var sections: [SleepSection: Int] = [:]

        // Timing is two things: how consistent your hours are, and which hours
        // they are. Consistency is the better evidenced of the two and carries
        // the larger share — but it needs three nights, and placement needs
        // one. On a strap worn a handful of times, placement is what keeps the
        // section from reading "not measured" for weeks.
        //
        // Both are negated so the ramp still runs worst→best: less is better.
        var timingParts: [(Double, Double)] = []
        if let sd = input.bedtimeSDMin {
            // 20 minutes is about as tight as a real bedtime gets; beyond 110
            // the times describe different schedules rather than one with
            // variation, and there is nothing left to distinguish.
            timingParts.append((0.65, ramp(-sd, worst: -110, best: -20)))
        }
        if let outside = input.bedtimeOutsideMin {
            timingParts.append((0.35, ramp(-outside,
                                           worst: -BedtimePlacement.reachMinutes, best: 0)))
        }
        if !timingParts.isEmpty {
            let total = timingParts.reduce(0) { $0 + $1.0 }
            sections[.timing] = round(timingParts.reduce(0) { $0 + $1.0 * $1.1 } / total)
        }
        if let asleep = input.asleepSec {
            // Asymmetric, deliberately. Symmetric scoring punished ten hours
            // exactly as hard as four, and the evidence does not support that:
            // short sleep is causally harmful and dose-dependent, while the
            // long-sleep hazard is not supported by Mendelian randomisation,
            // largely disappears under accelerometry, and reads as a marker of
            // illness rather than a cause. The research says it plainly — do
            // not tell users that sleeping long is harmful.
            //
            // So the score climbs to the need and then holds. Sleeping more
            // than you need is not a failure to report.
            let shortfall = max(0, input.needSec - asleep)
            sections[.duration] = round(ramp(-shortfall, worst: -(150 * 60), best: 0))
        }
        if let longest = input.longestUnbrokenSec, let bouts = input.wakeBouts {
            // Three views of one question: how much of the night held together.
            // The longest stretch carries most of it — one four-hour block is
            // not eight thirty-minute ones at the same total — then the count
            // of breaks, then the breath.
            //
            // Breath steadiness is here rather than in a section of its own
            // because it measures the same thing from a third channel. It is
            // weighted least of the three: it is ordinal, self-referential, and
            // reads high on nights with real awake time in them.
            var parts: [(Double, Double)] = [
                (0.45, ramp(longest, worst: 45 * 60, best: 180 * 60)),
                (0.35, ramp(Double(-bouts), worst: -12, best: -2)),
            ]
            if let steady = input.steadyFraction {
                parts.append((0.20, ramp(steady, worst: 0.45, best: 0.90)))
            }
            let total = parts.reduce(0) { $0 + $1.0 }
            sections[.continuity] = round(parts.reduce(0) { $0 + $1.0 * $1.1 } / total)
        }
        if let dip = input.hrNadirDip {
            // Depth, then placement, then the night's own vagal level. A nadir
            // that arrives near the middle is the settled pattern; one that
            // arrives near morning is the signature evening load leaves.
            var parts: [(Double, Double)] = [(0.40, ramp(Double(dip), worst: 6, best: 18))]
            if let at = input.hrNadirFraction {
                parts.append((0.20, ramp(-abs(at - 0.45), worst: -0.35, best: 0)))
            }
            // Vagal tone, against this sleeper's own recent nights rather than
            // a population band: their median is 50, thirty per cent above it
            // is 100, thirty per cent below is 0. Nightly RMSSD carries a
            // within-person CV of 27%, so a ±30% span is roughly ±1 SD — wide
            // enough that an ordinary night is not read as a bad one.
            //
            // Absent rather than zero when there is no baseline yet. The parts
            // are weight-normalised below, so a new sleeper is scored on depth
            // and placement alone instead of being marked down for having no
            // history.
            if let dc = input.quietDC, let base = input.quietDCBaseline, base > 0 {
                parts.append((0.25, ramp(Double(dc / base), worst: 0.70, best: 1.30)))
            }
            if let rmssd = input.quietRMSSD, let base = input.quietRMSSDBaseline, base > 0 {
                parts.append((0.15, ramp(Double(rmssd / base), worst: 0.70, best: 1.30)))
            }
            let totalWeight = parts.reduce(0) { $0 + $1.0 }
            sections[.autonomic] = round(parts.reduce(0) { $0 + $1.0 * $1.1 } / totalWeight)
        }

        let present = SleepSection.allCases.filter { sections[$0] != nil }
        let overall: Int?
        if present.count >= SleepThresholds.minSectionsForOverall {
            let weight = present.reduce(0.0) { $0 + $1.weight }
            let sum = present.reduce(0.0) { $0 + $1.weight * Double(sections[$1] ?? 0) }
            overall = Int((sum / weight).rounded())
        } else {
            overall = nil
        }

        // Renormalised weights, so the printed sum actually reaches the
        // headline. Showing the raw weights of a partial set was worse than
        // showing nothing: "46 = 25%·0 + 15%·96 + 20%·67" adds up to 28, and a
        // reader who checks it finds the arithmetic wrong rather than finding
        // out that two sections were missing.
        let liveWeight = present.reduce(0.0) { $0 + $1.weight }
        let line = present
            .map { section -> String in
                let share = liveWeight > 0 ? section.weight / liveWeight : 0
                return "\(Int((share * 100).rounded()))%·\(sections[section] ?? 0) \(section.name.lowercased())"
            }
            .joined(separator: " + ")
        let missing = SleepSection.allCases.filter { sections[$0] == nil }
        let note = missing.isEmpty
            ? ""
            : "  (\(missing.map { $0.name.lowercased() }.joined(separator: " and ")) not measured — "
              + "the rest are reweighted to fill it)"

        return SleepScore(sections: sections,
                          overall: overall,
                          arithmetic: (overall.map { "\($0) = \(line)" } ?? line) + note)
    }

    // MARK: Helpers

    /// Linear between two anchors, clamped. Anchored rather than percentile-
    /// ranked so a first night still scores — the app's own rule that every
    /// section carries a number from day one.
    private static func ramp(_ v: Double, worst: Double, best: Double) -> Double {
        guard best != worst else { return 0 }
        return min(1, max(0, (v - worst) / (best - worst))) * 100
    }

    private static func round(_ v: Double) -> Int { Int(v.rounded()) }
}
