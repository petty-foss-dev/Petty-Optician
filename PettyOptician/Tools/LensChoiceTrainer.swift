import SwiftUI

enum LensRating: Int, Comparable, Sendable {
    case poor, acceptable, best

    static func < (lhs: LensRating, rhs: LensRating) -> Bool { lhs.rawValue < rhs.rawValue }

    var title: String {
        switch self {
        case .best: "Best"
        case .acceptable: "Acceptable"
        case .poor: "Poor"
        }
    }

    var symbol: String {
        switch self {
        case .best: "checkmark.circle.fill"
        case .acceptable: "minus.circle.fill"
        case .poor: "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .best: .green
        case .acceptable: .orange
        case .poor: .red
        }
    }
}

enum LensMaterial: String, CaseIterable, Identifiable, Sendable {
    case cr39, polycarbonate, trivex, highIndex167, highIndex174, crownGlass

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cr39: "CR-39"
        case .polycarbonate: "Polycarbonate"
        case .trivex: "Trivex"
        case .highIndex167: "1.67 high-index"
        case .highIndex174: "1.74 high-index"
        case .crownGlass: "Crown glass"
        }
    }

    /// Typical published values; high-index Abbe and density vary a little by manufacturer.
    var specs: String {
        switch self {
        case .cr39: "n 1.498 · Abbe 58 · SG 1.32"
        case .polycarbonate: "n 1.586 · Abbe ≈30 · SG 1.20"
        case .trivex: "n 1.53 · Abbe ≈45 · SG 1.11"
        case .highIndex167: "n 1.67 · Abbe ≈32 · SG ≈1.35"
        case .highIndex174: "n 1.74 · Abbe ≈32 · SG ≈1.47"
        case .crownGlass: "n 1.523 · Abbe 59 · SG 2.54"
        }
    }
}

enum LensDesign: String, CaseIterable, Identifiable, Sendable {
    case svSpherical, svAspheric, progressive, occupational, flatTop, executive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .svSpherical: "Single vision, spherical"
        case .svAspheric: "Single vision, aspheric"
        case .progressive: "Progressive"
        case .occupational: "Occupational (computer)"
        case .flatTop: "Flat-top bifocal"
        case .executive: "Executive bifocal"
        }
    }
}

enum LensTreatment: String, CaseIterable, Identifiable, Sendable {
    case antiReflective, scratchCoat, uv, photochromic, polarized, sunTint, blueLight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .antiReflective: "Anti-reflective"
        case .scratchCoat: "Scratch coat"
        case .uv: "UV protection"
        case .photochromic: "Photochromic"
        case .polarized: "Polarized"
        case .sunTint: "Gray sun tint"
        case .blueLight: "Blue-light filter"
        }
    }
}

enum FrameAdvice: String, CaseIterable, Identifiable, Sendable {
    case smaller, asChosen, deeper

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smaller: "Steer to a smaller frame"
        case .asChosen: "Chosen frame is fine"
        case .deeper: "Needs a taller B"
        }
    }
}

enum LensSource: String, CaseIterable, Sendable {
    case fda, athletes, materials, aspheric, arCoating, photochromic, polarized, lensStyles, thickness
    case faa, osha, childBifocals, occupational, shortCorridor, blueLightAAO, blueLightCochrane, aphakia

    var short: String {
        switch self {
        case .fda: "21 CFR 801.410"
        case .athletes: "AAO/AAP"
        case .materials, .aspheric, .arCoating, .photochromic, .polarized, .lensStyles: "Laramy-K"
        case .thickness: "20/20 Magazine"
        case .faa: "FAA"
        case .osha: "OSHA 1910.133"
        case .childBifocals: "MKUH (NHS)"
        case .occupational: "ABDO"
        case .shortCorridor: "Review of Ophthalmology"
        case .blueLightAAO: "AAO"
        case .blueLightCochrane: "Cochrane"
        case .aphakia: "Wikipedia: Aphakia"
        }
    }

    var link: SourceLink {
        switch self {
        case .fda: Self.link("FDA 21 CFR 801.410: Use of impact-resistant lenses in eyeglasses (eCFR)", "https://www.ecfr.gov/current/title-21/chapter-I/subchapter-H/part-801/subpart-H/section-801.410")
        case .athletes: Self.link("AAO/AAP: Protective Eyewear for Young Athletes", "https://www.aao.org/education/clinical-statement/protective-eyewear-young-athletes")
        case .materials: Self.link("Laramy-K: How to Choose Lens Material", "https://www.laramyk.com/resources/education/lens-options-and-materials/lens-materials/")
        case .aspheric: Self.link("Laramy-K: Aspheric Lenses", "https://www.laramyk.com/resources/education/lens-form-and-theory/aspheric-lenses/")
        case .arCoating: Self.link("Laramy-K: What Is an AR (Anti-Reflective) Coating?", "https://www.laramyk.com/resources/education/lens-options-and-materials/principles-of-ar-coatings/")
        case .photochromic: Self.link("Laramy-K: Photochromic Lenses", "https://www.laramyk.com/resources/education/lens-options-and-materials/photochromic-lenses/")
        case .polarized: Self.link("Laramy-K: What Are Polarized Lenses?", "https://www.laramyk.com/resources/education/lens-options-and-materials/polarized-lenses/")
        case .lensStyles: Self.link("Laramy-K: Basic Lens Styles and Types", "https://www.laramyk.com/resources/education/lens-options-and-materials/basic-lens-styles/")
        case .thickness: Self.link("20/20 Magazine: Thick or Thin? What Matters Most for Lens Thickness", "https://www.2020mag.com/article/thick-or-thin-what-matters-most-when-it-comes-to-lens-thickness")
        case .faa: Self.link("FAA: Sunglasses for Pilots", "https://www.faa.gov/pilots/safety/pilotsafetybrochures/Sunglasses.pdf")
        case .osha: Self.link("OSHA 29 CFR 1910.133: Eye and face protection", "https://www.osha.gov/laws-regs/regulations/standardnumber/1910/1910.133")
        case .childBifocals: Self.link("Milton Keynes University Hospital (NHS): Dispensing Bifocals to Children", "https://www.mkuh.nhs.uk/patient-information-leaflet/dispensing-bifocals-to-children")
        case .occupational: Self.link("ABDO Dispensing Optics: OA Corner Part 13 (occupational lenses)", "https://www.abdo.org.uk/news/oa-corner-part-13/")
        case .shortCorridor: Self.link("Review of Ophthalmology: Success with Short-Corridor Progressives", "https://www.reviewofophthalmology.com/article/success-with-short-corridor-progressives")
        case .blueLightAAO: Self.link("AAO: Should You Be Worried About Blue Light?", "https://www.aao.org/eye-health/tips-prevention/should-you-be-worried-about-blue-light")
        case .blueLightCochrane: Self.link("Cochrane Review CD013244: Blue-light filtering spectacle lenses", "https://www.cochrane.org/evidence/CD013244_blue-light-filtering-spectacle-lenses-visual-performance-macular-back-part-eye-protection-and")
        case .aphakia: Self.link("Wikipedia: Aphakia", "https://en.wikipedia.org/wiki/Aphakia")
        }
    }

    private static func link(_ title: String, _ url: String) -> SourceLink {
        SourceLink(title: title, url: URL(string: url)!)
    }
}

struct LensVerdict: Sendable {
    let rating: LensRating
    let reason: String
    let source: LensSource

    static func best(_ reason: String, _ source: LensSource) -> LensVerdict { LensVerdict(rating: .best, reason: reason, source: source) }
    static func ok(_ reason: String, _ source: LensSource) -> LensVerdict { LensVerdict(rating: .acceptable, reason: reason, source: source) }
    static func poor(_ reason: String, _ source: LensSource) -> LensVerdict { LensVerdict(rating: .poor, reason: reason, source: source) }
}

struct TreatmentRule: Sendable {
    enum Advice: Sendable {
        case essential, recommended, optional, unnecessary, avoid
    }

    let advice: Advice
    let reason: String
    let source: LensSource

    func rating(selected: Bool) -> LensRating {
        switch advice {
        case .essential: selected ? .best : .poor
        case .recommended: selected ? .best : .acceptable
        case .optional: .best
        case .unnecessary: selected ? .acceptable : .best
        case .avoid: selected ? .poor : .best
        }
    }

    var belongsInPackage: Bool { advice == .essential || advice == .recommended }

    static func essential(_ reason: String, _ source: LensSource) -> TreatmentRule { TreatmentRule(advice: .essential, reason: reason, source: source) }
    static func recommended(_ reason: String, _ source: LensSource) -> TreatmentRule { TreatmentRule(advice: .recommended, reason: reason, source: source) }
    static func optional(_ reason: String, _ source: LensSource) -> TreatmentRule { TreatmentRule(advice: .optional, reason: reason, source: source) }
    static func unnecessary(_ reason: String, _ source: LensSource) -> TreatmentRule { TreatmentRule(advice: .unnecessary, reason: reason, source: source) }
    static func avoid(_ reason: String, _ source: LensSource) -> TreatmentRule { TreatmentRule(advice: .avoid, reason: reason, source: source) }
}

struct LensChoiceCase: Identifiable, Sendable {
    enum Pair: Sendable {
        case everyday, sun

        var title: String { self == .sun ? "Sun pair" : "Everyday pair" }
    }

    let id: String
    let patient: String
    let rx: String
    let details: String
    let pair: Pair
    let materials: [LensMaterial: LensVerdict]
    let designs: [LensDesign: LensVerdict]
    let treatments: [LensTreatment: TreatmentRule]
    let frames: [FrameAdvice: LensVerdict]

    /// `treatments` overrides the defaults for the pair type.
    init(
        id: String, patient: String, rx: String, details: String, pair: Pair = .everyday,
        materials: [LensMaterial: LensVerdict], designs: [LensDesign: LensVerdict],
        treatments: [LensTreatment: TreatmentRule] = [:], frames: [FrameAdvice: LensVerdict]
    ) {
        self.id = id
        self.patient = patient
        self.rx = rx
        self.details = details
        self.pair = pair
        self.materials = materials
        self.designs = designs
        self.treatments = (pair == .sun ? LensChoice.sunTreatments : LensChoice.everydayTreatments).merging(treatments) { _, override in override }
        self.frames = frames
    }

    var bestMaterial: LensMaterial? { LensMaterial.allCases.first { materials[$0]?.rating == .best } }
    var bestDesign: LensDesign? { LensDesign.allCases.first { designs[$0]?.rating == .best } }
    var bestFrame: FrameAdvice? { FrameAdvice.allCases.first { frames[$0]?.rating == .best } }
    var packageTreatments: [LensTreatment] { LensTreatment.allCases.filter { treatments[$0]?.belongsInPackage == true } }
}

struct LensFeedback: Identifiable, Sendable {
    let id: String
    let category: String
    let choice: String
    let rating: LensRating
    let reason: String
    let source: LensSource
}

struct LensChoiceResult: Sendable {
    let items: [LensFeedback]

    var overall: LensRating { items.map(\.rating).min() ?? .best }

    var sources: [SourceLink] {
        var seen: Set<LensSource> = []
        return items.compactMap { seen.insert($0.source).inserted ? $0.source.link : nil }
    }
}

enum LensChoice {
    nonisolated static func grade(
        _ lensCase: LensChoiceCase, material: LensMaterial, design: LensDesign,
        treatments: Set<LensTreatment>, frame: FrameAdvice
    ) -> LensChoiceResult {
        func item(_ id: String, _ category: String, _ choice: String, _ verdict: LensVerdict) -> LensFeedback {
            LensFeedback(id: id, category: category, choice: choice, rating: verdict.rating, reason: verdict.reason, source: verdict.source)
        }
        var items = [
            item("material", "Material", material.title, lensCase.materials[material]!),
            item("design", "Design", design.title, lensCase.designs[design]!),
            item("frame", "Frame", frame.title, lensCase.frames[frame]!),
        ]
        for treatment in LensTreatment.allCases {
            let rule = lensCase.treatments[treatment]!
            let selected = treatments.contains(treatment)
            items.append(LensFeedback(
                id: "treatment.\(treatment.rawValue)", category: treatment.title, choice: selected ? "Added" : "Left off",
                rating: rule.rating(selected: selected), reason: rule.reason, source: rule.source
            ))
        }
        return LensChoiceResult(items: items)
    }

    nonisolated static func singleVision(spherical: LensVerdict, aspheric: LensVerdict) -> [LensDesign: LensVerdict] {
        let noAdd = LensVerdict.poor("There's no add in this Rx, so a multifocal zone has nothing to do.", .lensStyles)
        return [.svSpherical: spherical, .svAspheric: aspheric, .progressive: noAdd, .occupational: noAdd, .flatTop: noAdd, .executive: noAdd]
    }

    nonisolated static let everydayTreatments: [LensTreatment: TreatmentRule] = [
        .antiReflective: .recommended("Cuts reflections, ghost images and glare from screens and headlights.", .arCoating),
        .scratchCoat: .recommended("Plastic lenses scratch easily; a hard coat protects them and is normally applied under AR.", .arCoating),
        .uv: .recommended("Every pair should block UV. Poly, Trivex and high-index block it on their own; CR-39 lets a little UVA through and glass much more.", .materials),
        .photochromic: .optional("Fine either way: it darkens outdoors and clears indoors, though standard types barely darken in a car.", .photochromic),
        .polarized: .avoid("This is the everyday clear pair. Polarized lenses are sun lenses, too dark indoors and at night.", .polarized),
        .sunTint: .avoid("This is the everyday clear pair. A sun tint is too dark indoors and at night; make sunglasses a second pair.", .faa),
        .blueLight: .unnecessary("Harmless, but the AAO doesn't recommend blue-light lenses and they haven't been shown to ease eye strain.", .blueLightAAO),
    ]

    nonisolated static let sunTreatments: [LensTreatment: TreatmentRule] = [
        .antiReflective: .recommended("Back-surface AR stops light bouncing off the inside of a dark lens into the eye.", .arCoating),
        .scratchCoat: .recommended("Plastic lenses scratch easily; a hard coat protects them and is normally applied under AR.", .arCoating),
        .uv: .essential("Sunglasses must block UV; a dark lens without it lets the pupil open wider to more UV.", .faa),
        .photochromic: .unnecessary("A sun pair is dark already; photochromic adds cost and standard types barely darken in a car.", .photochromic),
        .polarized: .recommended("Polarized lenses block glare reflected off roads, water and snow.", .polarized),
        .sunTint: .recommended("A neutral gray tint cuts brightness with the least color distortion.", .faa),
        .blueLight: .unnecessary("Adds little behind a sun tint.", .blueLightCochrane),
    ]

    nonisolated static let cases: [LensChoiceCase] = [
        LensChoiceCase(
            id: "child-soccer",
            patient: "9-year-old soccer player",
            rx: "OD −6.00 DS · OS −6.00 DS",
            details: "These are his only glasses; he wears them at recess and soccer practice (games call for separate ASTM F803 sports eyewear). He wants a big frame like his dad's.",
            materials: [
                .polycarbonate: .best("The most impact-resistant lens and the AAO/AAP choice for children and sports; thinner than Trivex at −6.00.", .athletes),
                .trivex: .ok("Just as suitable for impact, lighter and with a better Abbe value, but a little thicker at −6.00.", .materials),
                .cr39: .poor("Weaker on impact; AAO/AAP say CR-39 shouldn't be used for sports eyewear.", .athletes),
                .highIndex167: .poor("Thinner, but not the impact protection a child in sports needs. Stick with poly or Trivex.", .athletes),
                .highIndex174: .poor("Thinnest, but not an impact material for a child's sports glasses.", .athletes),
                .crownGlass: .poor("Heavy and not impact resistant: never for a child or for sports.", .materials),
            ],
            designs: singleVision(
                spherical: .ok("Works, but a steeper, bulgier lens with thicker edges than aspheric at −6.00.", .aspheric),
                aspheric: .best("Flatter and thinner at the edge, with clearer vision off-center at this power.", .aspheric)
            ),
            treatments: [
                .scratchCoat: .essential("Polycarbonate is soft and scratches fast without a hard coat, and kids are hard on lenses.", .materials),
            ],
            frames: [
                .smaller: .best("Minus edges grow with decentration: a small frame whose PD matches his keeps them thin and the glasses stay put.", .thickness),
                .asChosen: .poor("A big frame on −6.00 means thick, heavy edges that slide down a small nose.", .thickness),
                .deeper: .poor("A taller lens is more thick minus edge.", .thickness),
            ]
        ),
        LensChoiceCase(
            id: "toddler-plus",
            patient: "2-year-old hyperope, always climbing",
            rx: "OD +4.50 DS · OS +4.50 DS",
            details: "Just started climbing and drops everything. The parents chose a small flexible frame with a head strap.",
            materials: [
                .trivex: .best("Impact resistant like poly, but the lightest material (SG 1.11) with a better Abbe value: ideal on a tiny nose.", .materials),
                .polycarbonate: .ok("Fully impact resistant and the classic children's lens; slightly heavier and lower Abbe.", .athletes),
                .cr39: .poor("Not impact resistant enough for a child.", .athletes),
                .highIndex167: .poor("Not an impact material for a toddler.", .athletes),
                .highIndex174: .poor("Not an impact material, and nothing to gain at +4.50.", .athletes),
                .crownGlass: .poor("Heavy and breakable: never for a child.", .materials),
            ],
            designs: singleVision(
                spherical: .ok("Works, but bulgier and heavier at +4.50.", .aspheric),
                aspheric: .best("Flatter and thinner in the center, with better off-axis vision at +4.50.", .aspheric)
            ),
            treatments: [
                .scratchCoat: .essential("Trivex is soft; toddlers scratch lenses within days without a hard coat.", .materials),
            ],
            frames: [
                .asChosen: .best("Small, flexible and strapped on: right for a toddler, and it keeps the plus lenses thin.", .thickness),
                .smaller: .ok("It's already small; any smaller and the eyes start to fall outside the lenses.", .thickness),
                .deeper: .poor("A bigger lens makes a thicker, heavier plus lens on a toddler.", .thickness),
            ]
        ),
        LensChoiceCase(
            id: "accommodative-esotropia",
            patient: "6-year-old with accommodative esotropia",
            rx: "OD +3.00 DS · OS +3.00 DS · Add +2.50",
            details: "High AC/A: the eyes are straight at distance with the full plus but still cross at near. Chose a round frame with a 30 mm B.",
            materials: [
                .polycarbonate: .best("Impact resistant and the standard children's lens.", .athletes),
                .trivex: .ok("Equally impact resistant, lighter, with better optics.", .materials),
                .cr39: .poor("Not impact resistant enough for a child.", .athletes),
                .highIndex167: .poor("Not an impact material for a child.", .athletes),
                .highIndex174: .poor("Not an impact material for a child.", .athletes),
                .crownGlass: .poor("Heavy and breakable: never for a child.", .materials),
            ],
            designs: [
                .executive: .best("The segment spans the lens, set at or just below the pupil center, so the child can't look around it.", .childBifocals),
                .flatTop: .ok("A large D-seg set high works; a small one lets the child peek around it.", .childBifocals),
                .progressive: .ok("Some prescribers use them, but the full add sits low and is easy to avoid; a high-set bifocal is the classic choice.", .childBifocals),
                .occupational: .poor("No usable distance zone for a child at school and play.", .lensStyles),
                .svSpherical: .poor("No add, so the eyes still cross at near.", .childBifocals),
                .svAspheric: .poor("No add, so the eyes still cross at near.", .childBifocals),
            ],
            treatments: [
                .scratchCoat: .essential("Polycarbonate is soft and needs a hard coat on a child.", .materials),
            ],
            frames: [
                .asChosen: .best("A 30 mm B leaves room for a segment at the pupil with distance above it.", .childBifocals),
                .smaller: .poor("A shallow frame has no room for a high segment and a distance zone.", .childBifocals),
                .deeper: .ok("Fine, but this frame already has enough depth.", .childBifocals),
            ]
        ),
        LensChoiceCase(
            id: "first-progressive",
            patient: "56-year-old office manager, first multifocal",
            rx: "OD +1.25 −0.50 × 090 · OS +1.25 −0.50 × 090 · Add +2.00",
            details: "Wants one pair for driving, the computer and reading, and doesn't want lines. Chose a slim frame with a 24 mm B; fitting height 14 mm.",
            materials: [
                .cr39: .best("Low power and no impact needs: CR-39 gives the best optics (Abbe 58) at the lowest cost.", .materials),
                .trivex: .ok("Light with good optics, but more cost than this Rx needs.", .materials),
                .polycarbonate: .ok("Fine at this power, though Abbe ≈30 can show color fringes off-axis.", .materials),
                .highIndex167: .ok("Works, but no real thickness benefit at +1.25 for the cost and extra reflections.", .materials),
                .highIndex174: .ok("Works, but the most expensive material for no benefit at +1.25.", .materials),
                .crownGlass: .ok("Great optics and scratch resistance, but about twice the weight of plastic and not impact resistant.", .materials),
            ],
            designs: [
                .progressive: .best("No lines, with distance, computer and reading zones in one pair.", .lensStyles),
                .flatTop: .ok("Works with a wide reading area, but has the line she doesn't want and no intermediate zone.", .lensStyles),
                .executive: .poor("A line across the whole lens and no intermediate: the opposite of a no-lines request.", .lensStyles),
                .occupational: .poor("No proper distance zone, so she can't drive in it.", .occupational),
                .svSpherical: .poor("Single vision means two pairs, and she wants one.", .lensStyles),
                .svAspheric: .poor("Single vision means two pairs, and she wants one.", .lensStyles),
            ],
            frames: [
                .deeper: .best("Allow the fitting height plus about 10 mm of distance zone: a 24 mm B with a 14 mm fit allows only the shortest corridors.", .shortCorridor),
                .asChosen: .ok("A short-corridor design fits a B of 24 mm or more, but the reading area is small for a first-time wearer.", .shortCorridor),
                .smaller: .poor("Any shallower and no progressive fits.", .shortCorridor),
            ]
        ),
        LensChoiceCase(
            id: "computer-occupational",
            patient: "61-year-old accountant at two monitors",
            rx: "OD +0.75 DS · OS +0.75 DS · Add +2.50",
            details: "Already wears progressives. Works 8 hours a day at two monitors at eye level and has a sore neck from tipping her chin up to see them. Wants a desk pair; chose a frame with a 32 mm B.",
            materials: [
                .cr39: .best("Low power, indoor pair: CR-39 has the best optics at the lowest cost.", .materials),
                .trivex: .ok("Light with good optics, but more cost than needed.", .materials),
                .polycarbonate: .ok("Fine at this power, though its low Abbe gives nothing back.", .materials),
                .highIndex167: .ok("Works, but no benefit at +0.75 for the cost.", .materials),
                .highIndex174: .ok("Works, but no benefit at +0.75 for the cost.", .materials),
                .crownGlass: .ok("Great optics, but heavy for all-day wear.", .materials),
            ],
            designs: [
                .occupational: .best("Gives up distance for wide intermediate and near zones placed for the screens and desk: no chin-lifting.", .occupational),
                .svSpherical: .ok("A single-vision lens for screen distance clears both monitors but blurs the papers on the desk.", .occupational),
                .svAspheric: .ok("A single-vision lens for screen distance clears both monitors but blurs the papers on the desk.", .occupational),
                .flatTop: .ok("Only works made as an intermediate/near bifocal; a standard distance/near one leaves the screens blurry.", .occupational),
                .executive: .ok("Only works made as an intermediate/near bifocal; a standard distance/near one leaves the screens blurry.", .occupational),
                .progressive: .poor("That's the lens causing the neck ache: its intermediate zone is narrow and low.", .occupational),
            ],
            treatments: [
                .antiReflective: .recommended("Cuts reflections from overhead lights and screens: the coating that actually helps at a computer.", .arCoating),
                .photochromic: .unnecessary("An indoor pair: photochromics stay clear indoors, so it adds cost for nothing.", .photochromic),
                .polarized: .avoid("Polarized lenses can make LCD monitors look dim or black at some angles.", .polarized),
                .blueLight: .unnecessary("A Cochrane review found blue-light lenses may not reduce eye strain from computer work.", .blueLightCochrane),
            ],
            frames: [
                .asChosen: .best("A 32 mm B gives the office lens room for wide zones.", .occupational),
                .smaller: .poor("A shallow frame squeezes the intermediate and near zones this lens is for.", .occupational),
                .deeper: .ok("Fine, but this frame is deep enough already.", .occupational),
            ]
        ),
        LensChoiceCase(
            id: "rimless-drill",
            patient: "34-year-old choosing a rimless drill mount",
            rx: "OD −4.50 −0.75 × 180 · OS −4.50 −0.75 × 180",
            details: "Loves a three-piece rimless frame held by screws through drilled holes. Moderate lens shape.",
            materials: [
                .trivex: .best("High tensile strength resists cracking at the drill holes: the textbook drill-mount material.", .materials),
                .polycarbonate: .ok("Impact resistant and a little thinner, but prone to stress cracks around drill holes.", .materials),
                .highIndex167: .ok("Thinner visible edges and it drills well, but it is less impact resistant than Trivex.", .materials),
                .highIndex174: .ok("Thinnest edges, but more prone to chipping, and some labs won't drill it.", .materials),
                .cr39: .poor("Brittle at the holes: it chips and cracks in drill mounts.", .materials),
                .crownGlass: .poor("Heavy and not impact resistant; holes start cracks.", .materials),
            ],
            designs: singleVision(
                spherical: .ok("Works, but steeper with thicker visible edges than aspheric.", .aspheric),
                aspheric: .best("Flatter and thinner at the edge, which shows in a rimless mount.", .aspheric)
            ),
            treatments: [
                .antiReflective: .recommended("Rimless lenses are all on show; AR cuts surface reflections and edge glare.", .arCoating),
                .scratchCoat: .essential("Trivex is soft and needs a hard coat, which also goes under AR.", .materials),
            ],
            frames: [
                .asChosen: .best("Rimless shapes are cut to order; a moderate shape is fine at −4.50.", .thickness),
                .smaller: .ok("A smaller shape gives thinner edges, but it isn't necessary here.", .thickness),
                .deeper: .ok("A taller shape shows thicker minus edges in a rimless mount.", .thickness),
            ]
        ),
        LensChoiceCase(
            id: "pilot-sun",
            patient: "44-year-old airline pilot",
            rx: "OD −1.25 DS · OS −1.25 DS",
            details: "Wants prescription sunglasses for the flight deck, which has LCD displays. Chose a full-size metal aviator with thin temples that clear the headset.",
            pair: .sun,
            materials: [
                .trivex: .best("Impact resistant against bird strike or decompression debris, the lightest material, tints well, with good optics.", .materials),
                .polycarbonate: .ok("The most impact-resistant lens, but it doesn't take dye as readily and its Abbe is low.", .faa),
                .cr39: .ok("Excellent optics and tints well, but less impact resistant than poly or Trivex.", .faa),
                .highIndex167: .ok("Works, but more reflections and a lower Abbe for nothing at −1.25.", .materials),
                .highIndex174: .ok("Works, but more reflections and a lower Abbe for nothing at −1.25.", .materials),
                .crownGlass: .ok("Superb optics and scratch resistance, but heavier and less impact resistant than plastic.", .faa),
            ],
            designs: singleVision(
                spherical: .best("Low power: a spherical lens performs well.", .aspheric),
                aspheric: .ok("Fine, but adds little at −1.25.", .aspheric)
            ),
            treatments: [
                .sunTint: .essential("Neutral gray, blocking 70–85% of light, is the FAA's recommended tint.", .faa),
                .polarized: .avoid("FAA: polarization can hide instruments that use anti-glare filters and shows windscreen striations.", .faa),
                .photochromic: .avoid("FAA: not recommended; reduced UV in the cockpit limits darkening, and fading back is slow.", .faa),
                .blueLight: .unnecessary("Adds nothing behind gray; amber blue-blocker tints distort signal and display colors, so the FAA advises against them.", .faa),
            ],
            frames: [
                .asChosen: .best("Full-size lenses on thin temples that clear the headset are what the FAA describes.", .faa),
                .smaller: .poor("Small lenses let light and UV in around the edges.", .faa),
                .deeper: .ok("Fine if it still clears the headset; more coverage is good.", .faa),
            ]
        ),
        LensChoiceCase(
            id: "machinist-safety",
            patient: "31-year-old CNC machinist",
            rx: "OD −2.50 −0.50 × 180 · OS −2.50 −0.50 × 180",
            details: "His employer requires prescription safety glasses to ANSI Z87.1. Chose a Z87-2+ marked safety frame with permanent side shields.",
            materials: [
                .polycarbonate: .best("The most impact-resistant lens and the standard for high-impact prescription safety eyewear.", .materials),
                .trivex: .ok("Also an impact material with better optics; costs more.", .materials),
                .cr39: .poor("Not a high-impact material; flying chips call for poly or Trivex.", .athletes),
                .highIndex167: .poor("Not a high-impact safety material.", .materials),
                .highIndex174: .poor("Not a high-impact safety material.", .materials),
                .crownGlass: .poor("Not impact resistant: never for flying-particle hazards.", .materials),
            ],
            designs: singleVision(
                spherical: .best("Low power: a spherical lens performs well.", .aspheric),
                aspheric: .ok("Fine, but adds little at −2.50.", .aspheric)
            ),
            treatments: [
                .scratchCoat: .essential("Shop grit scratches polycarbonate quickly; a hard coat is essential.", .materials),
                .photochromic: .unnecessary("An indoor shop: photochromics stay clear indoors, so it adds nothing.", .photochromic),
                .polarized: .avoid("Indoors, and polarization can black out the machine's LCD control panel.", .polarized),
            ],
            frames: [
                .asChosen: .best("Rx safety lenses only count in a frame built for the hazard; OSHA requires side protection against flying particles.", .osha),
                .smaller: .ok("Fine only if it's still a marked safety frame with side shields.", .osha),
                .deeper: .ok("Fine only if it's still a marked safety frame with side shields.", .osha),
            ]
        ),
        LensChoiceCase(
            id: "aphakic-high-plus",
            patient: "46-year-old aphakic patient",
            rx: "OD +11.00 DS · OS +11.00 DS (distance pair)",
            details: "Aphakic in both eyes since childhood cataract surgery and can't tolerate contacts. Current CR-39 spherical lenses are heavy and the world swims at the edges. Likes a large, wide frame.",
            materials: [
                .highIndex167: .best("Thinner and lighter than lower indexes and widely made in high-plus aspheric designs.", .materials),
                .highIndex174: .ok("Thinnest, but costly and offered in fewer plus powers.", .materials),
                .polycarbonate: .ok("Thinner and lighter than CR-39, but Abbe ≈30 shows color fringes in a lens this strong.", .materials),
                .trivex: .ok("The lightest material, but at index 1.53 the center is still thick.", .materials),
                .cr39: .poor("What they wear now: the thickest, heaviest plastic at +11.00.", .materials),
                .crownGlass: .poor("By far the heaviest material (SG 2.54).", .materials),
            ],
            designs: singleVision(
                spherical: .poor("Above about +8.00 there's no good spherical form: thick, heavy and distorted off-center, the \"swim\" complaint.", .aspheric),
                aspheric: .best("Above about +8.00 an aspheric form is needed for usable off-axis vision, and it's flatter and thinner.", .aspheric)
            ),
            treatments: [
                .uv: .essential("With no crystalline lens, UV reaches the retina unfiltered; UV blocking is a must.", .aphakia),
                .scratchCoat: .essential("High-index lenses need a hard coat, which also goes under AR.", .arCoating),
            ],
            frames: [
                .smaller: .best("A small, round frame whose PD matches theirs keeps a +11.00 lens as thin, light and undistorted as possible.", .thickness),
                .asChosen: .poor("A large frame makes a much thicker, heavier plus lens with more edge distortion.", .thickness),
                .deeper: .poor("More lens means more thickness and weight at +11.00.", .thickness),
            ]
        ),
        LensChoiceCase(
            id: "high-minus",
            patient: "27-year-old high myope",
            rx: "OD −9.00 −0.50 × 180 · OS −9.00 −0.50 × 180",
            details: "Hates his thick edges and how small his eyes look through his glasses. Chose a large frame.",
            materials: [
                .highIndex174: .best("The thinnest plastic, and the stronger the minus the more each step up in index thins the edge.", .thickness),
                .highIndex167: .ok("Thin and a common choice, a bit thicker than 1.74.", .thickness),
                .polycarbonate: .ok("Thinner than CR-39, but much thicker than high-index at −9.00, and Abbe ≈30.", .materials),
                .trivex: .poor("At index 1.53 the edges stay thick: it doesn't fix the complaint.", .materials),
                .cr39: .poor("The thickest edges: the opposite of what he wants.", .thickness),
                .crownGlass: .poor("Thick and very heavy at −9.00.", .materials),
            ],
            designs: singleVision(
                spherical: .ok("Works, but a steeper, bulgier lens with thicker edges than aspheric.", .aspheric),
                aspheric: .best("Flatter and thinner at the edge with better off-axis vision; most high-index lenses are aspheric.", .aspheric)
            ),
            treatments: [
                .antiReflective: .essential("High-index lenses reflect more light than other lenses; AR removes the rings and glare.", .arCoating),
                .scratchCoat: .essential("High-index lenses need a hard coat, which also goes under AR.", .arCoating),
            ],
            frames: [
                .smaller: .best("Decentration drives minus edge thickness most: a small frame whose PD matches his gives the thinnest edges.", .thickness),
                .asChosen: .poor("A large frame means more decentration and thick edges, whatever the material.", .thickness),
                .deeper: .poor("A taller lens is more thick minus edge.", .thickness),
            ]
        ),
        LensChoiceCase(
            id: "chromatic-poly",
            patient: "36-year-old with color fringes",
            rx: "OD −3.50 −0.50 × 010 · OS −3.50 −0.50 × 010",
            details: "New polycarbonate glasses. Sees colored fringes around signs and lights when looking off to the side. PD and optical centers check out.",
            materials: [
                .cr39: .best("Abbe 58 has about half the chromatic aberration of poly, and the thickness is fine at −3.50.", .materials),
                .trivex: .ok("Abbe ≈45 is a big step up from poly and lighter than CR-39.", .materials),
                .crownGlass: .ok("Abbe 59, but more than twice as heavy and not impact resistant.", .materials),
                .polycarbonate: .poor("Abbe ≈30 is what's causing the fringes.", .materials),
                .highIndex167: .poor("Abbe ≈32 is barely better than poly.", .materials),
                .highIndex174: .poor("Abbe ≈32 is barely better than poly, and not needed at −3.50.", .materials),
            ],
            designs: singleVision(
                spherical: .best("A best-form spherical lens performs well at −3.50.", .aspheric),
                aspheric: .ok("Fine; flatter, but adds little at this power.", .aspheric)
            ),
            frames: [
                .asChosen: .best("The frame isn't the problem; the material is.", .materials),
                .smaller: .ok("Fine, but it won't fix a material problem.", .materials),
                .deeper: .ok("Fine, but bigger lenses invite more off-center viewing, where fringing is worst.", .materials),
            ]
        ),
        LensChoiceCase(
            id: "driving-photochromic",
            patient: "41-year-old commuter",
            rx: "OD −2.25 DS · OS −2.25 DS",
            details: "Her photochromic glasses barely darken in the car. Wants sunglasses for driving into the sun and the glare off wet roads. Chose a medium sunglass frame.",
            pair: .sun,
            materials: [
                .cr39: .best("Tints and polarizes well with the best optics at a low price.", .materials),
                .polycarbonate: .ok("Impact resistant and widely made polarized, but lower Abbe.", .materials),
                .trivex: .ok("Light with good optics; more cost than needed.", .materials),
                .highIndex167: .ok("Works, but no benefit at −2.25.", .materials),
                .highIndex174: .ok("Works, but no benefit at −2.25.", .materials),
                .crownGlass: .ok("Glass polarized lenses are very clear, but heavy and not impact resistant.", .materials),
            ],
            designs: singleVision(
                spherical: .best("Low power: a spherical lens performs well.", .aspheric),
                aspheric: .ok("Fine, but adds little at −2.25.", .aspheric)
            ),
            treatments: [
                .polarized: .essential("Blocks glare off wet roads and car hoods: the real fix for her driving complaint.", .polarized),
                .sunTint: .optional("Polarized lenses are already tinted; a plain tint alone cuts brightness but not road glare.", .polarized),
                .photochromic: .unnecessary("Standard photochromics need UV, which windshields block; only visible-light types like XTRActive darken partly in the car.", .photochromic),
            ],
            frames: [
                .asChosen: .best("A medium sunglass frame covers the eyes well.", .faa),
                .smaller: .ok("Works, but small lenses let light in around the edges.", .faa),
                .deeper: .ok("Fine; more coverage is good in sunglasses.", .faa),
            ]
        ),
        LensChoiceCase(
            id: "fishing-progressive",
            patient: "57-year-old fly fisher",
            rx: "OD +1.00 DS · OS +1.00 DS · Add +2.00",
            details: "Wants fishing sunglasses to spot fish under the surface glare and to tie flies on the line. Chose a sport frame with a 30 mm B.",
            pair: .sun,
            materials: [
                .polycarbonate: .best("Impact resistant against stray hooks and sinkers, light, and widely made in polarized progressives.", .materials),
                .trivex: .ok("Impact resistant, lighter and with better optics: an equally good outdoor choice.", .materials),
                .cr39: .ok("Great optics and polarizes well, but less impact resistant around flying hooks.", .materials),
                .highIndex167: .ok("Works, but no benefit at this power.", .materials),
                .highIndex174: .ok("Works, but no benefit at this power.", .materials),
                .crownGlass: .ok("Glass polarized lenses are prized for clarity and scratch resistance, but heavy and not impact resistant.", .materials),
            ],
            designs: [
                .progressive: .best("Distance for spotting fish and near for tying flies, with no line.", .lensStyles),
                .flatTop: .ok("Works with a wide near area, but the line gets in the way outdoors.", .lensStyles),
                .executive: .ok("Wide near, but heavy with a line across the whole lens.", .lensStyles),
                .occupational: .poor("No distance zone: he can't spot fish across the water.", .occupational),
                .svSpherical: .poor("Distance only: no way to tie flies without readers.", .lensStyles),
                .svAspheric: .poor("Distance only: no way to tie flies without readers.", .lensStyles),
            ],
            treatments: [
                .polarized: .essential("Cuts glare off the water's surface so he can see below it: the whole point of fishing sunglasses.", .polarized),
                .sunTint: .optional("Polarized lenses are already tinted; a plain tint alone won't cut water glare.", .polarized),
            ],
            frames: [
                .asChosen: .best("A 30 mm B leaves room for the progressive's distance and reading zones.", .shortCorridor),
                .smaller: .poor("A shallow sun frame cuts off the reading zone he needs for tying flies.", .shortCorridor),
                .deeper: .ok("Fine, but this frame is deep enough already.", .shortCorridor),
            ]
        ),
        LensChoiceCase(
            id: "monocular",
            patient: "53-year-old, functionally one-eyed",
            rx: "OD −2.75 DS · OS −3.00 DS · Add +1.75",
            details: "Amblyopic OS, best-corrected 20/200. Happy progressive wearer; office job and weekend woodworking. Chose a frame with a 30 mm B.",
            materials: [
                .polycarbonate: .best("The good eye must be protected: anyone functionally one-eyed belongs in the most impact-resistant lens.", .athletes),
                .trivex: .ok("The same class of impact protection with better optics: equally sound.", .materials),
                .cr39: .poor("Not impact resistant enough to protect the only good eye.", .athletes),
                .highIndex167: .poor("Not an impact material for a one-eyed patient.", .athletes),
                .highIndex174: .poor("Not an impact material for a one-eyed patient.", .athletes),
                .crownGlass: .poor("Not impact resistant: never for a one-eyed patient.", .materials),
            ],
            designs: [
                .progressive: .best("Already adapted to progressives: one pair for everything.", .lensStyles),
                .flatTop: .ok("Works, but there's no reason to move him off progressives.", .lensStyles),
                .executive: .ok("Works, but heavy and visible, with no reason to switch.", .lensStyles),
                .occupational: .poor("No distance zone for everyday wear.", .occupational),
                .svSpherical: .poor("Ignores the add, so he'd juggle readers.", .lensStyles),
                .svAspheric: .poor("Ignores the add, so he'd juggle readers.", .lensStyles),
            ],
            treatments: [
                .scratchCoat: .essential("Polycarbonate is soft and needs a hard coat.", .materials),
            ],
            frames: [
                .asChosen: .best("A 30 mm B fits a standard progressive. For woodworking, add Z87-2+ safety glasses with side shields.", .osha),
                .smaller: .ok("Fine only if the B still leaves room for the corridor.", .shortCorridor),
                .deeper: .ok("Fine, but this frame is deep enough already.", .shortCorridor),
            ]
        ),
        LensChoiceCase(
            id: "progressive-nonadapt",
            patient: "66-year-old who couldn't adapt to progressives",
            rx: "OD +2.00 DS · OS +2.00 DS · Add +2.50",
            details: "Felt dizzy and swimmy in two different progressives. Mostly reads, sews and plays cards at the table and wants one pair. Chose a frame with a 32 mm B.",
            materials: [
                .cr39: .best("Moderate plus and no impact needs: the best optics at the lowest cost.", .materials),
                .trivex: .ok("Light with good optics, but more cost than needed.", .materials),
                .polycarbonate: .ok("Fine, though its low Abbe gives nothing back here.", .materials),
                .highIndex167: .ok("Slightly thinner, but not needed at +2.00.", .materials),
                .highIndex174: .ok("Not needed at +2.00, and costly.", .materials),
                .crownGlass: .ok("Great optics and scratch resistance, but heavy.", .materials),
            ],
            designs: [
                .flatTop: .best("A wide, distortion-free reading zone with no swim; an FT-28 or FT-35 is the usual answer.", .lensStyles),
                .executive: .ok("The widest reading area, but heavy, thick and lined across the whole lens.", .lensStyles),
                .occupational: .ok("Good at the table, but no real distance zone for walking around or TV.", .occupational),
                .progressive: .poor("Two failures already: a third progressive is unlikely to work.", .lensStyles),
                .svSpherical: .poor("She wants distance and reading in one pair.", .lensStyles),
                .svAspheric: .poor("She wants distance and reading in one pair.", .lensStyles),
            ],
            frames: [
                .asChosen: .best("A 32 mm B leaves plenty of room for the segment.", .lensStyles),
                .smaller: .ok("Fine if it still leaves room for the segment.", .lensStyles),
                .deeper: .ok("Fine, but this frame is deep enough already.", .lensStyles),
            ]
        ),
        LensChoiceCase(
            id: "student-blue-light",
            patient: "21-year-old student, first glasses",
            rx: "OD −1.00 DS · OS −1.00 DS",
            details: "On a laptop 10 hours a day. Asks for blue-light lenses because a video said screens damage the retina. Tight budget.",
            materials: [
                .cr39: .best("Low Rx and a tight budget: the best optics at the lowest price.", .materials),
                .polycarbonate: .ok("Fine and impact resistant, but costs more with a lower Abbe.", .materials),
                .trivex: .ok("Light with good optics, but more cost than needed.", .materials),
                .highIndex167: .ok("Works, but pointless at −1.00 for the price.", .materials),
                .highIndex174: .ok("Works, but pointless at −1.00 for the price.", .materials),
                .crownGlass: .ok("Clear and scratch resistant, but heavy and not impact resistant.", .materials),
            ],
            designs: singleVision(
                spherical: .best("Low power: a spherical lens performs well.", .aspheric),
                aspheric: .ok("Fine, but adds little at −1.00.", .aspheric)
            ),
            treatments: [
                .blueLight: .unnecessary("No evidence screen blue light damages the eye, and the AAO doesn't recommend these lenses; fine if she insists.", .blueLightAAO),
                .antiReflective: .recommended("The coating that actually helps on screens: it cuts reflections and glare.", .arCoating),
            ],
            frames: [
                .asChosen: .best("Any reasonable frame works at −1.00.", .thickness),
                .smaller: .ok("Fine, but unnecessary at −1.00.", .thickness),
                .deeper: .ok("Fine at −1.00.", .thickness),
            ]
        ),
    ]
}

struct LensChoiceTrainerView: View {
    @State private var order = LensChoice.cases.indices.shuffled()
    @State private var position = 0
    @State private var material: LensMaterial?
    @State private var design: LensDesign?
    @State private var treatments: Set<LensTreatment> = []
    @State private var frame: FrameAdvice?
    @State private var result: LensChoiceResult?
    @State private var correctCount = 0
    @State private var attempts = 0
    @State private var showingHelp = false
    @Environment(\.palette) private var palette

    private var lensCase: LensChoiceCase { LensChoice.cases[order[position]] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                casePanel

                choiceGroup("Material", options: LensMaterial.allCases, title: \.title, isSelected: { material == $0 }) { material = $0 }
                if let material {
                    Text(material.specs)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(palette.secondaryText)
                }
                choiceGroup("Lens design", options: LensDesign.allCases, title: \.title, isSelected: { design == $0 }) { design = $0 }
                choiceGroup("Treatments", options: LensTreatment.allCases, title: \.title, isSelected: { treatments.contains($0) }) { treatment in
                    if treatments.contains(treatment) { treatments.remove(treatment) } else { treatments.insert(treatment) }
                }
                choiceGroup("Frame advice", options: FrameAdvice.allCases, title: \.title, isSelected: { frame == $0 }) { frame = $0 }

                if let result {
                    resultPanel(result)
                } else {
                    Button("Check", action: check)
                        .buttonStyle(.borderedProminent)
                        .disabled(material == nil || design == nil || frame == nil)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityIdentifier("lenschoice.check")
                }

                Text("Score \(correctCount) / \(attempts)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(palette.secondaryText)

                DisclosureGroup("How it works", isExpanded: $showingHelp) {
                    VStack(alignment: .leading, spacing: 12) {
                        RichText(text: """
                        Read the patient, then pick a material, a lens design, any treatments and your frame advice. Each pick is graded **best**, **acceptable** or **poor** for this patient, with the reason and its source. A case scores when nothing is poor.

                        - **Impact:** children, sports, work safety and functionally one-eyed patients get polycarbonate or Trivex. Every US eyeglass lens must pass the FDA drop-ball test; work safety eyewear must meet ANSI Z87.1.
                        - **Thickness:** high-index and aspheric designs for strong powers, and small frames with little decentration.
                        - **Chromatic aberration:** a low Abbe value (poly, high-index) gives color fringes off-center; CR-39 and Trivex are cleaner.
                        - **Drill mounts:** Trivex resists cracking at the holes; poly can stress-crack and CR-39 chips.
                        - **Sun lenses:** polarized for road and water glare, but not for pilots. Standard photochromics need UV, which windshields block.
                        - **Multifocals:** progressives need enough frame depth below the pupil; occupational lenses trade distance for wide intermediate and near.
                        """)
                        .font(.subheadline)
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(LensMaterial.allCases) { material in
                                Text("\(material.title): \(material.specs)").font(.caption.monospacedDigit())
                            }
                        }
                        .foregroundStyle(palette.secondaryText)
                        SourceList(sources: LensSource.allCases.map(\.link))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, 8)
                }
                .tint(palette.accent)
            }
            .padding()
        }
        .pettyScreen()
        .navigationTitle("Lens Choice Trainer")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var casePanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(lensCase.patient).font(.headline)
                    Spacer()
                    Chip(text: lensCase.pair.title, selected: true)
                }
                Text(lensCase.rx).font(.subheadline.monospacedDigit())
                Text(lensCase.details)
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func choiceGroup<Option: Identifiable>(
        _ heading: String, options: [Option], title: KeyPath<Option, String>,
        isSelected: @escaping (Option) -> Bool, select: @escaping (Option) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(heading).font(.headline)
            FlowLayout {
                ForEach(options) { option in
                    Button { select(option) } label: {
                        Chip(text: option[keyPath: title], symbol: isSelected(option) ? "checkmark" : nil, selected: isSelected(option))
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(result != nil)
        }
    }

    private func resultPanel(_ result: LensChoiceResult) -> some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                Label(overallText(result.overall), systemImage: result.overall.symbol)
                    .font(.headline)
                    .foregroundStyle(result.overall.color)
                ForEach(result.items) { item in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(item.category): \(item.choice)").font(.subheadline.weight(.semibold))
                            Spacer()
                            Label(item.rating.title, systemImage: item.rating.symbol)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(item.rating.color)
                        }
                        Text("\(item.reason) (\(item.source.short))")
                            .font(.caption)
                            .foregroundStyle(palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Divider()
                Text("Best package").font(.subheadline.weight(.semibold))
                Text(packageText)
                    .font(.caption)
                    .foregroundStyle(palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                SourceList(sources: result.sources)
                Button("Next Case", action: next)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("lenschoice.next")
            }
        }
    }

    private var packageText: String {
        let treatments = lensCase.packageTreatments.map(\.title).joined(separator: ", ")
        return [
            lensCase.bestMaterial?.title,
            lensCase.bestDesign?.title,
            treatments.isEmpty ? nil : treatments,
            lensCase.bestFrame?.title,
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    private func overallText(_ rating: LensRating) -> String {
        switch rating {
        case .best: "Ideal package"
        case .acceptable: "Workable package"
        case .poor: "Needs changes"
        }
    }

    private func check() {
        guard let material, let design, let frame else { return }
        let graded = LensChoice.grade(lensCase, material: material, design: design, treatments: treatments, frame: frame)
        result = graded
        attempts += 1
        if graded.overall != .poor { correctCount += 1 }
    }

    private func next() {
        position += 1
        if position == order.count {
            order = LensChoice.cases.indices.shuffled()
            position = 0
        }
        material = nil
        design = nil
        treatments = []
        frame = nil
        result = nil
    }
}
