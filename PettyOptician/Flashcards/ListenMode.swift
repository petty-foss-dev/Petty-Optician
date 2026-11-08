import AVFoundation
import FluidAudio
import SwiftUI

/// Text-to-speech that keeps playing with the screen locked. Uses the Supertonic voice when one is picked and
/// downloaded, and Apple's built-in voice otherwise.
@MainActor
@Observable
final class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    /// 1 is normal pace.
    var speed: Float = 1
    private(set) var isSpeaking = false
    private let synthesizer = AVSpeechSynthesizer()
    private let player = PCMPlayer()
    private var finished: CheckedContinuation<Void, Never>?
    private var current: ObjectIdentifier?
    private var generation = 0

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    private var supertonicVoice: SupertonicVoice? {
        StudySettings.shared.supertonicVoice.flatMap { SupertonicPack.isInstalled ? $0 : nil }
    }

    /// Returns when the text has been read, or right away if speech is stopped.
    func say(_ text: String) async {
        stop()
        let mine = generation
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        isSpeaking = true
        if let voice = supertonicVoice {
            do {
                let samples = try await SupertonicRuntime.shared.synthesize(Self.spoken(text), voice: voice, speed: Supertonic3Constants.defaultSpeed * speed)
                guard generation == mine else { return }
                try await player.play(samples)
                if generation == mine { finishSpeaking() }
                return
            } catch {
                guard generation == mine else { return }
            }
        }
        let utterance = AVSpeechUtterance(string: Self.spoken(text))
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * speed
        current = ObjectIdentifier(utterance)
        await withCheckedContinuation { continuation in
            finished = continuation
            synthesizer.speak(utterance)
        }
    }

    /// Synthesizes ahead so the next line starts without a pause; Apple's voice needs no warm-up.
    func prepare(_ text: String) {
        guard let voice = supertonicVoice else { return }
        let speed = Supertonic3Constants.defaultSpeed * speed
        Task { _ = try? await SupertonicRuntime.shared.synthesize(Self.spoken(text), voice: voice, speed: speed) }
    }

    func stop() {
        generation += 1
        player.stop()
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        resume(current)
        finishSpeaking()
    }

    /// Reads optics notation the way an optician would say it instead of letter by letter.
    nonisolated static func spoken(_ text: String) -> String {
        [("**", ""), ("−", "minus "), ("Δ", " prism diopters"), (" × ", " axis "), ("°", " degrees"), ("- ", "")]
            .reduce(text) { $0.replacingOccurrences(of: $1.0, with: $1.1) }
    }

    private func finishSpeaking() {
        guard isSpeaking else { return }
        isSpeaking = false
        // Deactivation blocks, so it runs off the main thread, and only if no new speech starts in the meantime.
        let ended = generation
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard generation == ended, !isSpeaking else { return }
            await Task.detached { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }.value
        }
    }

    /// Late delegate callbacks for an utterance that was already stopped must not end the next one.
    private func resume(_ utterance: ObjectIdentifier?) {
        guard utterance != nil, utterance == current else { return }
        current = nil
        finished?.resume()
        finished = nil
        finishSpeaking()
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.resume(id) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.resume(id) }
    }
}

/// Reads each card's front, pauses so you can answer in your head, then reads the back. Doesn't change card scheduling.
struct ListenSessionView: View {
    let deck: FlashcardDeck
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var speaker = Speaker()
    @State private var index = 0
    @State private var showingBack = false
    @State private var playing = true
    @State private var thinkSeconds = 4.0
    @State private var run: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if index < deck.cards.count {
                    let card = deck.cards[index]
                    Text("\(index + 1) of \(deck.cards.count)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(palette.secondaryText)
                    Panel(padding: 24) {
                        VStack(alignment: .leading, spacing: 16) {
                            RichText(text: card.front).font(.title3.weight(.semibold))
                            if showingBack {
                                Divider()
                                RichText(text: card.back)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Spacer()
                    controls
                } else {
                    ContentUnavailableView {
                        Label("All done", systemImage: "checkmark.seal.fill")
                    } description: {
                        Text("\(deck.cards.count) cards read aloud.")
                    } actions: {
                        Button("Start Over") { restart(at: 0) }.buttonStyle(.bordered)
                        Button("Done") { dismiss() }.buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .pettyScreen()
            .navigationTitle("Listen · \(deck.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel("Close")
                }
            }
        }
        .onAppear { restart(at: 0) }
        .onDisappear {
            run?.cancel()
            speaker.stop()
        }
    }

    private var controls: some View {
        VStack(spacing: 18) {
            HStack(spacing: 36) {
                Button { restart(at: max(0, index - 1)) } label: { Image(systemName: "backward.fill") }
                    .accessibilityLabel("Previous card")
                Button { playing ? pause() : restart(at: index) } label: {
                    Image(systemName: playing ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 64))
                }
                .accessibilityLabel(playing ? "Pause" : "Play")
                .accessibilityIdentifier("listen.play")
                Button { restart(at: index + 1) } label: { Image(systemName: "forward.fill") }
                    .accessibilityLabel("Next card")
            }
            .font(.title)
            .foregroundStyle(palette.accent)

            VStack(alignment: .leading, spacing: 6) {
                Text("Time to answer: \(Int(thinkSeconds)) s").font(.subheadline)
                Slider(value: $thinkSeconds, in: 2...12, step: 1)
                Picker("Speed", selection: $speaker.speed) {
                    Text("Slow").tag(Float(0.85))
                    Text("Normal").tag(Float(1))
                    Text("Fast").tag(Float(1.2))
                }
                .pickerStyle(.segmented)
                NavigationLink { VoiceSettingsView() } label: {
                    HStack {
                        Text("Voice")
                        Spacer()
                        Text(StudySettings.shared.supertonicVoice.map { SupertonicPack.isInstalled ? "Supertonic \($0.rawValue)" : "Apple (Supertonic not downloaded)" } ?? "Apple")
                            .foregroundStyle(palette.secondaryText)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(palette.tertiaryText)
                    }
                    .font(.subheadline)
                }
                .accessibilityIdentifier("listen.voice")
            }
            Text("Keeps playing with the screen locked. Listening doesn't change when cards are due.")
                .font(.caption)
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    private func pause() {
        playing = false
        run?.cancel()
        speaker.stop()
    }

    private func restart(at start: Int) {
        run?.cancel()
        speaker.stop()
        index = start
        playing = true
        run = Task {
            while index < deck.cards.count, !Task.isCancelled {
                let card = deck.cards[index]
                showingBack = false
                speaker.prepare(card.back)
                await speaker.say(card.front)
                try? await Task.sleep(for: .seconds(thinkSeconds))
                guard !Task.isCancelled else { return }
                showingBack = true
                if index + 1 < deck.cards.count { speaker.prepare(deck.cards[index + 1].front) }
                await speaker.say(card.back)
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                index += 1
            }
            playing = false
        }
    }
}
