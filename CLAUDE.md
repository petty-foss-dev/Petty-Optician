# petty: Optician (iOS)

Study app for the ABO Basic (spectacle) and NCLE Basic (contact lens) certification exams, with California registration guidance (SLD/CLD/RDO via the California State Board of Optometry). SwiftUI · Swift 6 · SwiftData · iOS 17+. Part of the Petty app family: follows the workspace code norms (see `../CLAUDE.md`) but uses the Petty look shared with petty: Tracker and petty: Jobs — cool-gray surfaces, teal accent `#0F7A8A` / `#4FC1C9` dark, optional pure black, standard `TabView`, no animated background or floating pill bar. The palette lives in `Core/Theme/ThemeManager.swift`; the icon is rendered by `docs/icon/render_icon.py`.

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
| `guides_*.json` | `[{id, exam, domain, title, summary, sections[{heading, body, diagram?, sources?[]}], formulas[{name, expression, notes}]}]` — guides sharing a `domain` are merged, so a pack can append lessons to an existing section |
| `resources_*.json` | `[{id, title, url, kind, exams[], domains[], author, description, free, minutes}]` — YouTube videos/playlists play in-app |
| `exams.json` / `california.json` / `diagrams.json` | single files — exam facts + official section weights, CA registration guide, diagram captions + sources |
| `glossary_*.json` | `[{id, term, definition, aliases[], exams[], domains[], source}]` — Glossary screen + search |
| `tables_*.json` | `[{id, title, exams[], domains[], columns[], rows[[String]], notes, sources[]}]` — Reference Tables; every row must have `columns.count` cells |
| `images.json` | single file — photos in `Resources/Images/` (`{id, file, title, caption, author, license, licenseURL, sourceURL, credit, exams[], domains[]}`); every photo needs a credit and license (CC BY-SA requires attribution + noting the resize), surfaced in Settings → Image Credits |

`exam` is `abo` or `ncle`. `domain` is an **official ABO-NCLE content-outline section** id from `exams.json`: ABO `abo.optics`, `abo.anatomy`, `abo.products`, `abo.instruments`, `abo.dispensing`, `abo.laws`; NCLE `ncle.anatomy`, `ncle.refraction`, `ncle.instruments`, `ncle.prefitting`, `ncle.fitting`, `ncle.dispensing`, `ncle.followup`, `ncle.regulatory`. Mock exams allocate questions by those weights; `topic` drives the per-section topic browser and search. Diagrams are drawn in code (`Diagrams/DiagramArt.swift`) keyed by id; `diagram` fields reference those ids. Guide bodies: paragraphs split by blank lines, `- ` bullets, inline `**bold**` only. IDs must be globally unique — `ContentTests` enforces this plus 4 choices, valid answer index, known sections/diagrams, and that every official section has a guide and questions. Run the tests after adding content.

Built-in trainers live in `Tools/` and are listed in `Tools/Trainers.swift` (Practice tab + Simulator Lab): ABO lensometer, frame adjusting, PD & seg height, prism & base, ANSI job check; NCLE keratometer, GP fluorescein, soft lens fit, toric rotation (LARS). Right/left always means the patient's; drawings use the optician's front view. Each trainer's generation and scoring logic is unit-tested and its rules cite sources in-app. The timed Mock Exam runs in exam-day mode: hidden topic hints, 25 unscored pretest items, review-before-submit, on-screen calculator.

Math drills (`Models/DrillGenerator.swift`) generate questions on the fly from `OpticsMath`; their ids start with `drill-` and are excluded from per-question stats. ANSI Z80.1 content cites the 2025 edition. It differs from 2020 in two places: the new prescribed-prism tolerance (±0.33Δ up to 6Δ, ±0.5Δ above) and the progressive horizontal-prism threshold (±3.375 D → ±3.75 D).

Facts in `exams.json` / `california.json` were verified 2026-11-04 from abo-ncle.org and optometry.ca.gov; re-verify fees before release.
