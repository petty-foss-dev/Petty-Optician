import Foundation

enum CardGrade: Int, CaseIterable, Identifiable, Sendable {
    case again, hard, good, easy

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .again: "Again"
        case .hard: "Hard"
        case .good: "Good"
        case .easy: "Easy"
        }
    }
}

/// SM-2 variant: ease drifts with grades, intervals grow multiplicatively, lapses reset to 1 day.
enum CardScheduler {
    static let startingEase = 2.5
    static let minimumEase = 1.3

    struct State: Equatable, Sendable {
        var ease: Double
        var intervalDays: Double
        var reps: Int
        var lapses: Int
    }

    static func next(_ state: State, grade: CardGrade) -> State {
        var s = state
        switch grade {
        case .again:
            s.ease = max(minimumEase, s.ease - 0.2)
            s.intervalDays = 0
            s.lapses += 1
            s.reps = 0
            return s
        case .hard:
            s.ease = max(minimumEase, s.ease - 0.15)
            s.intervalDays = s.reps == 0 ? 1 : max(1, s.intervalDays * 1.2)
        case .good:
            s.intervalDays = switch s.reps {
            case 0: 1
            case 1: 3
            default: s.intervalDays * s.ease
            }
        case .easy:
            s.ease += 0.15
            s.intervalDays = s.reps == 0 ? 4 : s.intervalDays * s.ease * 1.3
        }
        s.reps += 1
        return s
    }

    static func apply(_ grade: CardGrade, to review: CardReview, now: Date = .now) {
        let state = next(
            State(ease: review.ease, intervalDays: review.intervalDays, reps: review.reps, lapses: review.lapses),
            grade: grade
        )
        review.ease = state.ease
        review.intervalDays = state.intervalDays
        review.reps = state.reps
        review.lapses = state.lapses
        review.lastReviewed = now
        review.due = grade == .again
            ? now.addingTimeInterval(60)
            : now.addingTimeInterval(state.intervalDays * 86_400)
    }
}
