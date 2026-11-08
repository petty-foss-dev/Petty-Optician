import Foundation
import SwiftData

/// iCloud sync can't enforce uniqueness, so two devices may each create a record for the same question or card.
/// This folds those duplicates into one, keeping every answer and the most recent state.
enum ProgressMerge {
    @MainActor
    static func run(in context: ModelContext) {
        mergeStats(context)
        keepNewest(CardReview.self, in: context, key: \.cardID, newest: \.lastReviewed)
        keepNewest(StudyNote.self, in: context, key: { "\($0.kindRaw)|\($0.targetID)" }, newest: \.updated)
        keepNewest(PersonalCard.self, in: context, key: \.cardID, newest: \.created)
        keepNewest(QuizRecord.self, in: context, key: \.id, newest: \.date)
        mergeMarks(context)
        if context.hasChanges { try? context.save() }
    }

    private static func mergeStats(_ context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<QuestionStat>())) ?? []
        for duplicates in Dictionary(grouping: all, by: \.questionID).values where duplicates.count > 1 {
            let group = duplicates.sorted { $0.uid.uuidString < $1.uid.uuidString }
            let latest = group.max { $0.lastAnswered < $1.lastAnswered }!
            let keep = group[0]
            keep.seen = group.map(\.seen).reduce(0, +)
            keep.correct = group.map(\.correct).reduce(0, +)
            keep.flagged = group.contains(where: \.flagged)
            keep.lastAnswered = latest.lastAnswered
            keep.lastWasCorrect = latest.lastWasCorrect
            keep.reviewDue = latest.reviewDue
            keep.reviewStep = latest.reviewStep
            group.dropFirst().forEach(context.delete)
        }
    }

    private static func mergeMarks(_ context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<ResourceMark>())) ?? []
        for duplicates in Dictionary(grouping: all, by: \.resourceID).values where duplicates.count > 1 {
            let group = duplicates.sorted { $0.uid.uuidString < $1.uid.uuidString }
            group[0].completed = group.contains(where: \.completed)
            group[0].favorite = group.contains(where: \.favorite)
            group.dropFirst().forEach(context.delete)
        }
    }

    private static func keepNewest<M: PersistentModel, Key: Hashable>(
        _ type: M.Type, in context: ModelContext, key: (M) -> Key, newest: KeyPath<M, Date>
    ) {
        let all = (try? context.fetch(FetchDescriptor<M>())) ?? []
        for group in Dictionary(grouping: all, by: key).values where group.count > 1 {
            let sorted = group.sorted { $0[keyPath: newest] > $1[keyPath: newest] }
            sorted.dropFirst().forEach(context.delete)
        }
    }
}
