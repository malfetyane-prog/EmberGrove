import SwiftUI
import Charts

@MainActor
struct StatsView: View {
    @Environment(GameStore.self) private var store
    private var state: GameState { store.state }
    private let calendar = Calendar.current

    private struct DayCategory: Identifiable {
        let day: Date
        let category: FocusCategory
        let minutes: Int
        var id: String { "\(day.timeIntervalSince1970)-\(category.rawValue)" }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    tiles
                    weekChart
                    categoryChart
                    recordsCard
                    historyCard
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 30)
            }
            .screenBackground()
            .navigationTitle("Statistics")
        }
    }

    private var counted: [FocusRecord] { state.sessions.filter { $0.minutes >= 1 } }
    private var weekMinutes: Int { state.sessions(inWeekOf: .now).reduce(0) { $0 + $1.seconds } / 60 }

    private var tiles: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            StatTile(title: "Today", value: formatMinutes(state.todayMinutes), symbol: "sun.max.fill")
            StatTile(title: "This week", value: formatMinutes(weekMinutes), symbol: "calendar")
            StatTile(title: "Lifetime", value: String(format: "%.1fh", Double(state.totalMinutes) / 60), symbol: "flame.fill")
            StatTile(title: "Sessions", value: "\(counted.count)", symbol: "checkmark.circle.fill")
        }
    }

    private var lastSevenDays: [DayCategory] {
        let today = calendar.startOfDay(for: .now)
        var result: [DayCategory] = []
        for offset in (0..<7).reversed() {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let records = state.sessions(onDay: day)
            for category in FocusCategory.allCases {
                let minutes = records.filter { $0.category == category }.reduce(0) { $0 + $1.seconds } / 60
                result.append(DayCategory(day: day, category: category, minutes: minutes))
            }
        }
        return result
    }

    private var weekChart: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "Last 7 days")
                Chart(lastSevenDays) { item in
                    BarMark(x: .value("Day", item.day, unit: .day), y: .value("Minutes", item.minutes))
                        .foregroundStyle(by: .value("Category", item.category.title))
                        .cornerRadius(5)
                }
                .chartForegroundStyleScale(domain: FocusCategory.allCases.map(\.title),
                                           range: FocusCategory.allCases.map { Color(hex: $0.hex) })
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                    }
                }
                .chartYAxisLabel("min")
                .frame(height: 190)
                if state.settings.dailyGoalMinutes > 0 {
                    Text("Your daily goal is \(formatMinutes(state.settings.dailyGoalMinutes)). Any amount is progress.")
                        .font(.caption).foregroundStyle(Theme.inkSoft)
                }
            }
        }
    }

    private struct CategoryTotal: Identifiable {
        let category: FocusCategory
        let minutes: Int
        var id: FocusCategory { category }
    }

    private var categoryTotals: [CategoryTotal] {
        FocusCategory.allCases
            .map { c in CategoryTotal(category: c, minutes: counted.filter { $0.category == c }.reduce(0) { $0 + $1.seconds } / 60) }
            .filter { $0.minutes > 0 }
    }

    @ViewBuilder
    private var categoryChart: some View {
        if !categoryTotals.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(title: "Where your focus goes")
                    HStack(spacing: 18) {
                        Chart(categoryTotals) { item in
                            SectorMark(angle: .value("Minutes", item.minutes), innerRadius: .ratio(0.62), angularInset: 2)
                                .foregroundStyle(Color(hex: item.category.hex))
                                .cornerRadius(4)
                        }
                        .frame(width: 130, height: 130)
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(categoryTotals) { item in
                                HStack(spacing: 8) {
                                    Circle().fill(Color(hex: item.category.hex)).frame(width: 10, height: 10)
                                    Text(item.category.title).font(.subheadline).foregroundStyle(Theme.ink)
                                    Spacer()
                                    Text(formatMinutes(item.minutes)).font(.caption.monospacedDigit()).foregroundStyle(Theme.inkSoft)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var recordsCard: some View {
        let longest = counted.map(\.minutes).max() ?? 0
        let days = Set(counted.map { calendar.startOfDay(for: $0.start) })
        let byDay = Dictionary(grouping: counted) { calendar.startOfDay(for: $0.start) }
            .mapValues { $0.reduce(0) { $0 + $1.seconds } / 60 }
        let best = byDay.values.max() ?? 0
        let average = days.isEmpty ? 0 : state.totalMinutes / days.count
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "Personal records")
                recordRow("Longest session", formatMinutes(longest), "timer")
                recordRow("Best day", formatMinutes(best), "star.fill")
                recordRow("Days you focused", "\(days.count)", "calendar.badge.checkmark")
                recordRow("Average on focus days", formatMinutes(average), "chart.line.uptrend.xyaxis")
                recordRow("Places restored", "\(state.restored.count)/\(store.content.landmarks.count)", "leaf.fill")
            }
        }
    }

    private func recordRow(_ title: String, _ value: String, _ symbol: String) -> some View {
        HStack {
            Image(systemName: symbol).foregroundStyle(Palette.amber).frame(width: 24)
            Text(title).font(.subheadline).foregroundStyle(Theme.ink)
            Spacer()
            Text(value).font(.label.monospacedDigit()).foregroundStyle(Theme.ink)
        }
        .accessibilityElement(children: .combine)
    }

    private var historyCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "Recent sessions")
                if counted.isEmpty {
                    Text("Your sessions will appear here.").font(.subheadline).foregroundStyle(Theme.inkSoft)
                }
                ForEach(Array(counted.suffix(15).reversed())) { r in
                    HStack(spacing: 12) {
                        Image(systemName: r.category.symbol)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color(hex: r.category.hex)))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(r.category.title).font(.label).foregroundStyle(Theme.ink)
                            Text(r.start, format: .dateTime.weekday(.abbreviated).month().day().hour().minute())
                                .font(.caption).foregroundStyle(Theme.inkSoft)
                        }
                        Spacer()
                        if r.reachedTarget { Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.moss) }
                        Text(formatMinutes(r.minutes)).font(.label.monospacedDigit()).foregroundStyle(Theme.ink)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

@MainActor
struct StatTile: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol).foregroundStyle(Palette.amber)
            Text(value).font(.display(26, weight: .heavy)).foregroundStyle(Theme.ink).minimumScaleFactor(0.7).lineLimit(1)
            Text(title).font(.caption).foregroundStyle(Theme.inkSoft)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.line.opacity(0.7), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}
