# petty: Optician (iOS)

Study app for the ABO Basic (spectacle) and NCLE Basic (contact lens) certification exams, with California registration guidance (SLD/CLD/RDO via the California State Board of Optometry). SwiftUI · Swift 6 · SwiftData · iOS 17+. Part of the Petty app family: follows the workspace code norms (see `../CLAUDE.md`) but uses the Petty look shared with petty: Tracker and petty: Jobs — cool-gray surfaces, teal accent `#0F7A8A` / `#4FC1C9` dark, optional pure black, standard `TabView`, no animated background or floating pill bar. The palette lives in `Core/Theme/ThemeManager.swift`; the icon is rendered by `docs/icon/render_icon.py`.

## Source control

Public repo `https://github.com/petty-foss-dev/Petty-Optician.git` on `main`, AGPL-3.0-only like the other Petty apps. Before committing, check `pwd`, `git remote get-url origin` and `git branch --show-current`. No Claude co-author trailers.

## Build

```bash
xcodegen generate   # after adding files or editing project.yml
xcodebuild -project PettyOptician.xcodeproj -scheme PettyOptician \
  -destination "platform=iOS Simulator,id=FA996208-6558-4E89-88F1-B184DF04CD44" \
  -derivedDataPath /Volumes/games/EnveBuildTmp/DerivedData-optician build
xcodebuild ... test   # ContentTests validates every bundled JSON file
```

## Layout

- `PettyOptician/Models` — content types (`Content.swift`), `ContentLibrary` (bundle loader), SwiftData progress models, `QuizBuilder`, `CardScheduler` (SM-2), `OpticsMath`, `StudySettings`.
- `Home`, `Study`, `Practice`, `Flashcards`, `Library`, `Tools`, `Settings` — one folder per tab/feature.
- `Core` — Petty theme + `pettyScreen()` background, `Panel`/`Chip`/`RichText` components. The resolved `ColorSet` is injected as `\.palette` from `RootView`.

## Content packs

All study content is JSON in `PettyOptician/Resources/Content/`, discovered by filename prefix — drop in a new file and it loads, no code changes:

| Prefix | Shape |
|---|---|
| `questions_*.json` | `[{id, exam, domain, topic, difficulty 1–3, stem, choices[4], answer (0-based), explanation, source?{title,url}, diagram?}]` |
| `flashcards_*.json` | `[{id, exam, domain, front, back}]` |
| `guides_*.json` | `[{id, exam, domain, title, summary, sections[{heading, body, diagram?, sources?[], resourceID?, resourceReason?, trainerID?, checkpointIDs?[], relatedLessonID?}], formulas[{name, expression, notes}]}]` — guides sharing a `domain` are merged, so a pack can append lessons to an existing section |
| `resources_*.json` | `[{id, title, url, kind, exams[], domains[], author, description, free, minutes}]` — YouTube videos/playlists play in-app |
| `textbook.json` | ordered chapters `{id, exam, domain, title, introduction, objectives[], takeaways[], lessonOrder[Int], sources?[]}`; zero-based lesson indexes refer to the merged guide for that domain |
| `exams.json` / `california.json` / `diagrams.json` | single files — exam facts + official section weights, CA registration guide, diagram captions + sources |
| `glossary_*.json` | `[{id, term, definition, aliases[], exams[], domains[], source}]` — Glossary screen + search |
| `tables_*.json` | `[{id, title, exams[], domains[], columns[], rows[[String]], notes, sources[]}]` — Reference Tables; every row must have `columns.count` cells |
| `images.json` | single file — photos in `Resources/Images/` (`{id, file, title, caption, author, license, licenseURL, sourceURL, credit, exams[], domains[]}`); every photo needs a credit and license (CC BY-SA requires attribution + noting the resize), surfaced in Settings → Image Credits |

`exam` is `abo` or `ncle`. `domain` is an **official ABO-NCLE content-outline section** id from `exams.json`: ABO `abo.optics`, `abo.anatomy`, `abo.products`, `abo.instruments`, `abo.dispensing`, `abo.laws`; NCLE `ncle.anatomy`, `ncle.refraction`, `ncle.instruments`, `ncle.prefitting`, `ncle.fitting`, `ncle.dispensing`, `ncle.followup`, `ncle.regulatory`. Mock exams allocate questions by those weights; `topic` drives the per-section topic browser and search. Diagrams are drawn in code (`Diagrams/DiagramArt.swift`) keyed by id; `diagram` fields reference those ids. Guide bodies: paragraphs split by blank lines, `- ` bullets, inline `**bold**` only. IDs must be globally unique — `ContentTests` enforces this plus 4 choices, valid answer index, known sections/diagrams, and that every official section has a guide and questions. Every stem and card front must stand alone (it is shown shuffled, in widgets and read aloud): name the instrument, lens type, eye and case facts; `ContentContextTests` rejects instrument parts with no instrument named and references like "as shown" or "the same patient". Run the tests after adding content.

Built-in trainers live in `Tools/` and are listed in `Tools/Trainers.swift` (Practice tab; `SimulatorLabView` now holds only the outside web simulators): ABO lensometer (optional horizontal + vertical prism, graded separately from power), frame adjusting, PD & seg height, prism & base, ANSI job check; NCLE keratometer, GP fluorescein, soft lens fit, toric rotation (LARS). Right/left always means the patient's; drawings use the optician's front view. Each trainer's generation and scoring logic is unit-tested and its rules cite sources in-app. The timed Mock Exam runs in exam-day mode: hidden topic hints, 100 scored items allocated by domain followed by 25 distinct unscored items mixed into the presentation order, review-before-submit, on-screen calculator.

The exam objectives in `outline-study.json` map every displayed subtopic to stable lesson IDs, one worked example and separate check questions. `OutlineStudyTests` verifies the mappings.

The default Study tab is a sequential textbook: 6 ABO chapters (63 lessons) and 8 NCLE chapters (70 lessons). `Models/Textbook.swift` validates that the manifest covers every guide section exactly once. Update `textbook.json` when adding guide sections; preserve existing section indexes because notes and reading progress use `domain#index`. `ReadingProgress` stores per-exam last-opened lessons and explicit completion locally in UserDefaults, separately from quiz readiness; Settings reset clears it. Chapters and library resources link both ways using explicit exam/domain tags; general untagged resources remain in the main Library. Erin’s Study Binder remains on the reference shelf.

Questions and lessons link both ways through `Models/LessonLinks.swift`, which resolves authored checkpoint IDs first, then matches the remaining questions by text overlap. Weak automatic matches stay unlinked. Selected resources link to exact lessons in both directions. Explanations offer the lesson, Add to Cards (`PersonalCard`, reviewed with the bundled decks) and Report a Problem (a pre-filled GitHub issue). Readiness = three full-length mocks in a row at ≥75% (`Practice/MockReadiness.swift`); ABO-NCLE doesn't publish its pass mark, so keep that framing.

Tip Jar (`Settings/TipJar.swift`, linked from Settings and the bottom of Today): four StoreKit 2 consumables `com.isaaclamb.PettyOptician.tip.{coffee,lunch,celebration,generous}` ($0.99/$2.99/$4.99/$9.99). Tips unlock nothing. `PettyOptician.storekit` is the local test config (scheme + `TipJarTests`); the same IDs must exist in App Store Connect before release.

Math drills (`Models/DrillGenerator.swift`) generate questions on the fly from `OpticsMath`; their ids start with `drill-` and are excluded from per-question stats. ANSI Z80.1 content cites the 2025 edition. It differs from 2020 in two places: the new prescribed-prism tolerance (±0.33Δ up to 6Δ, ±0.5Δ above) and the progressive horizontal-prism threshold (±3.375 D → ±3.75 D).

Facts in `exams.json` / `california.json` were verified 2026-11-04 from abo-ncle.org and optometry.ca.gov; re-verify fees before release.
