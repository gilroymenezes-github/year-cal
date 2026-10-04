import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Navigation state (lives in the widget extension's own defaults)

enum NavState {
    private static let yearKey = "yearOffset"
    private static let monthKey = "monthOffset"

    static var yearOffset: Int {
        get { UserDefaults.standard.integer(forKey: yearKey) }
        set { UserDefaults.standard.set(newValue, forKey: yearKey) }
    }

    static var monthOffset: Int {
        get { UserDefaults.standard.integer(forKey: monthKey) }
        set { UserDefaults.standard.set(newValue, forKey: monthKey) }
    }
}

/// Moves the year widgets back or forward a year. Delta 0 jumps back to this year.
struct ShiftYearIntent: AppIntent {
    static var title: LocalizedStringResource = "Change Year"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Delta")
    var delta: Int

    init() {}
    init(delta: Int) { self.delta = delta }

    func perform() async throws -> some IntentResult {
        NavState.yearOffset = (delta == 0) ? 0 : NavState.yearOffset + delta
        return .result()
    }
}

/// Slides the Three Months widget by a month. Delta 0 jumps back to the current month.
struct ShiftMonthIntent: AppIntent {
    static var title: LocalizedStringResource = "Change Month"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Delta")
    var delta: Int

    init() {}
    init(delta: Int) { self.delta = delta }

    func perform() async throws -> some IntentResult {
        NavState.monthOffset = (delta == 0) ? 0 : NavState.monthOffset + delta
        return .result()
    }
}

// MARK: - Background style (chosen per widget via right-click → Edit Widget)

enum WidgetBackground: String, AppEnum {
    case clear, smoke, solid

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Background"
    static var caseDisplayRepresentations: [WidgetBackground: DisplayRepresentation] = [
        .clear: "Clear",
        .smoke: "Smoke (neutral dark glass)",
        .solid: "Solid",
    ]
}

struct StyleIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Widget Style"
    static var description = IntentDescription("Choose how the calendar sits on your desktop.")

    @Parameter(title: "Background", default: .clear)
    var background: WidgetBackground

    init() {}
}

/// Applies the chosen background. Clear = no backing at all, white digits with a soft
/// shadow so they read over any wallpaper; Smoke = neutral dark tint that cancels colour
/// cast; Solid = opaque window background.
struct Styled<Content: View>: View {
    let style: WidgetBackground
    @ViewBuilder let content: () -> Content

    var body: some View {
        switch style {
        case .clear:
            content()
                .environment(\.colorScheme, .dark)
                .shadow(color: .black.opacity(0.75), radius: 1.2, x: 0, y: 0.5)
                .containerBackground(for: .widget) { Color.clear }
        case .smoke:
            content()
                .environment(\.colorScheme, .dark)
                .containerBackground(for: .widget) { Color.black.opacity(0.55) }
        case .solid:
            content()
                .containerBackground(for: .widget) { Color(nsColor: .windowBackgroundColor) }
        }
    }
}

// MARK: - Timeline

struct DayEntry: TimelineEntry {
    let date: Date
    let yearOffset: Int
    let monthOffset: Int
    var style: WidgetBackground = .clear

    var shownYear: Int { MonthPicker.currentYear(date) + yearOffset }
    var isCurrentYear: Bool { yearOffset == 0 }
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DayEntry {
        DayEntry(date: Date(), yearOffset: 0, monthOffset: 0)
    }

    func snapshot(for configuration: StyleIntent, in context: Context) async -> DayEntry {
        if context.isPreview {
            return DayEntry(date: Date(), yearOffset: 0, monthOffset: 0, style: configuration.background)
        }
        return DayEntry(date: Date(), yearOffset: NavState.yearOffset,
                        monthOffset: NavState.monthOffset, style: configuration.background)
    }

    /// One entry now, then one at each of the next 7 midnights, so "today" stays correct.
    func timeline(for configuration: StyleIntent, in context: Context) async -> Timeline<DayEntry> {
        let cal = Calendar.current
        let now = Date()
        let y = NavState.yearOffset
        let m = NavState.monthOffset
        let style = configuration.background
        var entries = [DayEntry(date: now, yearOffset: y, monthOffset: m, style: style)]
        var midnight = cal.startOfDay(for: now)
        for _ in 0..<7 {
            guard let next = cal.date(byAdding: .day, value: 1, to: midnight) else { break }
            midnight = next
            entries.append(DayEntry(date: midnight.addingTimeInterval(1), yearOffset: y,
                                    monthOffset: m, style: style))
        }
        return Timeline(entries: entries, policy: .atEnd)
    }
}

// MARK: - Headers

private struct NavArrow: View {
    let systemName: String
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 11, weight: .semibold))
            .frame(width: 20, height: 18)
            .contentShape(Rectangle())
    }
}

struct YearNavHeader: View {
    let entry: DayEntry
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            Button(intent: ShiftYearIntent(delta: -1)) { NavArrow(systemName: "chevron.left") }
                .buttonStyle(.plain)

            // Tapping the year jumps back to the current year.
            Button(intent: ShiftYearIntent(delta: 0)) {
                Text(String(entry.shownYear))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(entry.isCurrentYear ? Color.primary : Color.accentColor)
            }
            .buttonStyle(.plain)

            Button(intent: ShiftYearIntent(delta: 1)) { NavArrow(systemName: "chevron.right") }
                .buttonStyle(.plain)

            Spacer()

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.secondary)
    }
}

struct MonthNavHeader: View {
    let entry: DayEntry
    let months: [MonthRef]

    private var rangeText: String {
        guard let first = months.first, let last = months.last else { return "" }
        let symbols = Calendar.current.shortStandaloneMonthSymbols
        let a = symbols[first.month - 1], b = symbols[last.month - 1]
        return first.year == last.year
            ? "\(a) – \(b) \(last.year)"
            : "\(a) \(first.year) – \(b) \(last.year)"
    }

    var body: some View {
        HStack(spacing: 4) {
            Button(intent: ShiftMonthIntent(delta: -1)) { NavArrow(systemName: "chevron.left") }
                .buttonStyle(.plain)

            // Tapping the range jumps back to the current month.
            Button(intent: ShiftMonthIntent(delta: 0)) {
                Text(rangeText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(entry.monthOffset == 0 ? Color.secondary : Color.accentColor)
            }
            .buttonStyle(.plain)

            Button(intent: ShiftMonthIntent(delta: 1)) { NavArrow(systemName: "chevron.right") }
                .buttonStyle(.plain)

            Spacer()
        }
        .foregroundStyle(.secondary)
    }
}

// MARK: - Year Calendar: large = 3 × 4; extra-large portrait (macOS 27+) = 2 × 7 with Dec/Jan bookends

struct YearCalView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DayEntry

    private var isPortraitXL: Bool {
        if #available(macOS 27.0, *) {
            return family == .systemExtraLargePortrait
        }
        return false
    }

    var body: some View {
        if isPortraitXL {
            MonthsGrid(months: MonthPicker.withBookends(entry.shownYear), columns: 2,
                       today: entry.date, focusYear: entry.shownYear,
                       textScale: 0.6, headerHeight: 24) {
                YearNavHeader(entry: entry, subtitle: "Dec – Jan")
            }
        } else {
            MonthsGrid(months: MonthPicker.fullYear(entry.shownYear), columns: 3,
                       today: entry.date, headerHeight: 22) {
                YearNavHeader(entry: entry)
            }
        }
    }
}

private var yearFamilies: [WidgetFamily] {
    if #available(macOS 27.0, *) {
        return [.systemLarge, .systemExtraLargePortrait]
    }
    return [.systemLarge]
}

struct YearCalWidget: Widget {
    let kind = "YearCalWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: StyleIntent.self, provider: Provider()) { entry in
            Styled(style: entry.style) {
            YearCalView(entry: entry)
                }
        }
        .configurationDisplayName("Year Calendar")
        .description("The whole year with ‹ › to change year. Large: 3 per row. Extra-large portrait: 2 per row, Dec to Jan.")
        .supportedFamilies(yearFamilies)
    }
}

// MARK: - Half years: 2 months per row, 3 rows. Stack both for a 2 × 6 year.

struct FirstHalfWidget: Widget {
    let kind = "YearCalFirstHalf"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: StyleIntent.self, provider: Provider()) { entry in
            Styled(style: entry.style) {
            MonthsGrid(months: MonthPicker.half(false, year: entry.shownYear), columns: 2,
                       today: entry.date, headerHeight: 22) {
                YearNavHeader(entry: entry, subtitle: "Jan – Jun")
            }
            }
        }
        .configurationDisplayName("Year Calendar · Jan–Jun")
        .description("January to June, 2 per row. Stack with Jul–Dec for the full year.")
        .supportedFamilies([.systemLarge])
    }
}

struct SecondHalfWidget: Widget {
    let kind = "YearCalSecondHalf"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: StyleIntent.self, provider: Provider()) { entry in
            Styled(style: entry.style) {
            MonthsGrid(months: MonthPicker.half(true, year: entry.shownYear), columns: 2,
                       today: entry.date, headerHeight: 22) {
                YearNavHeader(entry: entry, subtitle: "Jul – Dec")
            }
            }
        }
        .configurationDisplayName("Year Calendar · Jul–Dec")
        .description("July to December, 2 per row. Stack under Jan–Jun for the full year.")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - Three months: sliding window, ‹ › moves one month

struct ThreeMonthsWidget: Widget {
    let kind = "YearCalThreeMonths"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: StyleIntent.self, provider: Provider()) { entry in
            Styled(style: entry.style) {
            let months = MonthPicker.around(entry.date, offset: entry.monthOffset)
            MonthsGrid(months: months, columns: 3, today: entry.date,
                       textScale: 0.62, hSpacing: 8, headerHeight: 20) {
                MonthNavHeader(entry: entry, months: months)
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 8)
            }
        }
        .contentMarginsDisabled()
        .configurationDisplayName("Three Months")
        .description("A sliding three-month window. ‹ › moves one month; tap the range to come back.")
        .supportedFamilies([.systemMedium])
    }
}

@main
struct YearCalWidgetBundle: WidgetBundle {
    var body: some Widget {
        YearCalWidget()
        FirstHalfWidget()
        SecondHalfWidget()
        ThreeMonthsWidget()
    }
}
