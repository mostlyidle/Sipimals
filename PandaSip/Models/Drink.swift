import Foundation

enum DrinkKind: String, CaseIterable, Codable, Identifiable {
    case water, coffee, tea, softDrink, juice, milk, sparklingWater, sportsDrink, alcohol

    var id: String { rawValue }

    var name: String {
        switch self {
        case .water: "Water"
        case .coffee: "Coffee"
        case .tea: "Tea"
        case .softDrink: "Soft drink"
        case .juice: "Juice"
        case .milk: "Milk"
        case .sparklingWater: "Sparkling"
        case .sportsDrink: "Sports drink"
        case .alcohol: "Alcohol"
        }
    }

    var symbol: String {
        switch self {
        case .water: "drop.fill"
        case .coffee: "cup.and.saucer.fill"
        case .tea: "mug.fill"
        case .softDrink: "takeoutbag.and.cup.and.straw.fill"
        case .juice: "carrot.fill"
        case .milk: "waterbottle.fill"
        case .sparklingWater: "bubbles.and.sparkles.fill"
        case .sportsDrink: "bolt.fill"
        case .alcohol: "wineglass.fill"
        }
    }

    // Water-content proxies from Maughan et al. (2016), Table 2; alcohol is excluded by app policy.
    var factorPercent: Int {
        switch self {
        case .water, .tea, .sparklingWater: 100
        case .coffee: 99
        case .softDrink, .juice: 89
        case .milk: 88
        case .sportsDrink: 96
        case .alcohol: 0
        }
    }
}

struct DrinkEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let drink: DrinkKind
    let volumeML: Int
    let factorPercent: Int

    init(id: UUID = UUID(), date: Date = .now, drink: DrinkKind, volumeML: Int) {
        self.id = id
        self.date = date
        self.drink = drink
        self.volumeML = volumeML
        self.factorPercent = drink.factorPercent
    }

    var creditedML: Double { Double(volumeML) * Double(factorPercent) / 100 }
}

struct HydrationData: Codable, Equatable {
    var goalML = 2_000
    var entries: [DrinkEntry] = []

    var isValid: Bool {
        (100...10_000).contains(goalML)
            && Set(entries.map(\.id)).count == entries.count
            && entries.allSatisfy {
                (1...5_000).contains($0.volumeML)
                    && (0...100).contains($0.factorPercent)
                    && $0.date.timeIntervalSinceReferenceDate.isFinite
            }
    }

    func entries(on date: Date, calendar: Calendar = .current) -> [DrinkEntry] {
        entries.filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date > $1.date }
    }

    func goalCreditML(on date: Date, calendar: Calendar = .current) -> Int {
        Int(entries(on: date, calendar: calendar).reduce(0) { $0 + $1.creditedML }.rounded())
    }

    func qualifyingDayStreak(calendar: Calendar = .autoupdatingCurrent, through today: Date = .now) -> (current: Int, best: Int) {
        let todayStart = calendar.startOfDay(for: today)
        let days = Set(entries.lazy.filter { $0.creditedML > 0 && $0.date <= today }
            .map { calendar.startOfDay(for: $0.date) }).sorted()
        guard let latest = days.last else { return (0, 0) }

        var best = 1
        var run = 1
        for index in 1..<days.count {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: days[index - 1])
            if let nextDay, calendar.isDate(days[index], inSameDayAs: nextDay) {
                run += 1
                best = max(best, run)
            } else {
                run = 1
            }
        }

        let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart)
        let isCurrent = calendar.isDate(latest, inSameDayAs: todayStart) || yesterday.map { calendar.isDate(latest, inSameDayAs: $0) } == true
        let current = isCurrent ? run : 0
        return (current, best)
    }
}
