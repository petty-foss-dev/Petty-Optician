import AVFoundation
import CryptoKit
import FluidAudio
import Foundation

/// Supertonic 3 voices run fully on device; the Core ML models are an optional download pinned by revision and checksum.
enum SupertonicVoice: String, CaseIterable, Identifiable, Sendable {
    case f1 = "F1", f2 = "F2", f3 = "F3", f4 = "F4", f5 = "F5"
    case m1 = "M1", m2 = "M2", m3 = "M3", m4 = "M4", m5 = "M5"

    var id: String { rawValue }
    var label: String { "Voice \(rawValue) · \(rawValue.hasPrefix("F") ? "feminine" : "masculine")" }
    fileprivate var fluidVoice: Supertonic3Voice { Supertonic3Voice(name: rawValue) ?? .default }
}

enum SupertonicError: LocalizedError {
    case damagedDownload, emptyAudio

    var errorDescription: String? {
        switch self {
        case .damagedDownload: "The voice download was incomplete or damaged. Try again."
        case .emptyAudio: "The voice produced no audio."
        }
    }
}

enum SupertonicPack {
    static let licenseURL = URL(string: "https://huggingface.co/Supertone/supertonic-3/blob/main/LICENSE")!
    static let modelURL = URL(string: "https://huggingface.co/FluidInference/supertonic-3-coreml")!

    struct File: Decodable, Sendable {
        let path: String
        let size: Int
        let sha256: String
    }

    private struct Manifest: Decodable {
        let revision: String
        let files: [File]
    }

    private static let manifest: Manifest = {
        let url = Bundle.main.url(forResource: "SupertonicManifest", withExtension: "json")!
        return try! JSONDecoder().decode(Manifest.self, from: Data(contentsOf: url))
    }()

    static var totalBytes: Int { manifest.files.reduce(0) { $0 + $1.size } }

    static var root: URL {
        get throws { try TtsCacheDirectory.ensure().appendingPathComponent("Models/PettySupertonic3") }
    }

    static var isInstalled: Bool {
        guard let root = try? root else { return false }
        return manifest.files.allSatisfy { size(at: destination(for: $0, in: root)) == $0.size }
    }

    // The pinned FluidAudio loader expects the original bundle names for these compatible v2 exports.
    private static func destination(for file: File, in root: URL) -> URL {
        root.appendingPathComponent(Repo.supertonic3.folderName).appendingPathComponent(file.path.replacingOccurrences(of: "_v2", with: ""))
    }

    private static func size(at url: URL) -> Int? { try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize }

    static func install(progress: @escaping @Sendable (Double) -> Void) async throws {
        let root = try root
        let total = Double(totalBytes)
        let source = URL(string: "https://huggingface.co/\(Repo.supertonic3.remotePath)/resolve/\(manifest.revision)")!
        var completed = 0
        for file in manifest.files {
            try Task.checkCancellation()
            let target = destination(for: file, in: root)
            if size(at: target) != file.size {
                let before = Double(completed)
                let watcher = DownloadProgress { progress((before + $0 * Double(file.size)) / total) }
                let (temporary, response) = try await URLSession.shared.download(from: source.appendingPathComponent(file.path), delegate: watcher)
                defer { try? FileManager.default.removeItem(at: temporary) }
                let data = try Data(contentsOf: temporary, options: .mappedIfSafe)
                let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                guard (response as? HTTPURLResponse)?.statusCode == 200, data.count == file.size, digest == file.sha256 else {
                    throw SupertonicError.damagedDownload
                }
                try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? FileManager.default.removeItem(at: target)
                try FileManager.default.moveItem(at: temporary, to: target)
            }
            completed += file.size
            progress(Double(completed) / total)
        }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var excluded = root
        try? excluded.setResourceValues(values)
    }

    static func remove() async throws {
        await SupertonicRuntime.shared.unload()
        try FileManager.default.removeItem(at: root)
    }
}

/// Reports byte progress for the async `URLSession.download(from:delegate:)` API, which has no progress callback of its own.
private final class DownloadProgress: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let report: @Sendable (Double) -> Void
    private var observation: NSKeyValueObservation?

    init(report: @escaping @Sendable (Double) -> Void) {
        self.report = report
    }

    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        observation = task.progress.observe(\.fractionCompleted) { [report] progress, _ in report(progress.fractionCompleted) }
    }
}

actor SupertonicRuntime {
    static let shared = SupertonicRuntime()

    private var manager: Supertonic3Manager?
    private var styles: [SupertonicVoice: Supertonic3VoiceStyle] = [:]
    private var recent: [String: [Float]] = [:]
    private var recentOrder: [String] = []

    /// Voices each natural phrase separately, trims the model's silent padding, and joins them with deliberate pauses.
    func synthesize(_ text: String, voice: SupertonicVoice, speed: Float) async throws -> [Float] {
        let key = "\(voice.rawValue)|\(speed)|\(text)"
        if let cached = recent[key] { return cached }
        let manager = try await loadedManager()
        let style = try style(for: voice)
        let rate = Double(Supertonic3Constants.sampleRate)
        var samples: [Float] = []
        for phrase in SpeechPhrases.split(text) {
            try Task.checkCancellation()
            let clip = try await manager.synthesize(text: phrase.text, language: "en", style: style, speed: speed).samples
            samples += SpeechPhrases.trimSilence(clip, sampleRate: rate)
            samples += [Float](repeating: 0, count: Int(phrase.pause / Double(speed) * rate))
        }
        guard samples.contains(where: { $0 != 0 }) else { throw SupertonicError.emptyAudio }
        remember(samples, for: key)
        return samples
    }

    func unload() {
        manager = nil
        styles = [:]
        recent = [:]
        recentOrder = []
    }

    private func loadedManager() async throws -> Supertonic3Manager {
        if let manager { return manager }
        let created = Supertonic3Manager(directory: try SupertonicPack.root, computeUnits: .cpuAndNeuralEngine, vectorEstimator: .aneBucketed(.int4))
        try await created.initialize()
        manager = created
        return created
    }

    private func style(for voice: SupertonicVoice) throws -> Supertonic3VoiceStyle {
        if let style = styles[voice] { return style }
        let url = try SupertonicPack.root.appendingPathComponent(Repo.supertonic3.folderName).appendingPathComponent(voice.fluidVoice.fileName)
        let style = try Supertonic3VoiceStyle.load(from: url)
        styles[voice] = style
        return style
    }

    /// Keeps the last few clips so prefetching the next card and replays don't synthesize twice.
    private func remember(_ samples: [Float], for key: String) {
        recent[key] = samples
        recentOrder.append(key)
        if recentOrder.count > 8 { recent[recentOrder.removeFirst()] = nil }
    }
}

@MainActor
final class PCMPlayer {
    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: Double(Supertonic3Constants.sampleRate), channels: 1)!
    private var playing: (id: UUID, continuation: CheckedContinuation<Void, Never>)?

    init() {
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
    }

    func play(_ samples: [Float]) async throws {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        buffer.floatChannelData![0].update(from: samples, count: samples.count)
        if !engine.isRunning { try engine.start() }
        let id = UUID()
        await withCheckedContinuation { continuation in
            playing = (id, continuation)
            // Called on the audio render thread, so it hops back before touching state.
            node.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { @Sendable [weak self] _ in
                Task { @MainActor in self?.finish(id) }
            }
            node.play()
        }
    }

    func stop() {
        guard let playing else { return }
        node.stop()
        finish(playing.id)
    }

    private func finish(_ id: UUID) {
        guard let current = playing, current.id == id else { return }
        playing = nil
        current.continuation.resume()
    }
}
