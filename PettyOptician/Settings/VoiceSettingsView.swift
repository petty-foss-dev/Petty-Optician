import SwiftUI

struct VoiceSettingsView: View {
    @ObservedObject private var settings = StudySettings.shared
    @State private var installed = SupertonicPack.isInstalled
    @State private var progress: Double?
    @State private var download: Task<Void, Never>?
    @State private var errorMessage: String?
    @State private var speaker = Speaker()

    private static let sample = "The tear lens is the layer of tears between the back of a GP lens and the cornea."

    var body: some View {
        Form {
            Section {
                Picker("Voice", selection: $settings.supertonicVoice) {
                    Text("Apple voice (built in)").tag(SupertonicVoice?.none)
                    if installed {
                        ForEach(SupertonicVoice.allCases) { Text("Supertonic \($0.label)").tag(Optional($0)) }
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                Button(speaker.isSpeaking ? "Stop" : "Play a Sample", systemImage: speaker.isSpeaking ? "stop.fill" : "play.fill") {
                    if speaker.isSpeaking { speaker.stop() } else { Task { await speaker.say(Self.sample) } }
                }
                .accessibilityIdentifier("voice.preview")
            } header: {
                Text("Listening voice")
            } footer: {
                Text("Used by Listen mode and the read-aloud button on the Question of the Day.")
            }

            Section {
                if installed {
                    LabeledContent("Supertonic voices", value: "Downloaded")
                    Button("Remove Voice Download", role: .destructive, action: remove)
                } else if let progress {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: progress)
                        Text("Downloading… \(Int(progress * 100))% of \(Self.size)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button("Cancel Download", role: .cancel) { download?.cancel() }
                } else {
                    Button("Agree & Download (\(Self.size))", systemImage: "arrow.down.circle", action: startDownload)
                        .accessibilityIdentifier("voice.download")
                }
                if let errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(.red)
                }
            } header: {
                Text("Supertonic voices")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ten natural-sounding voices that run entirely on this iPhone. The download comes from Hugging Face and needs no account; nothing you study is sent anywhere.")
                    Text("The Supertonic 3 models are made by Supertone and licensed under OpenRAIL-M, which includes use restrictions. By downloading, you agree to that license.")
                    Link("Read the model license", destination: SupertonicPack.licenseURL)
                    Link("Model files on Hugging Face", destination: SupertonicPack.modelURL)
                }
            }
        }
        .navigationTitle("Voice")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { speaker.stop() }
    }

    private static var size: String { ByteCountFormatter.string(fromByteCount: Int64(SupertonicPack.totalBytes), countStyle: .file) }

    private func startDownload() {
        errorMessage = nil
        progress = 0
        download = Task {
            do {
                try await SupertonicPack.install { value in Task { @MainActor in progress = value } }
                installed = true
                if settings.supertonicVoice == nil { settings.supertonicVoice = .f1 }
            } catch is CancellationError {
            } catch {
                errorMessage = error.localizedDescription
            }
            progress = nil
        }
    }

    private func remove() {
        speaker.stop()
        Task {
            do {
                try await SupertonicPack.remove()
            } catch {
                errorMessage = error.localizedDescription
            }
            installed = SupertonicPack.isInstalled
            if !installed { settings.supertonicVoice = nil }
        }
    }
}
