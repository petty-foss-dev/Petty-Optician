import SwiftData
import SwiftUI

struct FlashcardDeck: Identifiable {
    let id = UUID()
    let title: String
    let cards: [Flashcard]
}

struct FlashcardsView: View {
    @ObservedObject private var settings = StudySettings.shared
    @Query private var reviews: [CardReview]
    @Environment(\.palette) private var palette
    @State private var activeDeck: FlashcardDeck?
    private let library = ContentLibrary.shared

    private var reviewMap: [String: CardReview] {
        Dictionary(reviews.map { ($0.cardID, $0) }, uniquingKeysWith: { first, _ in first })
    }

    var body: some View {
        let cards = library.flashcards(for: settings.exam)
        let map = reviewMap
        let due = cards.filter { map[$0.id].map { $0.due <= .now } ?? false }.sorted { map[$0.id]!.due < map[$1.id]!.due }
        let fresh = cards.filter { map[$0.id] == nil }
        let introducedToday = reviews.filter { Calendar.current.isDateInToday($0.introduced) }.count
        let newToday = Array(fresh.prefix(max(0, settings.dailyNewCards - introducedToday)))

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ExamSwitcher()

                    Panel {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 0) {
                                countColumn(due.count, "Due")
                                countColumn(newToday.count, "New today")
                                countColumn(cards.count - fresh.count, "Learned")
                            }
                            Button {
                                activeDeck = FlashcardDeck(title: "Daily Review", cards: due + newToday)
                            } label: {
                                Text(due.isEmpty && newToday.isEmpty ? "All caught up" : "Study \(due.count + newToday.count) Cards")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(due.isEmpty && newToday.isEmpty)
                            .accessibilityIdentifier("cards.study")

                            Stepper(value: $settings.dailyNewCards, in: 5...100, step: 5) {
                                Text("New cards per day: **\(settings.dailyNewCards)**").font(.subheadline)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(title: "Decks", trailing: "\(cards.count) cards")
                        ForEach(library.domains(for: settings.exam)) { domain in
                            let deck = cards.filter { $0.domain == domain.id }
                            if !deck.isEmpty {
                                deckRow(domain: domain, cards: deck, map: map)
                            }
                        }
                    }
                }
                .padding()
            }
            .tabScreen("Flashcards")
        }
        .fullScreenCover(item: $activeDeck) { FlashcardSessionView(deck: $0) }
    }

    private func countColumn(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.title2.weight(.bold).monospacedDigit()).foregroundStyle(palette.text)
            Text(label).font(.caption).foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private func deckRow(domain: ExamDomain, cards: [Flashcard], map: [String: CardReview]) -> some View {
        let learned = cards.filter { map[$0.id] != nil }.count
        return Panel(padding: 14) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(domain.name).font(.headline).foregroundStyle(palette.text)
                    MeterBar(value: Double(learned) / Double(cards.count))
                    Text("\(learned) of \(cards.count) learned")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }
                Menu {
                    Button("Cram All \(cards.count)", systemImage: "shuffle") {
                        activeDeck = FlashcardDeck(title: domain.name, cards: cards.shuffled())
                    }
                    let unlearned = cards.filter { map[$0.id] == nil }
                    if !unlearned.isEmpty {
                        Button("Learn \(min(20, unlearned.count)) New", systemImage: "sparkles") {
                            activeDeck = FlashcardDeck(title: domain.name, cards: Array(unlearned.prefix(20)))
                        }
                    }
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(palette.accent)
                }
            }
        }
    }
}

struct FlashcardSessionView: View {
    let deck: FlashcardDeck
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.palette) private var palette
    @Query private var reviews: [CardReview]
    @State private var queue: [Flashcard] = []
    @State private var flipped = false
    @State private var reviewed = 0
    @State private var started = false
    private let library = ContentLibrary.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let card = queue.first {
                    Text("\(queue.count) left · \(reviewed) reviewed")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(palette.secondaryText)

                    cardFace(card)
                        .onTapGesture { withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { flipped.toggle() } }
                        .accessibilityIdentifier("card.face")

                    if flipped {
                        gradeButtons(card)
                    } else {
                        Text("Tap the card to reveal")
                            .font(.subheadline)
                            .foregroundStyle(palette.tertiaryText)
                            .frame(minHeight: 60)
                    }
                } else if started {
                    ContentUnavailableView {
                        Label("Session Complete", systemImage: "checkmark.seal.fill")
                    } description: {
                        Text("\(reviewed) cards reviewed.")
                    } actions: {
                        Button("Done") { dismiss() }.buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .pettyScreen()
            .navigationTitle(deck.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel("Close")
                }
            }
        }
        .onAppear {
            guard !started else { return }
            queue = deck.cards
            started = true
        }
    }

    private func cardFace(_ card: Flashcard) -> some View {
        ZStack {
            face(text: card.front, caption: library.domainName(card.domain), isBack: false)
                .opacity(flipped ? 0 : 1)
            face(text: card.back, caption: "Answer", isBack: true)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(flipped ? 1 : 0)
        }
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .frame(maxHeight: 440)
    }

    private func face(text: String, caption: String, isBack: Bool) -> some View {
        VStack(spacing: 16) {
            Text(caption.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(isBack ? palette.accent : palette.secondaryText)
            ScrollView {
                RichText(text: text)
                    .font(isBack ? .body : .title3.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(palette.cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(palette.accent.opacity(isBack ? 0.5 : 0.2), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
        }
    }

    private func gradeButtons(_ card: Flashcard) -> some View {
        HStack(spacing: 10) {
            ForEach(CardGrade.allCases) { grade in
                Button {
                    record(grade, for: card)
                } label: {
                    Text(grade.label)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.bordered)
                .tint(tint(for: grade))
                .accessibilityIdentifier("grade.\(grade.label.lowercased())")
            }
        }
        .frame(minHeight: 60)
    }

    private func tint(for grade: CardGrade) -> Color {
        switch grade {
        case .again: .red
        case .hard: .orange
        case .good: .green
        case .easy: .blue
        }
    }

    private func record(_ grade: CardGrade, for card: Flashcard) {
        let review = reviews.first { $0.cardID == card.id } ?? {
            let created = CardReview(cardID: card.id)
            context.insert(created)
            return created
        }()
        CardScheduler.apply(grade, to: review)
        try? context.save()
        StudySettings.shared.recordStudy()
        reviewed += 1
        flipped = false
        withAnimation(.snappy) {
            queue.removeFirst()
            if grade == .again { queue.insert(card, at: min(3, queue.count)) }
        }
    }
}
