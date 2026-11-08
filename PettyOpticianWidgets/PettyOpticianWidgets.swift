import SwiftUI
import WidgetKit

@main
struct PettyOpticianWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyQuestionWidget()
        CountdownWidget()
    }
}

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry { SnapshotEntry(date: .now, snapshot: .placeholder) }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: context.isPreview ? .placeholder : WidgetSnapshot.load() ?? .placeholder))
    }

    /// The app reloads the widgets whenever progress changes; the midnight refresh rolls the countdown and daily question.
    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let midnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
        completion(Timeline(entries: [SnapshotEntry(date: .now, snapshot: WidgetSnapshot.load() ?? .placeholder)], policy: .after(midnight)))
    }
}

private let teal = Color(red: 0x0F / 255, green: 0x7A / 255, blue: 0x8A / 255)

struct DailyQuestionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DailyQuestion", provider: SnapshotProvider()) { entry in
            DailyQuestionView(snapshot: entry.snapshot)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Question of the Day")
        .description("Today's question. Tap to answer it in the app.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private struct DailyQuestionView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let daily = snapshot.daily {
            VStack(alignment: .leading, spacing: 6) {
                Label("Question of the Day · \(snapshot.exam)", systemImage: "questionmark.bubble")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(teal)
                Text(daily.stem)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(family == .systemLarge ? 5 : 3)
                if family == .systemLarge {
                    ForEach(Array(daily.choices.enumerated()), id: \.offset) { index, choice in
                        Text("\(["A", "B", "C", "D"][index]). \(choice)").font(.caption).lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                Text("Tap to answer").font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(URL(string: "pettyoptician://daily"))
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Label("Question of the Day", systemImage: "questionmark.bubble").font(.caption.weight(.semibold)).foregroundStyle(teal)
                Text("Open petty: Optician to get today's question.").font(.subheadline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct CountdownWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Countdown", provider: SnapshotProvider()) { entry in
            CountdownView(snapshot: entry.snapshot)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "pettyoptician://today"))
        }
        .configurationDisplayName("Exam Countdown")
        .description("Days until your exam, plus cards and missed questions due today.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

private struct CountdownView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    private var countdown: String {
        guard let days = snapshot.daysUntilExam else { return "No date" }
        return days <= 0 ? "Today" : "\(days) d"
    }

    private var due: String { "\(snapshot.cardsDue) cards · \(snapshot.recheckDue) re-check" }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("\(snapshot.exam) \(countdown) · \(snapshot.cardsDue) cards")
        case .accessoryCircular:
            Gauge(value: snapshot.readiness) {
                Text(snapshot.exam)
            } currentValueLabel: {
                Text(snapshot.daysUntilExam.map { "\(max(0, $0))" } ?? "–")
            }
            .gaugeStyle(.accessoryCircularCapacity)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text("\(snapshot.exam) exam · \(countdown)").font(.headline).widgetAccentable()
                Text(due).font(.caption)
                Text("\(Int(snapshot.readiness * 100))% ready").font(.caption2)
            }
        default:
            VStack(alignment: .leading, spacing: 4) {
                Text("\(snapshot.exam) EXAM").font(.caption2.weight(.bold)).foregroundStyle(teal)
                Text(countdown).font(.system(size: 34, weight: .bold, design: .rounded)).minimumScaleFactor(0.6)
                Text(snapshot.daysUntilExam == nil ? "Set a date in the app" : "to go").font(.caption2).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Label("\(snapshot.cardsDue) cards", systemImage: "rectangle.on.rectangle.angled").font(.caption2)
                Label("\(snapshot.recheckDue) re-check", systemImage: "arrow.clockwise").font(.caption2)
                Label("\(snapshot.streak)-day streak", systemImage: "flame.fill").font(.caption2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
