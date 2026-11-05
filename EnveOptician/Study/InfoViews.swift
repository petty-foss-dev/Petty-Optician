import SwiftUI

struct ExamInfoView: View {
    let exam: ExamID
    @Environment(\.palette) private var palette
    @Environment(\.bottomBarInset) private var bottomBarInset
    private let library = ContentLibrary.shared

    var body: some View {
        ScrollView {
            if let info = library.exam(exam) {
                VStack(alignment: .leading, spacing: 20) {
                    Text(info.name).font(.title2.weight(.bold))
                    if let administrator = info.administrator {
                        Text(administrator).foregroundStyle(palette.secondaryText)
                    }

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        StatTile(value: info.totalQuestions.map(String.init) ?? "—", label: "Questions", symbol: "list.number")
                        StatTile(value: info.scoredQuestions.map(String.init) ?? "—", label: "Scored", symbol: "checkmark.circle")
                        StatTile(value: info.timeMinutes.map { "\($0) min" } ?? "—", label: "Time limit", symbol: "clock")
                        StatTile(value: info.fee ?? "—", label: "Exam fee", symbol: "dollarsign.circle")
                    }

                    factPanel(info)

                    if let outline = info.officialOutline, !outline.isEmpty {
                        SectionTitle(title: "Official Content Outline")
                        Panel {
                            VStack(alignment: .leading, spacing: 16) {
                                ForEach(outline, id: \.self) { domain in
                                    OutlineRow(domain: domain)
                                }
                            }
                        }
                    }

                    if let notes = info.notes, !notes.isEmpty {
                        SectionTitle(title: "Good to Know")
                        Panel {
                            RichText(text: notes.map { "- \($0)" }.joined(separator: "\n"))
                                .font(.subheadline)
                        }
                    }

                    VStack(spacing: 10) {
                        if let url = info.registrationURL {
                            BrowserLink(url: url) {
                                Label("Register for the Exam", systemImage: "arrow.up.right.square")
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        if let url = info.contentOutlineURL {
                            BrowserLink(url: url) {
                                Label("Official Handbook / Outline", systemImage: "doc.text")
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding()
            }
        }
        .safeAreaPadding(.bottom, bottomBarInset)
        .enveScreen()
        .navigationTitle(exam.shortLabel)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func factPanel(_ info: Exam) -> some View {
        let facts: [(String, String?)] = [
            ("Delivery", info.delivery),
            ("Scoring", info.scoring),
            ("Eligibility", info.eligibility),
            ("Retakes", info.retakePolicy)
        ]
        return Panel {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(facts.filter { $0.1 != nil }, id: \.0) { label, value in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(label.uppercased())
                            .font(.caption.weight(.bold))
                            .tracking(0.8)
                            .foregroundStyle(palette.accent)
                        Text(value ?? "").font(.subheadline)
                    }
                }
            }
        }
    }
}

private struct OutlineRow: View {
    let domain: OfficialOutlineDomain
    @State private var expanded = false
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.snappy) { expanded.toggle() }
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(domain.name).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
                        Spacer()
                        if let weight = domain.weight {
                            Text("\(Int(weight))%").font(.subheadline.weight(.bold).monospacedDigit()).foregroundStyle(palette.accent)
                        }
                        if domain.subtopics?.isEmpty == false {
                            Image(systemName: "chevron.down")
                                .rotationEffect(.degrees(expanded ? 180 : 0))
                                .foregroundStyle(palette.tertiaryText)
                        }
                    }
                    if let weight = domain.weight { MeterBar(value: weight / 40) }
                }
            }
            .buttonStyle(.plain)

            if expanded, let subtopics = domain.subtopics {
                RichText(text: subtopics.map { "- \($0)" }.joined(separator: "\n"))
                    .font(.footnote)
            }
        }
    }
}

struct CaliforniaView: View {
    @Environment(\.palette) private var palette
    @Environment(\.bottomBarInset) private var bottomBarInset
    private let guide = ContentLibrary.shared.california

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Panel {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("California", systemImage: "building.columns.fill")
                            .font(.headline)
                            .foregroundStyle(palette.accent)
                        Text(guide.summary).font(.subheadline)
                        if let verified = guide.lastVerified {
                            Text("Last verified \(verified)").font(.caption).foregroundStyle(palette.tertiaryText)
                        }
                    }
                }

                if let career = guide.career {
                    SectionTitle(title: "Career & Verification")
                    Panel {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(career.summary).font(.subheadline)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
                                ForEach(career.stats, id: \.self) { stat in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(stat.value).font(.title3.weight(.bold).monospacedDigit()).foregroundStyle(palette.accent)
                                        Text(stat.label).font(.caption).foregroundStyle(palette.secondaryText)
                                    }
                                }
                            }
                            if let asOf = career.asOf {
                                Text(asOf).font(.caption2).foregroundStyle(palette.tertiaryText)
                            }
                            SourceList(sources: career.links)
                        }
                    }
                }

                SectionTitle(title: "Registrations")
                ForEach(guide.credentials) { CredentialCard(credential: $0) }

                SectionTitle(title: "Steps")
                Panel {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(guide.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.subheadline.weight(.bold))
                                    .frame(width: 28, height: 28)
                                    .background(Circle().fill(palette.accent))
                                    .foregroundStyle(.white)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(step.title).font(.subheadline.weight(.semibold))
                                    Text(step.detail).font(.subheadline).foregroundStyle(palette.secondaryText)
                                    if let url = step.url {
                                        BrowserLink(url: url) { Text("Open link") }.font(.caption.weight(.semibold))
                                    }
                                }
                            }
                        }
                    }
                }

                if let faq = guide.faq, !faq.isEmpty {
                    SectionTitle(title: "FAQ")
                    Panel {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(faq, id: \.self) { entry in
                                DisclosureGroup {
                                    Text(entry.a)
                                        .font(.subheadline)
                                        .foregroundStyle(palette.secondaryText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 4)
                                } label: {
                                    Text(entry.q).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }

                if let sources = guide.sources, !sources.isEmpty {
                    SectionTitle(title: "Official Sources")
                    Panel {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(sources, id: \.self) { source in
                                BrowserLink(url: source.url) {
                                    Label(source.title, systemImage: "link")
                                        .font(.subheadline)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                        }
                    }
                }

                Text("Rules and fees change. Confirm everything with the California State Board of Optometry before applying.")
                    .font(.caption)
                    .foregroundStyle(palette.tertiaryText)
            }
            .padding()
        }
        .safeAreaPadding(.bottom, bottomBarInset)
        .enveScreen()
        .navigationTitle("California")
    }
}

private struct CredentialCard: View {
    let credential: CaliforniaCredential
    @Environment(\.palette) private var palette

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(credential.name).font(.headline)
                    Spacer()
                    if let exam = credential.requiredExam {
                        Chip(text: "Requires \(exam.shortLabel)", selected: true)
                    }
                }
                if let agency = credential.agency {
                    Text(agency).font(.caption).foregroundStyle(palette.secondaryText)
                }
                if let requirements = credential.requirements, !requirements.isEmpty {
                    RichText(text: requirements.map { "- \($0)" }.joined(separator: "\n"))
                        .font(.subheadline)
                }
                HStack(spacing: 16) {
                    if let fee = credential.fee { Label(fee, systemImage: "dollarsign.circle") }
                    if let renewal = credential.renewal { Label(renewal, systemImage: "arrow.triangle.2.circlepath") }
                }
                .font(.caption)
                .foregroundStyle(palette.secondaryText)
                if let sections = credential.codeSections, !sections.isEmpty {
                    Text(sections.joined(separator: " · ")).font(.caption2).foregroundStyle(palette.tertiaryText)
                }
                if let url = credential.url {
                    BrowserLink(url: url) { Text("Official page") }.font(.caption.weight(.semibold))
                }
            }
        }
    }
}
