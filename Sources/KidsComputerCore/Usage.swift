import Foundation

public enum DayKey {
    public static func make(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

public enum UsagePhase: Equatable {
    case unlimited
    case ok
    case warning(secondsRemaining: Int)
    case exhausted

    public static func make(limitMinutes: Int?, usedSeconds: Int, warnBeforeMinutes: Int) -> UsagePhase {
        guard let limitMinutes, limitMinutes > 0 else { return .unlimited }
        let remaining = limitMinutes * 60 - max(0, usedSeconds)
        if remaining <= 0 { return .exhausted }
        let warnSeconds = max(0, warnBeforeMinutes) * 60
        if warnSeconds > 0 && remaining <= warnSeconds {
            return .warning(secondsRemaining: remaining)
        }
        return .ok
    }
}

public enum TileFace: Equatable {
    case ready(minutesRemaining: Int?)
    case comingSoon
    case doneForToday
    case turnedOff
}

public func makeTileFace(tile: Tile, isInstalled: Bool, usedSeconds: Int, warnBeforeMinutes: Int) -> TileFace {
    if !tile.enabled { return .turnedOff }
    if !isInstalled { return .comingSoon }
    let phase = UsagePhase.make(
        limitMinutes: tile.dailyLimitMinutes,
        usedSeconds: usedSeconds,
        warnBeforeMinutes: warnBeforeMinutes
    )
    if phase == .exhausted { return .doneForToday }
    guard let limit = tile.dailyLimitMinutes, limit > 0 else {
        return .ready(minutesRemaining: nil)
    }
    let remaining = max(0, limit * 60 - max(0, usedSeconds))
    let minutes = max(1, Int((Double(remaining) / 60.0).rounded(.up)))
    return .ready(minutesRemaining: minutes)
}

public struct UsageLog: Codable, Equatable {
    public struct Day: Codable, Equatable {
        public var day: String
        public var seconds: [String: Int]

        public init(day: String, seconds: [String: Int]) {
            self.day = day
            self.seconds = seconds
        }
    }

    public var days: [Day]

    public init(days: [Day] = []) {
        self.days = days
    }

    public func seconds(for tileID: String, on day: String) -> Int {
        days.first { $0.day == day }?.seconds[tileID] ?? 0
    }

    public mutating func add(seconds: Int, to tileID: String, on day: String) {
        guard seconds > 0, !tileID.isEmpty, !day.isEmpty else { return }
        if let index = days.firstIndex(where: { $0.day == day }) {
            days[index].seconds[tileID, default: 0] += seconds
        } else {
            days.append(Day(day: day, seconds: [tileID: seconds]))
        }
    }

    public mutating func addInterval(
        tileID: String,
        from start: Date,
        to end: Date,
        calendar: Calendar,
        maxSeconds: Int? = nil
    ) {
        guard end > start else { return }
        var stop = end
        if let maxSeconds {
            let capped = start.addingTimeInterval(TimeInterval(max(0, maxSeconds)))
            if stop > capped { stop = capped }
        }
        var cursor = start
        var hops = 0
        while cursor < stop && hops < 4000 {
            hops += 1
            let dayStart = calendar.startOfDay(for: cursor)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return }
            let sliceEnd = min(stop, nextDay)
            let seconds = Int(sliceEnd.timeIntervalSince(cursor).rounded(.down))
            if seconds > 0 {
                add(seconds: seconds, to: tileID, on: DayKey.make(cursor, calendar: calendar))
            }
            if sliceEnd <= cursor { return }
            cursor = sliceEnd
        }
    }

    public mutating func prune(keepingNewest count: Int) {
        guard days.count > count else { return }
        let newest = days.sorted { $0.day > $1.day }.prefix(count)
        days = newest.sorted { $0.day < $1.day }
    }
}

public enum UsageEvent: Equatable {
    case warn(tileID: String, secondsRemaining: Int)
    case exhausted(tileID: String)
}

public struct UsageMonitor: Equatable {
    public var log: UsageLog
    public private(set) var frontTileID: String?
    public private(set) var lastSample: Date?
    public private(set) var warnedKeys: Set<String>

    public static let maxCountedGapSeconds = 30

    public init(log: UsageLog = UsageLog(), warnedKeys: Set<String> = []) {
        self.log = log
        self.frontTileID = nil
        self.lastSample = nil
        self.warnedKeys = warnedKeys
    }

    public mutating func noteClockGap() {
        lastSample = nil
    }

    public mutating func setFrontmost(
        _ tileID: String?,
        at date: Date,
        limits: [String: Int?],
        warnBeforeMinutes: Int,
        calendar: Calendar
    ) -> [UsageEvent] {
        let flushed = flush(until: date, limits: limits, warnBeforeMinutes: warnBeforeMinutes, calendar: calendar)
        frontTileID = tileID
        lastSample = date
        guard let tileID else { return flushed }
        return flushed + evaluate(
            tileID: tileID,
            at: date,
            limits: limits,
            warnBeforeMinutes: warnBeforeMinutes,
            calendar: calendar
        )
    }

    public mutating func sample(
        at date: Date,
        limits: [String: Int?],
        warnBeforeMinutes: Int,
        calendar: Calendar
    ) -> [UsageEvent] {
        flush(until: date, limits: limits, warnBeforeMinutes: warnBeforeMinutes, calendar: calendar)
    }

    private mutating func flush(
        until date: Date,
        limits: [String: Int?],
        warnBeforeMinutes: Int,
        calendar: Calendar
    ) -> [UsageEvent] {
        guard let lastSample, let frontTileID else {
            self.lastSample = date
            return []
        }
        guard date > lastSample else { return [] }
        log.addInterval(
            tileID: frontTileID,
            from: lastSample,
            to: date,
            calendar: calendar,
            maxSeconds: Self.maxCountedGapSeconds
        )
        self.lastSample = date
        return evaluate(
            tileID: frontTileID,
            at: date,
            limits: limits,
            warnBeforeMinutes: warnBeforeMinutes,
            calendar: calendar
        )
    }

    private mutating func evaluate(
        tileID: String,
        at date: Date,
        limits: [String: Int?],
        warnBeforeMinutes: Int,
        calendar: Calendar
    ) -> [UsageEvent] {
        guard let limit = limits[tileID] ?? nil, limit > 0 else { return [] }
        let day = DayKey.make(date, calendar: calendar)
        let used = log.seconds(for: tileID, on: day)
        switch UsagePhase.make(limitMinutes: limit, usedSeconds: used, warnBeforeMinutes: warnBeforeMinutes) {
        case .exhausted:
            frontTileID = nil
            return [.exhausted(tileID: tileID)]
        case .warning(let remaining):
            let key = "\(tileID)|\(day)"
            if warnedKeys.contains(key) { return [] }
            warnedKeys.insert(key)
            return [.warn(tileID: tileID, secondsRemaining: remaining)]
        case .ok, .unlimited:
            return []
        }
    }
}
