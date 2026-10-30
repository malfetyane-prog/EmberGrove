import WidgetKit
import SwiftUI
import ActivityKit

@main
struct EmberGroveWidgets: WidgetBundle {
    var body: some Widget {
        EmberHomeWidget()
        FocusLiveActivity()
    }
}

// MARK: - Home & Lock Screen widget

struct EmberEntry: TimelineEntry {
    let date: Date
    let snapshot: EmberSnapshot
}

struct EmberProvider: TimelineProvider {
    func placeholder(in context: Context) -> EmberEntry {
        EmberEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (EmberEntry) -> Void) {
        completion(EmberEntry(date: .now, snapshot: EmberSnapshot.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EmberEntry>) -> Void) {
        var snap = EmberSnapshot.load() ?? .placeholder
        // "Today" resets at midnight even if the app hasn't been opened.
        if !Calendar.current.isDateInToday(snap.updated) { snap.todayMinutes = 0 }
        let midnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
        var reset = snap
        reset.todayMinutes = 0
        completion(Timeline(entries: [EmberEntry(date: .now, snapshot: snap), EmberEntry(date: midnight, snapshot: reset)],
                            policy: .after(midnight.addingTimeInterval(60))))
    }
}

struct EmberHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "EmberHomeWidget", provider: EmberProvider()) { entry in
            EmberWidgetView(entry: entry)
        }
        .configurationDisplayName("Ember")
        .description("See your companion and today's focus.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

private let widgetBackground = LinearGradient(colors: [Color(hex: 0x2C2145), Color(hex: 0x4A3768)],
                                              startPoint: .top, endPoint: .bottom)

struct EmberWidgetView: View {
    let entry: EmberEntry
    @Environment(\.widgetFamily) private var family

    private var s: EmberSnapshot { entry.snapshot }
    private var goalFraction: Double { min(1, Double(s.todayMinutes) / Double(max(1, s.dailyGoalMinutes))) }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: goalFraction) {
                Image(systemName: "flame.fill")
            } currentValueLabel: {
                Text("\(s.todayMinutes)")
            }
            .gaugeStyle(.accessoryCircular)
            .containerBackground(for: .widget) { Color.clear }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("\(s.name) · Lv \(s.level)").font(.headline)
                Text("\(s.todayMinutes) min focused today")
                ProgressView(value: s.levelProgress)
            }
            .containerBackground(for: .widget) { Color.clear }
        case .systemMedium:
            HStack(spacing: 12) {
                EmberView(appearance: s.appearance, mood: .idle, animated: false)
                    .frame(width: 120, height: 120)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(s.name).font(.system(.title3, design: .rounded, weight: .heavy))
                        Text("Lv \(s.level)")
                            .font(.system(.caption, design: .rounded, weight: .heavy))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Palette.amberGlow))
                            .foregroundStyle(Palette.ink)
                    }
                    Text(s.stageName).font(.caption).foregroundStyle(Palette.lavender)
                    ProgressView(value: s.levelProgress).tint(Palette.amber)
                    HStack {
                        Label("\(s.todayMinutes)/\(s.dailyGoalMinutes)m", systemImage: "flame.fill")
                        Spacer()
                        Label("\(s.restoredCount)/\(s.landmarkCount)", systemImage: "leaf.fill")
                    }
                    .font(.caption.weight(.semibold))
                    if s.pendingChoices > 0 {
                        Text("Something is waiting for you").font(.caption2.weight(.bold)).foregroundStyle(Palette.amberGlow)
                    }
                }
                .foregroundStyle(Palette.cream)
            }
            .containerBackground(for: .widget) { widgetBackground }
        default:
            VStack(spacing: 2) {
                EmberView(appearance: s.appearance, mood: .idle, animated: false)
                    .frame(width: 92, height: 92)
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").foregroundStyle(Palette.amber)
                    Text("\(s.todayMinutes)m today").font(.system(.caption, design: .rounded, weight: .bold))
                }
                .foregroundStyle(Palette.cream)
                ProgressView(value: goalFraction).tint(Palette.amber)
            }
            .containerBackground(for: .widget) { widgetBackground }
        }
    }
}

// MARK: - Live Activity

struct FocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            HStack(spacing: 14) {
                EmberView(appearance: context.attributes.appearance,
                          mood: context.state.pausedElapsed == nil ? .focused : .sleepy, animated: false)
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Label(context.state.categoryTitle, systemImage: context.state.categorySymbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.lavender)
                    TimerText(state: context.state, attributes: context.attributes)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Palette.cream)
                    SessionProgress(state: context.state, attributes: context.attributes)
                }
            }
            .padding(16)
            .activityBackgroundTint(Color(hex: 0x2C2145))
            .activitySystemActionForegroundColor(Palette.amber)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    EmberView(appearance: context.attributes.appearance, mood: .focused, animated: false)
                        .frame(width: 52, height: 52)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TimerText(state: context.state, attributes: context.attributes)
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .frame(maxWidth: 110)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.pausedElapsed == nil ? "\(context.attributes.emberName) is tending the fire" : "Paused")
                        .font(.caption).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    SessionProgress(state: context.state, attributes: context.attributes)
                }
            } compactLeading: {
                EmberView(appearance: context.attributes.appearance, mood: .focused, animated: false)
                    .frame(width: 24, height: 24)
            } compactTrailing: {
                TimerText(state: context.state, attributes: context.attributes)
                    .monospacedDigit()
                    .frame(maxWidth: 52)
                    .foregroundStyle(Palette.amber)
            } minimal: {
                Image(systemName: "flame.fill").foregroundStyle(Palette.amber)
            }
            .keylineTint(Palette.amber)
        }
    }
}

/// Lets the system tick the timer, so it stays accurate without the app running.
struct TimerText: View {
    let state: FocusActivityAttributes.ContentState
    let attributes: FocusActivityAttributes

    var body: some View {
        if let paused = state.pausedElapsed {
            let shown = attributes.targetDuration.map { max(0, $0 - paused) } ?? paused
            Text(format(shown))
        } else if let end = state.endDate {
            Text(timerInterval: state.timerStart...end, countsDown: true)
        } else {
            Text(state.timerStart, style: .timer)
        }
    }

    private func format(_ t: TimeInterval) -> String {
        let total = Int(t)
        return total >= 3600
            ? String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
            : String(format: "%02d:%02d", total / 60, total % 60)
    }
}

struct SessionProgress: View {
    let state: FocusActivityAttributes.ContentState
    let attributes: FocusActivityAttributes

    var body: some View {
        if let end = state.endDate {
            ProgressView(timerInterval: state.timerStart...end, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                .tint(Palette.amber)
        } else if let paused = state.pausedElapsed, let target = attributes.targetDuration {
            ProgressView(value: min(1, paused / target)).tint(Palette.amber)
        }
    }
}
