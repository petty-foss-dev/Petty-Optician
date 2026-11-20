import Foundation
import Observation

struct SavedMock: Codable {
    let id: UUID
    let exam: ExamID
    let title: String
    let started: Date
    let duration: Int
    let questions: [Question]
    let pretestIDs: Set<String>
    let index: Int
    let selections: [Int?]
    let flags: Set<String>
    let changedFlags: Set<String>

    func isValid(for track: ExamID) -> Bool {
        let ids = Set(questions.map(\.id))
        return exam == track && duration > 0 && questions.indices.contains(index)
            && ids.count == questions.count && selections.count == questions.count
            && pretestIDs.isSubset(of: ids) && flags.isSubset(of: ids) && changedFlags.isSubset(of: ids)
            && zip(questions, selections).allSatisfy { question, selection in
                question.exam == track && question.choices.indices.contains(question.answer)
                    && (selection.map(question.choices.indices.contains) ?? true)
            }
    }
}

@MainActor
@Observable
final class SavedMockExams {
    static let shared: SavedMockExams = {
        var directory = URL.applicationSupportDirectory.appending(path: "Mock Exams")
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            directory = directory.appending(path: "UITests")
        }
        return SavedMockExams(directory: directory)
    }()

    private let directory: URL
    private(set) var sessions: [ExamID: QuizSession] = [:]
    private(set) var unreadable: Set<ExamID> = []

    init(directory: URL) {
        self.directory = directory
        for exam in ExamID.allCases {
            do {
                let data = try Data(contentsOf: file(for: exam))
                let state = try JSONDecoder().decode(SavedMock.self, from: data)
                guard state.isValid(for: exam) else { throw CocoaError(.fileReadCorruptFile) }
                sessions[exam] = QuizSession(saved: state, store: self)
            } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
                continue
            } catch {
                unreadable.insert(exam)
            }
        }
    }

    func begin(config: QuizConfig, questions: [Question], flagged: Set<String>, at start: Date = .now) throws -> QuizSession {
        if let existing = sessions[config.exam] { return existing }
        guard !unreadable.contains(config.exam), let duration = config.timeLimitSeconds, !questions.isEmpty else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let mock = SavedMock(
            id: UUID(), exam: config.exam, title: config.title, started: start, duration: duration,
            questions: questions, pretestIDs: config.pretestIDs, index: 0,
            selections: Array(repeating: nil, count: questions.count),
            flags: flagged.intersection(questions.map(\.id)), changedFlags: []
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try write(mock)
        let session = QuizSession(saved: mock, store: self)
        sessions[config.exam] = session
        return session
    }

    func save(_ mock: SavedMock) throws {
        guard sessions[mock.exam]?.id == mock.id else { return }
        try write(mock)
    }

    func remove(_ exam: ExamID, id: UUID? = nil) throws {
        if let id, sessions[exam]?.id != id { return }
        do {
            try FileManager.default.removeItem(at: file(for: exam))
        } catch let error as CocoaError where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile {}
        sessions[exam] = nil
        unreadable.remove(exam)
    }

    private func file(for exam: ExamID) -> URL {
        directory.appending(path: "\(exam.rawValue).json")
    }

    private func write(_ mock: SavedMock) throws {
        try JSONEncoder().encode(mock).write(to: file(for: mock.exam), options: .atomic)
    }
}
