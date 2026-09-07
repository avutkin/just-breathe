import XCTest
@testable import Wythin

final class BedtimeConsistencyTests: XCTestCase {

    /// A night starting at `hour:minute` on `day`, lasting `hours`.
    private func window(day: Int, hour: Int, minute: Int = 0,
                        hours: Double = 8) -> SleepWindow {
        var comps = DateComponents(year: 2026, month: 7, day: day)
        comps.hour = hour
        comps.minute = minute
        let start = Calendar.current.date(from: comps)!
        return SleepWindow(startedAt: start, endedAt: start.addingTimeInterval(hours * 3600))
    }

    // MARK: - The measurement

    func testIdenticalBedtimesHaveNoSpread() {
        let nights = [window(day: 10, hour: 23), window(day: 11, hour: 23),
                      window(day: 12, hour: 23)]
        XCTAssertEqual(BedtimeConsistency.onsetSDMinutes(of: nights) ?? -1, 0, accuracy: 0.5)
    }

    /// The reason this replaced SRI: gaps must cost nothing. Three nights taken
    /// three weeks apart, all at the same hour, describe a person with a fixed
    /// bedtime — not an irregular one, and not an unmeasurable one.
    func testNightsWeeksApartAreAsMeasurableAsConsecutiveOnes() {
        let spread = [window(day: 1, hour: 23), window(day: 11, hour: 23),
                      window(day: 25, hour: 23)]
        let together = [window(day: 1, hour: 23), window(day: 2, hour: 23),
                        window(day: 3, hour: 23)]
        XCTAssertEqual(BedtimeConsistency.onsetSDMinutes(of: spread) ?? -1,
                       BedtimeConsistency.onsetSDMinutes(of: together) ?? -2,
                       accuracy: 0.5,
                       "a gap between nights says nothing about the bedtime on either side")
    }

    /// Clock times wrap. A sleeper who goes to bed either side of midnight is
    /// one of the steadiest there is, and any measure that reads 23:50 and
    /// 00:10 as twenty-three hours apart is broken for most people.
    func testBedtimesEitherSideOfMidnightAreClose() {
        let nights = [window(day: 10, hour: 23, minute: 50),
                      window(day: 12, hour: 0, minute: 10),
                      window(day: 14, hour: 0, minute: 0)]
        guard let sd = BedtimeConsistency.onsetSDMinutes(of: nights) else {
            return XCTFail("three nights is enough to measure")
        }
        XCTAssertLessThan(sd, 20, "these are minutes apart, not most of a day")
    }

    func testAWideningSpreadRaisesTheNumber() {
        let tight = [window(day: 10, hour: 23), window(day: 11, hour: 23, minute: 15),
                     window(day: 12, hour: 22, minute: 45)]
        let loose = [window(day: 10, hour: 21), window(day: 11, hour: 1),
                     window(day: 12, hour: 23)]
        let a = BedtimeConsistency.onsetSDMinutes(of: tight) ?? 0
        let b = BedtimeConsistency.onsetSDMinutes(of: loose) ?? 0
        XCTAssertLessThan(a, b)
        XCTAssertLessThan(a, 30, "a quarter of an hour either way is a steady bedtime")
        XCTAssertGreaterThan(b, 60, "hours apart is not a bedtime, it is three of them")
    }

    // MARK: - What it refuses to answer

    func testTwoNightsIsNotASpread() {
        XCTAssertNil(BedtimeConsistency.onsetSDMinutes(of: [window(day: 10, hour: 23),
                                                            window(day: 11, hour: 23)]),
                     "with two points the spread is half the gap, and one late night reads as a habit")
    }

    func testOneNightIsNotASpread() {
        XCTAssertNil(BedtimeConsistency.onsetSDMinutes(of: [window(day: 10, hour: 23)]))
    }

    func testNoNightsIsNotASpread() {
        XCTAssertNil(BedtimeConsistency.onsetSDMinutes(of: []))
    }

    // MARK: - How it scores

    private func timing(sdMin: Double?) -> Int? {
        var input = SleepScoreInput(bedtimeSDMin: sdMin, asleepSec: 7 * 3600,
                                    needSec: 8 * 3600)
        input.bedtimeSDMin = sdMin
        return SleepScore.compute(input).sections[.timing]
    }

    func testATightBedtimeScoresFull() {
        XCTAssertEqual(timing(sdMin: 12), 100)
    }

    func testAScatteredBedtimeScoresNothing() {
        XCTAssertEqual(timing(sdMin: 140), 0)
    }

    /// The middle has to be usable, or the section is a pass/fail badge. An
    /// hour of spread is common and ordinary and should read as neither.
    func testAnHourOfSpreadLandsInTheMiddle() {
        guard let score = timing(sdMin: 60) else { return XCTFail("scoreable") }
        XCTAssertGreaterThan(score, 35)
        XCTAssertLessThan(score, 70)
    }

    func testWithoutEnoughNightsTimingIsAbsentRatherThanZero() {
        XCTAssertNil(timing(sdMin: nil),
                     "a section with no input is absent — scoring it zero would blame the sleeper "
                     + "for not having worn the strap three times yet")
    }
}
