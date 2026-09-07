import Foundation

/// How tightly clustered the hour of falling asleep is, across whatever nights
/// were recorded — consecutive or not.
///
/// **This replaced the Sleep Regularity Index, and the reason is the device.**
/// SRI compares every minute of the day against the same minute 24 h earlier
/// and scores the agreement. That makes it a superb measure — it is the one
/// sleep number that beat duration head-to-head in 60,977 UK Biobank
/// participants — and a measure of *daily wear* just as much as of the sleeper.
/// A night the strap was not worn has no sleep in it, so it reads as a night
/// spent entirely awake, and every minute of it disagrees with the night
/// before. On a chest strap somebody puts on for a study of a few nights rather
/// than every night of their life, SRI does not report an irregular sleeper. It
/// reports an intermittent wearer, in a number indistinguishable from the
/// first.
///
/// Bedtime consistency asks the question intermittent wear can answer: of the
/// nights we did record, how close together was the time you fell asleep? A gap
/// between two nights costs nothing, because each night contributes one instant
/// and says nothing about the days around it. Three nights across three weeks
/// are as answerable as three in a row.
///
/// Circular statistics throughout, because clock times wrap. 23:50 and 00:10
/// are twenty minutes apart, and any measure that reports them as twenty-three
/// hours and forty is broken for exactly the people who go to bed near
/// midnight — which is most of them.
enum BedtimeConsistency {

    /// A spread needs three points to mean anything. With two, the "spread" is
    /// just half the gap between them, and one late night would read as a
    /// permanent habit.
    static let minNights = 3

    /// Circular standard deviation of sleep onset, in minutes.
    ///
    /// Nil until there are enough nights. The caller shows how many it had —
    /// a consistency figure without its sample size invites more confidence
    /// than three nights can carry.
    static func onsetSDMinutes(of windows: [SleepWindow]) -> Double? {
        guard windows.count >= minNights else { return nil }

        let cal = Calendar.current
        var sumSin = 0.0, sumCos = 0.0
        for w in windows {
            let comps = cal.dateComponents([.hour, .minute, .second], from: w.startedAt)
            let seconds = Double((comps.hour ?? 0) * 3600 + (comps.minute ?? 0) * 60
                                 + (comps.second ?? 0))
            let angle = 2 * .pi * seconds / 86_400
            sumSin += sin(angle)
            sumCos += cos(angle)
        }
        let n = Double(windows.count)
        // Mean resultant length: 1 when every night landed on the same minute,
        // 0 when they are scattered evenly round the clock.
        let r = (sumSin * sumSin + sumCos * sumCos).squareRoot() / n
        guard r > 0 else { return nil }          // perfectly opposed: no centre to speak of
        // Yamartino / Mardia circular SD. Clamped because floating point can
        // put r a hair above 1 when every angle is identical, and log of that
        // is a negative zero the square root would turn into a NaN.
        let radians = (-2 * log(min(1, r))).squareRoot()
        return radians * 86_400 / (2 * .pi) / 60
    }
}
