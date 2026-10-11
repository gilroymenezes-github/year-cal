import SwiftUI
import WidgetKit

/// A (year, month) pair to render.
struct MonthRef: Hashable {
    let year: Int
    let month: Int
}

/// Grid of months laid out to fill the space it is given exactly.
/// Used by both the widgets and the menu bar panel.
struct MonthsGrid<Header: View>: View {
    let months: [MonthRef]
    let columns: Int
    let today: Date
    /// Months outside this year are dimmed (e.g. the Dec/Jan bookends).
    let focusYear: Int?
    let headerHeight: CGFloat
    let header: Header
    /// How much of a day cell's width the digits may use (0.5 default; higher = bigger text).
    var textScale: CGFloat = 0.5
    var hSpacingOverride: CGFloat? = nil
    /// Show a week-number column on the left of each month.
    var weekNumbers: Bool = false

    init(months: [MonthRef], columns: Int, today: Date, focusYear: Int? = nil,
         textScale: CGFloat = 0.5, hSpacing: CGFloat? = nil, weekNumbers: Bool = false,
         headerHeight: CGFloat, @ViewBuilder header: () -> Header) {
        self.months = months
        self.columns = columns
        self.today = today
        self.focusYear = focusYear
        self.textScale = textScale
        self.hSpacingOverride = hSpacing
        self.weekNumbers = weekNumbers
        self.headerHeight = headerHeight
        self.header = header()
    }

    private var rows: Int {
        Int((Double(months.count) / Double(columns)).rounded(.up))
    }

    var body: some View {
        GeometryReader { geo in
            let hSpacing: CGFloat = hSpacingOverride ?? (columns >= 3 ? 10 : 14)
            let vSpacing: CGFloat = rows >= 4 ? 4 : 8
            let cellW = (geo.size.width - hSpacing * CGFloat(columns - 1)) / CGFloat(columns)
            let cellH = (geo.size.height - headerHeight - vSpacing * CGFloat(rows - 1)) / CGFloat(rows)

            VStack(alignment: .leading, spacing: 0) {
                if headerHeight > 0 {
                    header.frame(height: headerHeight, alignment: .top)
                }
                VStack(alignment: .leading, spacing: vSpacing) {
                    ForEach(0..<rows, id: \.self) { r in
                        HStack(spacing: hSpacing) {
                            ForEach(0..<columns, id: \.self) { c in
                                let i = r * columns + c
                                Group {
                                    if i < months.count {
                                        MonthView(ref: months[i], today: today,
                                                  outsideYear: focusYear.map { $0 != months[i].year } ?? false,
                                                  textScale: textScale,
                                                  weekNumbers: weekNumbers)
                                    } else {
                                        Color.clear
                                    }
                                }
                                .frame(width: max(cellW, 0), height: max(cellH, 0))
                            }
                        }
                    }
                }
            }
        }
    }
}

extension MonthsGrid where Header == EmptyView {
    init(months: [MonthRef], columns: Int, today: Date, focusYear: Int? = nil,
         textScale: CGFloat = 0.5, hSpacing: CGFloat? = nil, weekNumbers: Bool = false) {
        self.init(months: months, columns: columns, today: today, focusYear: focusYear,
                  textScale: textScale, hSpacing: hSpacing, weekNumbers: weekNumbers,
                  headerHeight: 0) { EmptyView() }
    }
}

/// A single mini month: name, weekday initials, 6 week rows.
struct MonthView: View {
    let ref: MonthRef
    let today: Date
    var outsideYear: Bool = false
    var textScale: CGFloat = 0.5
    var weekNumbers: Bool = false

    private var calendar: Calendar { Calendar.current }

    private var monthName: String {
        let symbols = calendar.standaloneMonthSymbols
        let name = symbols[(ref.month - 1) % symbols.count]
        return outsideYear ? "\(name) \(ref.year)" : name
    }

    private var isCurrentMonth: Bool {
        calendar.component(.year, from: today) == ref.year &&
        calendar.component(.month, from: today) == ref.month
    }

    private var todayDay: Int? {
        isCurrentMonth ? calendar.component(.day, from: today) : nil
    }

    /// Weekday initials ordered by the user's first weekday.
    private var weekdayInitials: [String] {
        let s = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(s[first...] + s[..<first])
    }

    /// Week number for each of the 6 rows (nil for an empty trailing row), using the
    /// user's calendar so numbering matches the row's first weekday.
    private var weekNumbersByRow: [Int?] {
        var comps = DateComponents()
        comps.year = ref.year
        comps.month = ref.month
        comps.day = 1
        let days = slots
        guard let first = calendar.date(from: comps) else { return Array(repeating: nil, count: 6) }
        return (0..<6).map { row in
            guard let day = days[(row * 7)..<(row * 7 + 7)].compactMap({ $0 }).first,
                  let date = calendar.date(byAdding: .day, value: day - 1, to: first) else { return nil }
            return calendar.component(.weekOfYear, from: date)
        }
    }

    /// 42 slots (6 weeks x 7); nil for blanks.
    private var slots: [Int?] {
        var comps = DateComponents()
        comps.year = ref.year
        comps.month = ref.month
        comps.day = 1
        guard let first = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: first) else {
            return Array(repeating: nil, count: 42)
        }
        let weekday = calendar.component(.weekday, from: first)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        var result: [Int?] = Array(repeating: nil, count: offset)
        result += range.map { Optional($0) }
        while result.count < 42 { result.append(nil) }
        return result
    }

    var body: some View {
        GeometryReader { geo in
            // Rows: month name (1.1), weekday initials (0.9), 6 weeks (1 each) = 8 units.
            let unit = geo.size.height / 8
            // Week-number column is 0.8 of a day column.
            let wkW: CGFloat = weekNumbers ? geo.size.width / 7.8 * 0.8 : 0
            let cellW = (geo.size.width - wkW) / 7
            let fontSize = max(6, min(cellW * textScale, unit * 0.74))
            let days = slots
            let todayDay = todayDay
            let weeks = weekNumbers ? weekNumbersByRow : []

            VStack(spacing: 0) {
                Text(monthName)
                    .font(.system(size: fontSize * (weekNumbers ? 0.82 : 1.1), weight: .semibold, design: .rounded))
                    .foregroundStyle(isCurrentMonth ? AnyShapeStyle(Color.accentColor)
                                     : (weekNumbers ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.primary)))
                    .widgetAccentableIfAvailable(isCurrentMonth)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.leading, cellW * 0.15)
                    .frame(width: geo.size.width, height: unit * 1.1, alignment: .leading)

                HStack(spacing: 0) {
                    if weekNumbers {
                        Text("W")
                            .font(.system(size: fontSize * 0.82, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .frame(width: wkW, height: unit * 0.9)
                    }
                    ForEach(Array(weekdayInitials.enumerated()), id: \.offset) { _, s in
                        Text(s)
                            .font(.system(size: fontSize * 0.82, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(width: cellW, height: unit * 0.9)
                    }
                }

                ForEach(0..<6, id: \.self) { week in
                    HStack(spacing: 0) {
                        if weekNumbers {
                            Text(weeks[week].map(String.init) ?? "")
                                // Week numbers are the prominent numbers in this layout.
                                .font(.system(size: fontSize * 0.82, weight: .regular))
                                .monospacedDigit()
                                .foregroundStyle(Color.primary)
                                .frame(width: wkW, height: unit)
                        }
                        ForEach(0..<7, id: \.self) { d in
                            let day = days[week * 7 + d]
                            DayCell(day: day,
                                    isToday: day != nil && day == todayDay,
                                    fontSize: weekNumbers ? fontSize * 0.62 : fontSize,
                                    faint: weekNumbers,
                                    width: cellW,
                                    height: unit)
                        }
                    }
                }
            }
            .opacity(outsideYear ? 0.45 : 1)
        }
    }
}

private struct DayCell: View {
    let day: Int?
    let isToday: Bool
    let fontSize: CGFloat
    /// Dates are drawn small and faint (today stays bright) when week numbers take the lead.
    var faint: Bool = false
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Group {
            if let day {
                Text(String(day))
                    .font(.system(size: fontSize, weight: isToday ? .bold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(faint && !isToday ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.primary))
                    .fixedSize()
                    .frame(width: width, height: height)
                    .background {
                        if isToday {
                            // Outline (not filled) so the number keeps full contrast even when
                            // macOS renders widgets on translucent glass. Rounded rectangle that
                            // fills most of the day cell.
                            RoundedRectangle(cornerRadius: min(width, height) * 0.24, style: .continuous)
                                // Same subtle shade as the week numbers.
                                .strokeBorder(.tertiary, lineWidth: max(1.5, fontSize * 0.11))
                                .frame(width: width * 0.94, height: height * 0.9)
                        }
                    }
            } else {
                Color.clear.frame(width: width, height: height)
            }
        }
    }
}

extension View {
    @ViewBuilder
    func widgetAccentableIfAvailable(_ on: Bool) -> some View {
        if on {
            self.widgetAccentable()
        } else {
            self
        }
    }
}

/// Helpers for picking which months to show.
enum MonthPicker {
    static func currentYear(_ date: Date = Date()) -> Int {
        Calendar.current.component(.year, from: date)
    }

    static func fullYear(_ y: Int) -> [MonthRef] {
        (1...12).map { MonthRef(year: y, month: $0) }
    }

    /// January–June (first) or July–December (second).
    static func half(_ second: Bool, year y: Int) -> [MonthRef] {
        let start = second ? 7 : 1
        return (start..<(start + 6)).map { MonthRef(year: y, month: $0) }
    }

    /// December of the previous year, the whole year, then January of the next: 14 months.
    static func withBookends(_ y: Int) -> [MonthRef] {
        [MonthRef(year: y - 1, month: 12)] + fullYear(y) + [MonthRef(year: y + 1, month: 1)]
    }

    /// Three consecutive months centred on today's month shifted by `offset` months.
    static func around(_ date: Date, offset: Int = 0) -> [MonthRef] {
        let cal = Calendar.current
        return (-1...1).compactMap { delta in
            guard let d = cal.date(byAdding: .month, value: delta + offset, to: date) else { return nil }
            return MonthRef(year: cal.component(.year, from: d), month: cal.component(.month, from: d))
        }
    }
}
