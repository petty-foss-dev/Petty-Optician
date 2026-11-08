import SwiftUI

/// Efron grading scale steps. Grade 0 (normal) is never shown because every eye here has a problem.
nonisolated enum EfronGrade: Int, CaseIterable, Identifiable, Sendable {
    case trace = 1, mild, moderate, severe

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .trace: "Trace"
        case .mild: "Mild"
        case .moderate: "Moderate"
        case .severe: "Severe"
        }
    }
}

nonisolated enum ComplicationView: Sendable {
    case whiteLight, cobaltBlue, evertedLid
}

nonisolated enum LensAction: String, CaseIterable, Identifiable, Sendable {
    case urgentReferral, promptReferral, higherDkRefit, breakThenFreshLenses, modifyGPEdge
    case lowerModulusRefit, changeCareSystem, loosenFit, treatDrying
    case patchOvernight, continueWear, continuousWear, tightenFit, increaseEdgeLift, rednessDrops

    var id: String { rawValue }

    var title: String {
        switch self {
        case .urgentReferral: "Remove the lenses and get the patient to the eye doctor today as an emergency. Send the lenses and case along for culture, don't patch the eye, and no lens wear until cleared."
        case .promptReferral: "Stop lens wear and have the prescriber see the patient within 24 hours to rule out infection. Resume later on daily wear only, never sleeping in lenses."
        case .higherDkRefit: "Refer to the prescriber for a refit into a higher-Dk/t lens (silicone hydrogel or GP), with shorter wearing time and no overnight wear."
        case .breakThenFreshLenses: "Stop or cut back lens wear and refer to the prescriber. When wear resumes, use daily disposables or more frequent replacement, with better lens cleaning."
        case .modifyGPEdge: "With the prescriber's approval, modify the GP lens: reduce edge lift and improve centration. Coach full blinks and add rewetting drops."
        case .lowerModulusRefit: "Stop lens wear until it heals and refer to the prescriber for a refit into a lower-modulus (more flexible) lens or a different design."
        case .changeCareSystem: "Pause wear for a few days with preservative-free drops, then change the care system to hydrogen peroxide or switch to daily disposables. Refer if it doesn't clear."
        case .loosenFit: "Remove the lens and refer to the prescriber to loosen the fit: flatter base curve, smaller diameter or a different material, with shorter wearing time."
        case .treatDrying: "Coach complete blinking, add preservative-free rewetting drops, and refer to the prescriber for a dry-eye check and a material that dries out less."
        case .patchOvernight: "Remove the lens, patch the eye closed overnight, and recheck tomorrow."
        case .continueWear: "Keep wearing the lenses as usual and recheck at the next annual exam."
        case .continuousWear: "Switch to a 30-day continuous-wear lens so the eye is handled less often."
        case .tightenFit: "Tighten the fit with a steeper base curve so the lens moves less."
        case .increaseEdgeLift: "Increase edge lift by flattening the GP peripheral curves."
        case .rednessDrops: "Recommend over-the-counter redness-relief drops and keep wearing the lenses."
        }
    }

    /// Why an option that is never the answer is wrong; options that are right for another problem return nil.
    var pitfall: String? {
        switch self {
        case .patchOvernight: "Never patch a contact lens wearer's eye: patching raises the risk of bacterial keratitis."
        case .continueWear: "A complication that is already visible needs a change, not a year of the same wear."
        case .continuousWear: "Overnight wear is the biggest risk factor for infection and makes hypoxic and inflammatory problems worse."
        case .tightenFit: "A tighter lens moves less and exchanges fewer tears, which makes nearly every complication worse."
        case .increaseEdgeLift: "More edge lift holds the lid further from the cornea, so the peripheral cornea dries even more."
        case .rednessDrops: "Decongestant drops only hide the redness that signals a problem, and they aren't meant for use with lenses."
        default: nil
        }
    }
}

nonisolated enum LensComplication: String, CaseIterable, Identifiable, Sendable {
    case neovascularization, papillaryConjunctivitis, threeNineStaining, seal, edema
    case clare, clpu, microbialKeratitis, solutionToxicity, tightLens, inferiorStaining

    var id: String { rawValue }

    var title: String {
        switch self {
        case .neovascularization: "Corneal neovascularization"
        case .papillaryConjunctivitis: "Giant papillary conjunctivitis (CLPC)"
        case .threeNineStaining: "3 and 9 o'clock staining"
        case .seal: "Superior epithelial arcuate lesion (SEAL)"
        case .edema: "Corneal edema (hypoxia)"
        case .clare: "CLARE (contact lens acute red eye)"
        case .clpu: "Contact lens peripheral ulcer (CLPU)"
        case .microbialKeratitis: "Microbial keratitis (MK)"
        case .solutionToxicity: "Solution-induced staining (toxicity)"
        case .tightLens: "Tight lens syndrome"
        case .inferiorStaining: "Inferior desiccation staining"
        }
    }

    var view: ComplicationView {
        switch self {
        case .papillaryConjunctivitis: .evertedLid
        case .threeNineStaining, .seal, .solutionToxicity, .inferiorStaining: .cobaltBlue
        default: .whiteLight
        }
    }

    var viewCaption: String {
        switch self {
        case .papillaryConjunctivitis: "Upper lid everted, white light"
        case .threeNineStaining: "Fluorescein, cobalt blue, GP lens on the eye"
        case .seal, .solutionToxicity, .inferiorStaining: "Fluorescein after lens removal, cobalt blue"
        case .tightLens: "White light, soft lens on the eye"
        default: "White light, diffuse illumination"
        }
    }

    var histories: [String] {
        switch self {
        case .neovascularization: [
            "Low-Dk hydrogel monthly lenses worn 14–16 hours a day for years. No complaints; here for a lens refill.",
            "Conventional hydrogel lenses, often napped in and sometimes slept in. Eyes feel fine.",
        ]
        case .papillaryConjunctivitis: [
            "Monthly soft lenses often stretched to two or three months. Itchy, stringy mucus in the morning; lenses feel coated by midday.",
            "Soft lens wearer who replaces lenses \"when they start to bother me.\" The lenses keep riding up after blinks.",
        ]
        case .threeNineStaining: [
            "Spherical GP lenses for six years. The whites of the eyes look red at the sides by evening.",
            "New GP wearer. Comfortable lenses, but admits to long screen sessions with few blinks.",
        ]
        case .seal: [
            "Silicone hydrogel lenses worn 30 days continuously. \"Slight scratchy feeling up top.\"",
            "Two-week silicone hydrogel lenses. No complaints; found at a routine check.",
        ]
        case .edema: [
            "Thick low-Dk hydrogel lenses slept in most nights. Foggy vision and halos in the morning.",
            "High-minus conventional hydrogel lenses worn 16 hours a day. Glasses blur for a while after the lenses come out.",
        ]
        case .clare: [
            "Slept in soft lenses last night and woke with a sore, red, watery eye. It feels better with the lens out.",
            "Extended-wear hydrogel lenses slept in all week. Woke at 5 a.m. with an aching, light-sensitive red eye.",
        ]
        case .clpu: [
            "Two-week lenses, sometimes slept in. \"Something in my eye\" on one side since this morning.",
            "Monthly lenses stretched to three months. Mild ache and a red patch on one side of the eye.",
        ]
        case .microbialKeratitis: [
            "Showers and swims in soft lenses and sometimes sleeps in them. Pain has built over a day, with blurred vision and discharge.",
            "Reusable soft lenses topped off in old solution. Severe pain since last night; can't keep the eye open in light.",
        ]
        case .solutionToxicity: [
            "Switched to a store-brand multipurpose solution last month. Both eyes sting for the first few hours of wear.",
            "Silicone hydrogel lenses stored in a biguanide multipurpose solution. Both eyes are red and gritty by mid-morning.",
        ]
        case .tightLens: [
            "Soft lenses fit last week. Comfortable in the morning, aching and red by evening; the lens doesn't move on blinking.",
            "High-water soft lenses worn 14 hours a day. \"They feel stuck by the end of the day.\"",
        ]
        case .inferiorStaining: [
            "Thin high-water soft lenses, eight hours a day on a laptop. Eyes feel dry by afternoon.",
            "Soft lens wearer whose blinks only close partway. Burning and dryness late in the day.",
        ]
        }
    }

    var signs: String {
        switch self {
        case .neovascularization: "Fine, bright red vessels run from the limbal arcade into clear cornea, here under the upper lid, where the cornea gets the least oxygen. It is usually painless, so the patient rarely notices."
        case .papillaryConjunctivitis: "With the upper lid everted, the tarsal conjunctiva is red and covered in raised papillae, each with a central vascular tuft; at the giant stage they exceed 1 mm. Itching, mucus, lens awareness and a lens that rides high are typical."
        case .threeNineStaining: "Punctate staining at the nasal and temporal cornea, just outside the GP lens edge. The edge holds the lid away from these areas, so blinks don't rewet them and they dry out."
        case .seal: "A thin arc of stain in the superior cornea within about 1 mm of the limbus, between 10 and 2 o'clock, under the upper lid. Usually only a mild foreign-body feeling, or none."
        case .edema: "A hazy central cornea with epithelial microcysts (tiny dots) and fine vertical striae in the posterior stroma; folds appear when swelling is severe. Striae mean swelling of more than about 6%."
        case .clare: "Diffuse bulbar and limbal redness with small peripheral and mid-peripheral infiltrates. The epithelium is intact, so the infiltrates don't stain. Vision is usually normal."
        case .clpu: "A single small, round, dense white infiltrate (under 2 mm) in the peripheral cornea, with redness in that sector. A small overlying epithelial defect, mild to moderate discomfort."
        case .microbialKeratitis: "A large, dense, irregular infiltrate in the central or paracentral cornea with surrounding haze and intense redness; a hypopyon in severe cases. Fluorescein shows an epithelial defect over it. Pain, light sensitivity, discharge and blur."
        case .solutionToxicity: "Diffuse punctate staining over the whole cornea, often heaviest in the mid-periphery, in both eyes. It peaks a few hours after inserting lenses soaked in a multipurpose solution, with stinging and redness."
        case .tightLens: "The soft lens doesn't move. Its edge presses a blanched ring into the conjunctiva, with redness around the limbus, and leaves an indentation ring after removal. Discomfort builds late in the day."
        case .inferiorStaining: "A smile-shaped band of punctate stain in the lower cornea, between the lower edge of the pupil and the lower limbus. The lower cornea dries when blinks are incomplete and the soft lens dehydrates."
        }
    }

    var action: LensAction {
        switch self {
        case .neovascularization, .edema: .higherDkRefit
        case .papillaryConjunctivitis: .breakThenFreshLenses
        case .threeNineStaining: .modifyGPEdge
        case .seal: .lowerModulusRefit
        case .clare, .clpu: .promptReferral
        case .microbialKeratitis: .urgentReferral
        case .solutionToxicity: .changeCareSystem
        case .tightLens: .loosenFit
        case .inferiorStaining: .treatDrying
        }
    }

    /// Plausible next steps that are wrong for this problem.
    var actionDistractors: [LensAction] {
        switch self {
        case .neovascularization: [.continueWear, .continuousWear, .rednessDrops, .changeCareSystem]
        case .papillaryConjunctivitis: [.continueWear, .continuousWear, .rednessDrops, .tightenFit]
        case .threeNineStaining: [.increaseEdgeLift, .continueWear, .patchOvernight, .changeCareSystem]
        case .seal: [.continueWear, .tightenFit, .continuousWear, .modifyGPEdge]
        case .edema: [.continueWear, .continuousWear, .rednessDrops, .changeCareSystem]
        case .clare: [.continueWear, .continuousWear, .rednessDrops, .patchOvernight]
        case .clpu: [.continueWear, .continuousWear, .rednessDrops, .patchOvernight]
        case .microbialKeratitis: [.promptReferral, .patchOvernight, .rednessDrops, .changeCareSystem]
        case .solutionToxicity: [.continueWear, .rednessDrops, .continuousWear, .higherDkRefit]
        case .tightLens: [.tightenFit, .continueWear, .rednessDrops, .continuousWear]
        case .inferiorStaining: [.increaseEdgeLift, .continuousWear, .rednessDrops, .continueWear]
        }
    }

    var actionReason: String {
        switch self {
        case .neovascularization: "New vessels are a response to chronic hypoxia, so the cure is more oxygen: a higher-Dk/t silicone hydrogel or GP lens, less wearing time and no overnight wear. Superficial vessels usually empty and regress after the refit, and the prescriber tracks their reach at each visit."
        case .papillaryConjunctivitis: "CLPC is an inflammatory reaction to lens deposits and the lens edge rubbing the upper lid. Stopping or cutting back wear lets it settle, and the prescriber may add drops. Fresh lenses prevent a relapse: daily disposables or more frequent replacement."
        case .threeNineStaining: "This is drying beside the lens edge. Most GP labs recommend reducing edge lift first; better centration, a diameter change, full blinks and rewetting drops also help. Left alone it can progress to dellen or vascularized scarring."
        case .seal: "A SEAL is mechanical chafing from a stiff lens pressed by the upper lid. Wear stops until the epithelium heals, with lubricants only, then a lower-modulus lens or a different design keeps it from coming back."
        case .edema: "Edema, microcysts and striae mean the cornea isn't getting enough oxygen. Refit into a higher-Dk/t silicone hydrogel or GP lens, shorten wearing time and stop overnight wear."
        case .clare: "CLARE is a sterile inflammatory reaction to bacterial toxins on a lens that was slept in. The lenses come out and the prescriber confirms it isn't infection. It settles quickly, but it recurs in about half of patients who go back to overnight hydrogel wear, so return on daily wear."
        case .clpu: "CLPU is sterile and settles on its own, but it can look like early MK, so the prescriber must confirm it. It often leaves a small scar. Afterward, no overnight wear and lenses replaced on schedule."
        case .microbialKeratitis: "MK is sight-threatening and can get worse within hours, so the patient sees the eye doctor today, bringing the lenses and case for culture. Never patch a lens wearer's eye, and no lens wear until the doctor clears it. Waiting until tomorrow is too late."
        case .solutionToxicity: "This is a reaction between the lens and the solution's preservative. Peroxide systems and daily disposables cause little staining, so changing the care system fixes it."
        case .tightLens: "A lens that doesn't move stops tear exchange and squeezes the limbus. Loosening the fit and shortening wear time fix it; high-water lenses tighten as they dry out, so a different material can help. Infection can look similar, so the prescriber should check."
        case .inferiorStaining: "Incomplete blinks and a dehydrating lens leave the lower cornea dry. Blink training, preservative-free drops and a dry-eye workup address the cause."
        }
    }

    /// Names shown as wrong choices; three are picked at random.
    var confusers: [LensComplication] {
        switch self {
        case .neovascularization: [.edema, .tightLens, .clare, .clpu]
        case .papillaryConjunctivitis: [.solutionToxicity, .clare, .tightLens, .neovascularization]
        case .threeNineStaining: [.seal, .inferiorStaining, .solutionToxicity, .tightLens]
        case .seal: [.threeNineStaining, .inferiorStaining, .solutionToxicity, .clpu]
        case .edema: [.neovascularization, .solutionToxicity, .microbialKeratitis, .clare]
        case .clare: [.clpu, .microbialKeratitis, .tightLens, .solutionToxicity]
        case .clpu: [.microbialKeratitis, .clare, .seal, .neovascularization]
        case .microbialKeratitis: [.clpu, .clare, .edema, .tightLens]
        case .solutionToxicity: [.inferiorStaining, .seal, .threeNineStaining, .edema]
        case .tightLens: [.clare, .neovascularization, .solutionToxicity, .microbialKeratitis]
        case .inferiorStaining: [.solutionToxicity, .seal, .threeNineStaining, .clpu]
        }
    }

    /// The Efron scale (CooperVision edition) used to grade this problem.
    var efronScale: String {
        switch self {
        case .neovascularization: "Corneal neovascularisation"
        case .papillaryConjunctivitis: "Papillary conjunctivitis"
        case .threeNineStaining, .seal, .solutionToxicity, .inferiorStaining: "Corneal staining"
        case .edema: "Corneal oedema"
        case .clare: "Conjunctival redness"
        case .clpu: "Corneal infiltrates"
        case .microbialKeratitis: "Corneal ulcer"
        case .tightLens: "Limbal redness"
        }
    }

    func gradeCue(_ grade: EfronGrade) -> String {
        let cues: [String] = switch self {
        case .neovascularization: [
            "Vessels barely past the limbal arcade in a small sector.",
            "Vessels about 1 mm into clear cornea along part of the superior limbus.",
            "Vessels 1.5–2 mm in, over a wider arc.",
            "Vessels well into the cornea around much of the limbus.",
        ]
        case .papillaryConjunctivitis: [
            "A few small papillae; tarsal vessels still visible.",
            "More papillae over part of the tarsus, with mild redness.",
            "Papillae about 0.5 mm over most of the tarsus, vessels hidden, some mucus.",
            "Giant papillae over 1 mm with marked redness and mucus.",
        ]
        case .threeNineStaining: [
            "A few scattered dots at 3 and 9.",
            "Small patches of punctate stain at 3 and 9.",
            "Denser, coalescing stain over wider areas.",
            "Dense, confluent stain over broad areas at 3 and 9.",
        ]
        case .seal: [
            "A short, faint arc of punctate stain.",
            "A longer arc of light stain.",
            "A clear arc of coalescing stain over much of 10 to 2 o'clock.",
            "A long, dense arc with a split in the epithelium.",
        ]
        case .edema: [
            "Faint haze and a few microcysts, no striae yet.",
            "A few vertical striae begin to show.",
            "Several striae, more microcysts and clear haze.",
            "Many striae plus posterior folds and dense haze.",
        ]
        case .clare: [
            "Slight redness and a couple of faint infiltrates.",
            "Moderate diffuse redness with a few infiltrates.",
            "Marked redness with several infiltrates.",
            "Intense redness with many infiltrates.",
        ]
        case .clpu: [
            "A tiny faint infiltrate with little redness.",
            "A small infiltrate with sector redness.",
            "A dense infiltrate about 1–1.5 mm with clear sector redness.",
            "A dense infiltrate close to 2 mm with marked sector redness.",
        ]
        case .microbialKeratitis: [
            "A paracentral infiltrate just over 1 mm, with redness.",
            "A 2 mm infiltrate with haze and marked redness.",
            "A large central infiltrate with dense haze and a small hypopyon.",
            "A very large central ulcer with a layered hypopyon.",
        ]
        case .solutionToxicity: [
            "Sparse dots scattered across the cornea.",
            "Light punctate staining over most of the cornea.",
            "Dense punctate staining, heaviest in the mid-periphery.",
            "Very dense, coalescing staining over the whole cornea.",
        ]
        case .tightLens: [
            "Faint redness at the lens edge.",
            "Mild limbal redness and a visible edge ring.",
            "Moderate limbal redness with a clear compression ring.",
            "Intense limbal redness and a deep indentation ring.",
        ]
        case .inferiorStaining: [
            "A few dots low on the cornea.",
            "A light band of stain below the pupil.",
            "A dense, smile-shaped band.",
            "A dense, coalescing band across the lower cornea.",
        ]
        }
        return cues[grade.rawValue - 1]
    }

    var sources: [SourceLink] {
        switch self {
        case .neovascularization: [LensSources.millerNeovascularization, LensSources.joslinHypoxia]
        case .papillaryConjunctivitis: [LensSources.nhsPapillary, LensSources.gromackiRedEye, LensSources.deNaeyer]
        case .threeNineStaining: [LensSources.wooGP, LensSources.buchEdgeLift]
        case .seal: [LensSources.deNaeyer]
        case .edema: [LensSources.joslinHypoxia, LensSources.johnsonStriae, LensSources.eyeWiki]
        case .clare: [LensSources.sicksCLARE, LensSources.deNaeyer]
        case .clpu: [LensSources.deNaeyer, LensSources.tompkinsRedEye, LensSources.nhsInfiltrative]
        case .microbialKeratitis: [LensSources.aaoKeratitis, LensSources.nhsMicrobial, LensSources.tompkinsRedEye]
        case .solutionToxicity: [LensSources.brujicStaining, LensSources.deNaeyer, LensSources.tompkinsRedEye]
        case .tightLens: [LensSources.gromackiRedEye]
        case .inferiorStaining: [LensSources.chiuInferior, LensSources.schulzeBlink, LensSources.whiteStaining]
        }
    }

    func nameChoices<G: RandomNumberGenerator>(using rng: inout G) -> [LensComplication] {
        (confusers.shuffled(using: &rng).prefix(3) + [self]).shuffled(using: &rng)
    }

    func actionChoices<G: RandomNumberGenerator>(using rng: inout G) -> [LensAction] {
        (actionDistractors.shuffled(using: &rng).prefix(3) + [action]).shuffled(using: &rng)
    }
}

/// Drawing intensity in millimetres or 0–1 fractions; each problem's graded feature grows with the Efron grade.
nonisolated struct LesionSeverity: Equatable, Sendable {
    var redness = 0.1
    var limbalRedness = 0.0
    var sectorRedness = 0.0
    var vesselReach = 0.0
    var vesselSpan = 0.0
    var papillaSize = 0.0
    var papillaCoverage = 0.0
    var mucusStrands = 0
    var stainDots = 0
    var stainSpread = 0.0
    var confluent = false
    var epithelialSplit = false
    var haze = 0.0
    var microcysts = 0
    var striae = 0
    var folds = 0
    var infiltrates = 0
    var lesionSize = 0.0
    var hypopyon = 0.0
    var indentation = 0.0
    /// The feature the Efron scale grades for this problem.
    var magnitude = 0.0

    init(_ complication: LensComplication, grade: EfronGrade) {
        let g = grade.rawValue - 1
        switch complication {
        case .neovascularization:
            vesselReach = [0.4, 0.9, 1.6, 2.6][g]
            vesselSpan = [50, 80, 130, 220][g]
            limbalRedness = [0.1, 0.15, 0.25, 0.35][g]
            magnitude = vesselReach
        case .papillaryConjunctivitis:
            papillaSize = [0.25, 0.4, 0.6, 1.15][g]
            papillaCoverage = [0.3, 0.5, 0.75, 1][g]
            redness = [0.2, 0.4, 0.65, 0.9][g]
            mucusStrands = [0, 0, 2, 4][g]
            magnitude = papillaSize
        case .threeNineStaining:
            stainDots = [14, 40, 90, 150][g]
            stainSpread = [10, 14, 19, 24][g]
            confluent = g >= 2
            magnitude = Double(stainDots)
        case .seal:
            stainDots = [20, 50, 110, 180][g]
            stainSpread = [30, 55, 85, 115][g]
            confluent = g >= 2
            epithelialSplit = g == 3
            magnitude = stainSpread
        case .edema:
            haze = [0.14, 0.24, 0.36, 0.5][g]
            microcysts = [8, 16, 30, 48][g]
            striae = [0, 3, 7, 11][g]
            folds = [0, 0, 0, 3][g]
            magnitude = haze
        case .clare:
            redness = [0.35, 0.55, 0.75, 0.95][g]
            limbalRedness = [0.3, 0.5, 0.7, 0.9][g]
            infiltrates = [2, 4, 7, 11][g]
            magnitude = redness
        case .clpu:
            lesionSize = [0.5, 0.9, 1.3, 1.8][g]
            sectorRedness = [0.25, 0.45, 0.65, 0.85][g]
            redness = 0.15
            magnitude = lesionSize
        case .microbialKeratitis:
            lesionSize = [1.3, 2.1, 3.0, 4.2][g]
            redness = [0.5, 0.65, 0.8, 0.95][g]
            limbalRedness = [0.5, 0.65, 0.8, 0.95][g]
            haze = [0.1, 0.18, 0.28, 0.4][g]
            hypopyon = [0, 0, 0.3, 0.9][g]
            magnitude = lesionSize
        case .solutionToxicity:
            stainDots = [60, 140, 260, 420][g]
            confluent = g == 3
            magnitude = Double(stainDots)
        case .tightLens:
            limbalRedness = [0.25, 0.45, 0.7, 0.95][g]
            indentation = [0.2, 0.45, 0.7, 1][g]
            redness = [0.15, 0.2, 0.3, 0.4][g]
            magnitude = limbalRedness
        case .inferiorStaining:
            stainDots = [16, 45, 95, 160][g]
            stainSpread = [50, 70, 95, 120][g]
            confluent = g == 3
            magnitude = Double(stainDots)
        }
    }
}

nonisolated struct LensProblemCase: Equatable, Sendable {
    struct Result: Equatable, Sendable {
        var name: Bool
        var grade: Bool
        var action: Bool

        var points: Int { [name, grade, action].filter { $0 }.count }
    }

    var complication: LensComplication
    var grade: EfronGrade
    var rightEye: Bool
    var seed: UInt64

    var severity: LesionSeverity { LesionSeverity(complication, grade: grade) }

    var history: String {
        let histories = complication.histories
        return histories[Int(seed % UInt64(histories.count))]
    }

    func result(name: LensComplication, grade: EfronGrade, action: LensAction) -> Result {
        Result(name: name == complication, grade: grade == self.grade, action: action == complication.action)
    }

    static func random<G: RandomNumberGenerator>(excluding previous: LensComplication? = nil, using rng: inout G) -> LensProblemCase {
        LensProblemCase(
            complication: LensComplication.allCases.filter { $0 != previous }.randomElement(using: &rng)!,
            grade: EfronGrade.allCases.randomElement(using: &rng)!,
            rightEye: Bool.random(using: &rng),
            seed: UInt64.random(in: 1...UInt64.max, using: &rng)
        )
    }
}

private enum LensSources {
    static let clear = SourceLink(title: "BCLA CLEAR: Contact Lens Complications (Stapleton et al., Contact Lens & Anterior Eye, 2021)", url: URL(string: "https://doi.org/10.1016/j.clae.2021.02.010")!)
    static let efron = SourceLink(title: "CooperVision: Efron Grading Scales for Contact Lens Complications", url: URL(string: "https://coopervision.co.uk/node/46131")!)
    static let eyeWiki = SourceLink(title: "AAO EyeWiki: Contact Lens Complications", url: URL(string: "https://eyewiki.org/Contact_Lens_Complications")!)
    static let deNaeyer = SourceLink(title: "Contact Lens Spectrum: Diagnosing and Managing Lens-Related Complications (DeNaeyer, 2010)", url: URL(string: "https://clspectrum.com/issues/2010/march/diagnosing-and-managing-lens-related-complications/")!)
    static let millerNeovascularization = SourceLink(title: "Contact Lens Spectrum: Managing Corneal Neovascularization (Miller, 2015)", url: URL(string: "https://clspectrum.com/issues/2015/may/treatment-plan/")!)
    static let joslinHypoxia = SourceLink(title: "Contact Lens Spectrum: Contact Lenses and Complications (Joslin, 2003)", url: URL(string: "https://www.clspectrum.com/issues/2003/february/contact-lenses-and-complications/")!)
    static let johnsonStriae = SourceLink(title: "Br J Ophthalmol: Corneal Striae Following Contact Lens Wear (Johnson et al., 1987)", url: URL(string: "https://bjo.bmj.com/content/71/10/737")!)
    static let nhsPapillary = SourceLink(title: "NHS Scotland Eyecare Guidelines: CL-Associated Papillary / Giant Papillary Conjunctivitis", url: URL(string: "https://www.eyes.nhs.scot/eyecare-guidelines/section-3-conjunctiva/37-conjunctivitis-contact-lens-associated-papillary-giant-papillary/")!)
    static let nhsInfiltrative = SourceLink(title: "NHS Scotland Eyecare Guidelines: CL-Associated Peripheral Infiltrative Keratitis", url: URL(string: "https://www.eyes.nhs.scot/eyecare-guidelines/section-5-corneal/59-keratitis-peripheral-infiltrative-contact-lens-associated/")!)
    static let nhsMicrobial = SourceLink(title: "NHS Scotland Eyecare Guidelines: Microbial Keratitis (Bacterial)", url: URL(string: "https://www.eyes.nhs.scot/eyecare-guidelines/section-5-corneal/512-keratitis-microbial-bacterial/")!)
    static let aaoKeratitis = SourceLink(title: "American Academy of Ophthalmology: Bacterial Keratitis Preferred Practice Pattern (2023)", url: URL(string: "https://www.aao.org/education/preferred-practice-pattern/bacterial-keratitis-ppp-2023")!)
    static let gromackiRedEye = SourceLink(title: "Optometric Management: Combat Soft Contact Lens-Caused Red Eye (Gromacki, 2023)", url: URL(string: "https://www.optometricmanagement.com/issues/2023/januaryfebruary/combat-soft-contact-lens-caused-red-eye")!)
    static let wooGP = SourceLink(title: "Review of Cornea & Contact Lenses: Troubleshooting GP Complications (Woo, 2015)", url: URL(string: "https://www.reviewofcontactlenses.com/article/troubleshooting-gp-complications")!)
    static let buchEdgeLift = SourceLink(title: "Contact Lens Spectrum: Peripheral Corneal Staining, a Survey of RGP Laboratories (Buch, 1997)", url: URL(string: "https://clspectrum.com/issues/1997/may/peripheral-corneal-staining-a-survey-of-rgp-laboratories/")!)
    static let sicksCLARE = SourceLink(title: "Review of Cornea & Contact Lenses: Bringing Clarity to CLARE (Sicks, 2015)", url: URL(string: "https://www.reviewofcontactlenses.com/article/bringing-clarity-to-clare")!)
    static let tompkinsRedEye = SourceLink(title: "Review of Optometry CE: Contact Lens-associated Red Eye (Tompkins, 2017)", url: URL(string: "https://www.revieweducationgroup.com/ce/contact-lens-associated-red-eye")!)
    static let brujicStaining = SourceLink(title: "Contact Lens Spectrum: Practical Applications of the Staining Studies (Brujic, 2008)", url: URL(string: "https://clspectrum.com/issues/2008/august/practical-applications-of-the-staining-studies/")!)
    static let chiuInferior = SourceLink(title: "Contact Lens Spectrum: When Is It a Compliance Issue? (Chiu & Edrington, 2008)", url: URL(string: "https://clspectrum.com/issues/2008/december/cultivating-compliance/")!)
    static let schulzeBlink = SourceLink(title: "Review of Optometry CE: Blink Mechanics, Why It Matters (Schulze, 2020)", url: URL(string: "https://www.revieweducationgroup.com/ce/blink-mechanics-why-it-matters")!)
    static let whiteStaining = SourceLink(title: "Contact Lens Spectrum: Contact Lens Complications, Part II (White, 2000)", url: URL(string: "https://clspectrum.com/issues/2000/february/contact-lens-complications-part-ii/")!)
}

struct LensComplicationTrainerView: View {
    @State private var problem: LensProblemCase
    @State private var nameChoices: [LensComplication]
    @State private var actionChoices: [LensAction]
    @State private var pickedName: LensComplication?
    @State private var pickedGrade: EfronGrade?
    @State private var pickedAction: LensAction?
    @State private var result: LensProblemCase.Result?
    @State private var points = 0
    @State private var possible = 0
    @State private var perfectEyes = 0
    @State private var eyes = 0
    @State private var showingHelp = false
    @Environment(\.palette) private var palette

    private static let generalSources = [LensSources.efron, LensSources.clear, LensSources.eyeWiki]

    init() {
        var rng = SystemRandomNumberGenerator()
        let first = LensProblemCase.random(using: &rng)
        _problem = State(initialValue: first)
        _nameChoices = State(initialValue: first.complication.nameChoices(using: &rng))
        _actionChoices = State(initialValue: first.complication.actionChoices(using: &rng))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ComplicationEye(problem: problem)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .frame(maxWidth: 440)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Drawn \(problem.rightEye ? "right" : "left") eye, examiner's view: \(problem.complication.viewCaption.lowercased())")

                Text("\(problem.rightEye ? "OD" : "OS") · \(problem.complication.viewCaption)")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)

                Panel {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Follow-up visit").font(.headline)
                        Text(problem.history)
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryText)
                    }
                }

                Text("1. What is it?").font(.headline)
                ComplicationChoiceList(items: nameChoices, label: \.title, selection: $pickedName, correct: problem.complication, checked: result != nil)

                Text("2. Grade it (Efron scale)").font(.headline)
                FlowLayout {
                    ForEach(EfronGrade.allCases) { grade in
                        Button { pickedGrade = grade } label: {
                            Chip(text: "\(grade.rawValue) \(grade.label)", symbol: gradeSymbol(grade), selected: pickedGrade == grade)
                        }
                        .buttonStyle(.plain)
                        .disabled(result != nil)
                    }
                }

                Text("3. Next step").font(.headline)
                ComplicationChoiceList(items: actionChoices, label: \.title, selection: $pickedAction, correct: problem.complication.action, checked: result != nil)

                if let result {
                    resultPanel(result)
                } else {
                    Button("Check", action: check)
                        .buttonStyle(.borderedProminent)
                        .disabled(pickedName == nil || pickedGrade == nil || pickedAction == nil)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityIdentifier("lensproblem.check")
                }

                Text("Score \(points) / \(possible) · \(perfectEyes) of \(eyes) eyes all correct")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(palette.secondaryText)

                DisclosureGroup("How it works", isExpanded: $showingHelp) {
                    RichText(text: """
                    - **Name it** from the drawing and the history together. Overnight wear, pain and which part of the cornea is involved separate the red-eye problems: CLARE (diffuse redness, small infiltrates, intact epithelium), CLPU (one small peripheral infiltrate) and MK (large central infiltrate with a defect).
                    - **Grade it** on Efron's scales, which run 0 (normal), 1 trace, 2 mild, 3 moderate and 4 severe, with a separate scale for each sign, such as staining, redness or neovascularisation. A one-grade change is clinically meaningful. Judge how far, how wide and how dense the sign is.
                    - **Pick the next step** an optician takes. Diagnosis and medication belong to the prescriber, so most answers include a referral. A painful red eye with a corneal infiltrate is MK until proven otherwise: lenses out, same-day referral, never patch.

                    Views: white light shows redness, vessels, infiltrates and edema. Staining is shown with fluorescein under cobalt blue, with soft lenses removed first. Papillae are seen on the everted upper lid. Right and left mean the patient's; drawings are the examiner's front view. Simulated eyes; real presentations overlap.
                    """)
                    .font(.subheadline)
                    .padding(.top, 8)
                    SourceList(sources: Self.generalSources)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                }
                .tint(palette.accent)
            }
            .padding()
        }
        .pettyScreen()
        .navigationTitle("Lens Problems Trainer")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func resultPanel(_ result: LensProblemCase.Result) -> some View {
        let complication = problem.complication
        return Panel {
            VStack(alignment: .leading, spacing: 12) {
                feedback(
                    result.name,
                    title: result.name ? "Correct: \(complication.title)" : "This is \(complication.title)",
                    detail: complication.signs
                )
                feedback(
                    result.grade,
                    title: result.grade ? "Grade \(problem.grade.rawValue) (\(problem.grade.label)) is right" : "Efron grade \(problem.grade.rawValue) (\(problem.grade.label))",
                    detail: "\(complication.efronScale) scale: \(complication.gradeCue(problem.grade))"
                )
                feedback(
                    result.action,
                    title: result.action ? "Right next step" : "Better next step: \(complication.action.title)",
                    detail: [complication.actionReason, actionPitfall].compactMap { $0 }.joined(separator: " ")
                )
                SourceList(sources: complication.sources)
                Button("Next Eye", action: next)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("lensproblem.next")
            }
        }
    }

    private var actionPitfall: String? {
        guard let pickedAction, pickedAction != problem.complication.action else { return nil }
        if let pitfall = pickedAction.pitfall { return "Why not your pick: \(pitfall)" }
        let fits = LensComplication.allCases.filter { $0.action == pickedAction }.map(\.title)
        return fits.isEmpty ? nil : "Your pick is the usual plan for \(fits.formatted(.list(type: .or)))."
    }

    private func feedback(_ correct: Bool, title: String, detail: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.subheadline).foregroundStyle(palette.secondaryText)
            }
        } icon: {
            Image(systemName: correct ? "checkmark.seal.fill" : "xmark.octagon.fill")
                .foregroundStyle(correct ? .green : .red)
        }
    }

    private func gradeSymbol(_ grade: EfronGrade) -> String? {
        guard result != nil else { return nil }
        if grade == problem.grade { return "checkmark" }
        return grade == pickedGrade ? "xmark" : nil
    }

    private func check() {
        guard let pickedName, let pickedGrade, let pickedAction else { return }
        let outcome = problem.result(name: pickedName, grade: pickedGrade, action: pickedAction)
        result = outcome
        points += outcome.points
        possible += 3
        eyes += 1
        if outcome.points == 3 { perfectEyes += 1 }
    }

    private func next() {
        var rng = SystemRandomNumberGenerator()
        problem = LensProblemCase.random(excluding: problem.complication, using: &rng)
        nameChoices = problem.complication.nameChoices(using: &rng)
        actionChoices = problem.complication.actionChoices(using: &rng)
        pickedName = nil
        pickedGrade = nil
        pickedAction = nil
        result = nil
    }
}

private struct ComplicationChoiceList<Item: Hashable>: View {
    let items: [Item]
    let label: KeyPath<Item, String>
    @Binding var selection: Item?
    let correct: Item
    let checked: Bool
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 10) {
            ForEach(items, id: \.self) { item in
                Button { selection = item } label: {
                    HStack {
                        Text(item[keyPath: label]).multilineTextAlignment(.leading)
                        Spacer()
                        if checked {
                            if item == correct {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            } else if item == selection {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                            }
                        } else if item == selection {
                            Image(systemName: "largecircle.fill.circle").foregroundStyle(palette.accent)
                        }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(palette.text)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(checked)
            }
        }
    }
}

private struct ComplicationRNG: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

private struct ComplicationEye: View {
    let problem: LensProblemCase

    var body: some View {
        Canvas { ctx, size in
            ComplicationArt(problem: problem, size: size).draw(&ctx)
        }
        .aspectRatio(ComplicationArt.viewWidth / ComplicationArt.viewHeight, contentMode: .fit)
    }
}

/// Millimetre coordinates centred on the cornea, +x to the examiner's right, +y down.
private struct ComplicationArt {
    static let viewWidth = 22.0
    static let viewHeight = 15.0
    static let cornea = 5.9
    static let pupil = 1.9

    private static let irises: [(Color, Color)] = [
        (Color(red: 0.55, green: 0.36, blue: 0.16), Color(red: 0.3, green: 0.17, blue: 0.07)),
        (Color(red: 0.55, green: 0.68, blue: 0.8), Color(red: 0.25, green: 0.38, blue: 0.55)),
        (Color(red: 0.6, green: 0.55, blue: 0.28), Color(red: 0.3, green: 0.38, blue: 0.2)),
        (Color(red: 0.62, green: 0.66, blue: 0.68), Color(red: 0.34, green: 0.38, blue: 0.42)),
    ]
    private static let red = Color(red: 0.8, green: 0.14, blue: 0.16)
    private static let fluorescein = Color(red: 0.4, green: 1, blue: 0.45)
    private static let skin = Color(red: 0.87, green: 0.67, blue: 0.57)
    private static let skinShade = Color(red: 0.72, green: 0.52, blue: 0.44)

    let problem: LensProblemCase
    let severity: LesionSeverity
    let scale: Double
    let origin: CGPoint
    let bounds: CGRect
    let nasal: Double
    let sectorAngle: Double

    init(problem: LensProblemCase, size: CGSize) {
        self.problem = problem
        severity = problem.severity
        scale = size.width / Self.viewWidth
        origin = CGPoint(x: size.width / 2, y: size.height / 2)
        bounds = CGRect(origin: .zero, size: size)
        nasal = problem.rightEye ? 1 : -1
        var rng = ComplicationRNG(state: problem.seed)
        sectorAngle = switch problem.complication {
        case .neovascularization: -.pi / 2 + .random(in: -0.35...0.35, using: &rng)
        case .clpu: [-0.5, 0.4, 0.9, 2.2, 2.7, 3.6].randomElement(using: &rng)!
        default: .random(in: 0..<(2 * .pi), using: &rng)
        }
    }

    private func stream(_ index: UInt64) -> ComplicationRNG {
        ComplicationRNG(state: problem.seed &+ index &* 0x2545_F491_4F6C_DD1D)
    }

    private func pt(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
    }

    private func pt(_ p: SIMD2<Double>) -> CGPoint { pt(p.x, p.y) }

    private func polar(_ r: Double, _ angle: Double) -> SIMD2<Double> { [cos(angle) * r, sin(angle) * r] }

    private func circle(_ c: SIMD2<Double>, _ r: Double) -> Path {
        Path(ellipseIn: CGRect(x: origin.x + (c.x - r) * scale, y: origin.y + (c.y - r) * scale, width: 2 * r * scale, height: 2 * r * scale))
    }

    private func smooth(_ points: [SIMD2<Double>]) -> Path {
        var path = Path()
        let p = points.map(pt)
        guard p.count > 1 else { return path }
        path.move(to: p[0])
        for i in 1..<max(1, p.count - 1) {
            path.addQuadCurve(to: CGPoint(x: (p[i].x + p[i + 1].x) / 2, y: (p[i].y + p[i + 1].y) / 2), control: p[i])
        }
        path.addLine(to: p[p.count - 1])
        return path
    }

    private func arc(radius: Double, center: Double, span: Double) -> Path {
        smooth(stride(from: center - span / 2, through: center + span / 2, by: span / 40).map { polar(radius, $0) })
    }

    private func upperMargin(_ x: Double) -> Double { -6.4 + 0.038 * x * x }
    private func lowerMargin(_ x: Double) -> Double { 6.5 - 0.03 * x * x }

    func draw(_ ctx: inout GraphicsContext) {
        switch problem.complication.view {
        case .whiteLight: drawWhiteLight(&ctx)
        case .cobaltBlue: drawCobalt(&ctx)
        case .evertedLid: drawEvertedLid(&ctx)
        }
        ctx.fill(Path(bounds), with: .radialGradient(
            Gradient(colors: [.clear, .black.opacity(0.4)]),
            center: pt(0, 0), startRadius: 8 * scale, endRadius: 15 * scale
        ))
    }

    // MARK: White light

    private func drawWhiteLight(_ ctx: inout GraphicsContext) {
        let red = Self.red
        ctx.fill(Path(bounds), with: .radialGradient(
            Gradient(colors: [Color(red: 0.97, green: 0.94, blue: 0.92), Color(red: 0.88, green: 0.78, blue: 0.75)]),
            center: pt(0, 0), startRadius: Self.cornea * scale, endRadius: 13 * scale
        ))
        ctx.fill(Path(bounds), with: .radialGradient(
            Gradient(colors: [red.opacity(0.45 * severity.redness), red.opacity(0.12 * severity.redness)]),
            center: pt(0, 0), startRadius: Self.cornea * scale, endRadius: 12 * scale
        ))
        if severity.sectorRedness > 0 {
            var wedge = Path()
            wedge.move(to: pt(0, 0))
            wedge.addArc(center: pt(0, 0), radius: 13 * scale, startAngle: .radians(sectorAngle - 0.55), endAngle: .radians(sectorAngle + 0.55), clockwise: false)
            wedge.closeSubpath()
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: 1.2 * scale))
                layer.fill(wedge, with: .color(red.opacity(0.4 * severity.sectorRedness)))
            }
        }
        conjunctivalVessels(&ctx)
        if severity.limbalRedness > 0 {
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: 0.5 * scale))
                layer.stroke(circle(.zero, Self.cornea + 0.7), with: .color(red.opacity(0.6 * severity.limbalRedness)), lineWidth: 1.4 * scale)
            }
        }
        caruncle(&ctx, color: Color(red: 0.9, green: 0.58, blue: 0.56))
        iris(&ctx)

        switch problem.complication {
        case .neovascularization: neovascularization(&ctx)
        case .edema: edema(&ctx)
        case .clare: clareInfiltrates(&ctx)
        case .clpu: peripheralUlcer(&ctx)
        case .microbialKeratitis: microbialKeratitis(&ctx)
        case .tightLens: tightLens(&ctx)
        default: break
        }

        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 0.12 * scale))
            layer.fill(circle([1.3, -1.5], 0.35), with: .color(.white.opacity(0.9)))
        }
        lids(&ctx, skin: Self.skin, shade: Self.skinShade, lashes: Color(red: 0.16, green: 0.11, blue: 0.08), rim: Color(red: 0.86, green: 0.5, blue: 0.5))
        labels(&ctx, color: Color(red: 0.35, green: 0.22, blue: 0.18))
    }

    private func conjunctivalVessels(_ ctx: inout GraphicsContext) {
        var rng = stream(1)
        for _ in 0..<26 {
            let angle = Double.random(in: 0..<(2 * .pi), using: &rng)
            var p = polar(.random(in: 11...13.5, using: &rng), angle)
            var direction = -p / length(p)
            var points = [p]
            let stop = Double.random(in: (Self.cornea + 0.5)...(Self.cornea + 2.6), using: &rng)
            while length(p) > stop, points.count < 24 {
                direction = direction * 0.7 - p / length(p) * 0.3 + SIMD2(.random(in: -0.5...0.5, using: &rng), .random(in: -0.5...0.5, using: &rng))
                direction /= length(direction)
                p += direction * 0.75
                points.append(p)
            }
            let sector = severity.sectorRedness * pow(max(0, cos(angle - sectorAngle)), 3)
            let flush = max(severity.redness, sector)
            let opacity = 0.2 + .random(in: 0...0.25, using: &rng) + 0.5 * flush
            let width = Double.random(in: 0.05...0.13, using: &rng) * (1 + 1.3 * flush)
            ctx.stroke(smooth(points), with: .color(Self.red.opacity(min(0.95, opacity))), lineWidth: width * scale)
        }
    }

    private func caruncle(_ ctx: inout GraphicsContext, color: Color) {
        let x = nasal * 10.4
        ctx.fill(Path(ellipseIn: CGRect(x: origin.x + (x - 0.9) * scale, y: origin.y - 0.2 * scale, width: 1.8 * scale, height: 1.3 * scale)), with: .color(color))
    }

    private func iris(_ ctx: inout GraphicsContext) {
        var rng = stream(2)
        let colors = Self.irises.randomElement(using: &rng)!
        let center = pt(0, 0)
        let cornea = Self.cornea
        ctx.fill(circle(.zero, cornea), with: .radialGradient(
            Gradient(colors: [colors.0, colors.1]),
            center: center, startRadius: Self.pupil * scale, endRadius: cornea * scale
        ))
        for i in 0..<84 {
            let a = Double(i) / 84 * 2 * .pi + 0.03 * sin(Double(i) * 7.3)
            let shade = 0.1 + 0.12 * (0.5 + 0.5 * sin(Double(i) * 12.9898))
            var ray = Path()
            ray.move(to: pt(polar(Self.pupil + 0.2, a)))
            ray.addLine(to: pt(polar(cornea - 0.4, a)))
            ctx.stroke(ray, with: .color(.black.opacity(shade)), lineWidth: 0.12 * scale)
        }
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 0.2 * scale))
            layer.stroke(circle(.zero, cornea - 0.1), with: .color(.black.opacity(0.55)), lineWidth: 0.45 * scale)
        }
        ctx.fill(circle(.zero, Self.pupil), with: .color(.black))
    }

    private func neovascularization(_ ctx: inout GraphicsContext) {
        var rng = stream(3)
        let span = severity.vesselSpan * .pi / 180
        let count = max(4, Int(severity.vesselSpan / 8))
        let vessel = Color(red: 0.88, green: 0.12, blue: 0.14)
        ctx.stroke(arc(radius: Self.cornea + 0.35, center: sectorAngle, span: span * 1.1), with: .color(vessel.opacity(0.6)), lineWidth: 0.12 * scale)
        for i in 0..<count {
            var angle = sectorAngle - span / 2 + span * (Double(i) + .random(in: 0.2...0.8, using: &rng)) / Double(count)
            let reach = severity.vesselReach * .random(in: 0.55...1, using: &rng)
            let start = Self.cornea + 0.35
            var points = [polar(start, angle)]
            for step in 1...8 {
                angle += .random(in: -0.025...0.025, using: &rng)
                points.append(polar(start - (reach + 0.35) * Double(step) / 8, angle))
            }
            ctx.stroke(smooth(points), with: .color(vessel.opacity(0.85)), lineWidth: 0.09 * scale)
            if reach > 0.7, Bool.random(using: &rng) {
                let fork = points[4]
                let tip = fork + polar(reach * 0.45, angle + .pi + .random(in: -0.5...0.5, using: &rng))
                ctx.stroke(smooth([fork, (fork + tip) / 2 + polar(0.1, angle + .pi / 2), tip]), with: .color(vessel.opacity(0.75)), lineWidth: 0.06 * scale)
            }
        }
    }

    private func edema(_ ctx: inout GraphicsContext) {
        var rng = stream(4)
        ctx.fill(circle(.zero, 4.8), with: .radialGradient(
            Gradient(colors: [.white.opacity(severity.haze), .white.opacity(severity.haze * 0.4), .clear]),
            center: pt(0, 0), startRadius: 0, endRadius: 4.8 * scale
        ))
        for _ in 0..<severity.striae {
            let x = Double.random(in: -2.6...2.6, using: &rng)
            let top = Double.random(in: -2.6 ... -0.6, using: &rng)
            let bottom = top + .random(in: 1.8...3.6, using: &rng)
            let phase = Double.random(in: 0...6, using: &rng)
            let points = stride(from: top, through: bottom, by: 0.25).map { y in SIMD2(x + 0.08 * sin(y * 3 + phase), y) }
            ctx.stroke(smooth(points), with: .color(.white.opacity(0.6)), lineWidth: 0.05 * scale)
        }
        for _ in 0..<severity.folds {
            let x = Double.random(in: -2...2, using: &rng)
            let tilt = Double.random(in: -0.4...0.4, using: &rng)
            let points = stride(from: -2.4, through: 2.4, by: 0.4).map { y in SIMD2(x + tilt * y + 0.15 * sin(y * 2), y) }
            ctx.stroke(smooth(points), with: .color(.black.opacity(0.4)), lineWidth: 0.12 * scale)
        }
        for _ in 0..<severity.microcysts {
            let p = polar(4.2 * Double.random(in: 0...1, using: &rng).squareRoot(), .random(in: 0..<(2 * .pi), using: &rng))
            ctx.fill(circle(p, 0.075), with: .color(.white.opacity(0.85)))
            ctx.fill(circle(p + [0.03, 0.03], 0.045), with: .color(.black.opacity(0.45)))
        }
    }

    private func clareInfiltrates(_ ctx: inout GraphicsContext) {
        var rng = stream(5)
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 0.08 * scale))
            for _ in 0..<severity.infiltrates {
                let p = polar(.random(in: 3.8...5.4, using: &rng), .random(in: 0..<(2 * .pi), using: &rng))
                layer.fill(circle(p, .random(in: 0.12...0.24, using: &rng)), with: .color(.white.opacity(0.8)))
            }
        }
    }

    private func peripheralUlcer(_ ctx: inout GraphicsContext) {
        let radius = severity.lesionSize / 2
        let center = polar(Self.cornea - 0.7 - radius, sectorAngle)
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 0.25 * scale))
            layer.fill(circle(center, radius * 1.6), with: .color(.white.opacity(0.35)))
        }
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 0.06 * scale))
            layer.fill(circle(center, radius), with: .color(Color(red: 0.98, green: 0.97, blue: 0.92).opacity(0.92)))
        }
    }

    private func microbialKeratitis(_ ctx: inout GraphicsContext) {
        var rng = stream(6)
        let size = severity.lesionSize
        let center = polar(max(0.3, 2 - size * 0.4), sectorAngle)
        if severity.hypopyon > 0 {
            var chamber = ctx
            chamber.clip(to: circle(.zero, Self.cornea - 0.15))
            let top = Self.cornea - 0.15 - severity.hypopyon
            chamber.fill(Path(CGRect(x: origin.x - Self.cornea * scale, y: origin.y + top * scale, width: 2 * Self.cornea * scale, height: Self.cornea * scale)), with: .color(Color(red: 0.97, green: 0.94, blue: 0.82)))
        }
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 0.35 * scale))
            layer.fill(circle(center, size * 1.05), with: .color(.white.opacity(0.25 + severity.haze)))
        }
        var blob = Path()
        for i in 0..<20 {
            let p = pt(center + polar(size / 2 * .random(in: 0.72...1.15, using: &rng), Double(i) / 20 * 2 * .pi))
            if i == 0 { blob.move(to: p) } else { blob.addLine(to: p) }
        }
        blob.closeSubpath()
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 0.08 * scale))
            layer.fill(blob, with: .color(Color(red: 1, green: 0.97, blue: 0.84).opacity(0.95)))
        }
        ctx.fill(circle(center + [0.1, -0.1], size * 0.12), with: .color(.white.opacity(0.7)))
    }

    private func tightLens(_ ctx: inout GraphicsContext) {
        let lens = 7.0
        ctx.fill(circle(.zero, lens), with: .color(Color(red: 0.6, green: 0.78, blue: 0.95).opacity(0.06)))
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 0.25 * scale))
            layer.stroke(circle(.zero, lens + 0.45), with: .color(Self.red.opacity(0.55 * severity.indentation)), lineWidth: 0.55 * scale)
        }
        ctx.stroke(circle(.zero, lens + 0.12), with: .color(Color(red: 0.98, green: 0.95, blue: 0.93).opacity(0.4 + 0.5 * severity.indentation)), lineWidth: 0.22 * scale)
        ctx.stroke(circle(.zero, lens), with: .color(.white.opacity(0.55)), lineWidth: 0.08 * scale)
    }

    private func lids(_ ctx: inout GraphicsContext, skin: Color, shade: Color, lashes lashColor: Color, rim: Color) {
        let xs = stride(from: -12.0, through: 12.0, by: 0.5).map { $0 }
        var lower = Path()
        lower.addLines(xs.map { pt($0, lowerMargin($0)) })
        lower.addLine(to: CGPoint(x: bounds.maxX + 20, y: bounds.maxY + 20))
        lower.addLine(to: CGPoint(x: bounds.minX - 20, y: bounds.maxY + 20))
        lower.closeSubpath()
        ctx.fill(lower, with: .linearGradient(Gradient(colors: [skin, shade]), startPoint: pt(0, 6.5), endPoint: pt(0, 8)))
        var lowerRim = Path()
        lowerRim.addLines(xs.map { pt($0, lowerMargin($0)) })
        ctx.stroke(lowerRim, with: .color(rim), lineWidth: 0.3 * scale)

        var upper = Path()
        upper.addLines(xs.map { pt($0, upperMargin($0)) })
        upper.addLine(to: CGPoint(x: bounds.maxX + 20, y: bounds.minY - 20))
        upper.addLine(to: CGPoint(x: bounds.minX - 20, y: bounds.minY - 20))
        upper.closeSubpath()
        ctx.fill(upper, with: .linearGradient(Gradient(colors: [shade, skin]), startPoint: pt(0, -7.5), endPoint: pt(0, -6.4)))
        var lashes = Path()
        for x in stride(from: -10.4, through: 10.4, by: 0.35) {
            let reach = 1.0 + 0.35 * sin(x * 7.1)
            lashes.move(to: pt(x, upperMargin(x)))
            lashes.addQuadCurve(to: pt(x * 1.06, upperMargin(x) - reach), control: pt(x, upperMargin(x) - reach * 0.4))
        }
        ctx.stroke(lashes, with: .color(lashColor), lineWidth: 0.08 * scale)
        var lashLine = Path()
        lashLine.addLines(xs.map { pt($0, upperMargin($0)) })
        ctx.stroke(lashLine, with: .color(lashColor.opacity(0.8)), lineWidth: 0.22 * scale)
    }

    private func labels(_ ctx: inout GraphicsContext, color: Color) {
        let style = Font.caption2.weight(.semibold)
        let nasalAnchor: UnitPoint = nasal > 0 ? .trailing : .leading
        let temporalAnchor: UnitPoint = nasal > 0 ? .leading : .trailing
        ctx.draw(Text("Nasal").font(style).foregroundStyle(color), at: pt(nasal * 10.2, 7), anchor: nasalAnchor)
        ctx.draw(Text("Temporal").font(style).foregroundStyle(color), at: pt(-nasal * 10.2, 7), anchor: temporalAnchor)
        ctx.draw(Text("\(problem.rightEye ? "OD" : "OS") · examiner's view").font(.caption.weight(.bold)).foregroundStyle(color), at: pt(0, 7))
    }

    // MARK: Cobalt blue

    private func drawCobalt(_ ctx: inout GraphicsContext) {
        ctx.fill(Path(bounds), with: .radialGradient(
            Gradient(colors: [Color(red: 0.1, green: 0.11, blue: 0.36), Color(red: 0.04, green: 0.04, blue: 0.17)]),
            center: pt(0, 0), startRadius: Self.cornea * scale, endRadius: 13 * scale
        ))
        caruncle(&ctx, color: Color(red: 0.16, green: 0.1, blue: 0.3))
        ctx.fill(circle(.zero, Self.cornea), with: .radialGradient(
            Gradient(colors: [Color(red: 0.03, green: 0.05, blue: 0.14), Color(red: 0.06, green: 0.09, blue: 0.24)]),
            center: pt(0, 0), startRadius: Self.pupil * scale, endRadius: Self.cornea * scale
        ))
        ctx.fill(circle(.zero, Self.pupil), with: .color(Color(red: 0.01, green: 0.02, blue: 0.06)))
        ctx.fill(circle(.zero, Self.cornea), with: .color(Self.fluorescein.opacity(0.05)))
        ctx.stroke(circle(.zero, Self.cornea), with: .color(Color(red: 0.14, green: 0.2, blue: 0.4).opacity(0.7)), lineWidth: 0.12 * scale)

        if problem.complication == .threeNineStaining { gpLens(&ctx) }
        stain(&ctx, dots: stainPoints())
        if problem.complication == .seal { sealArc(&ctx) }

        var meniscus = Path()
        meniscus.addLines(stride(from: -10.0, through: 10.0, by: 0.5).map { pt($0, lowerMargin($0) - 0.15) })
        ctx.stroke(meniscus, with: .color(Self.fluorescein.opacity(0.75)), lineWidth: 0.25 * scale)
        lids(&ctx, skin: Color(red: 0.09, green: 0.07, blue: 0.22), shade: Color(red: 0.05, green: 0.04, blue: 0.14), lashes: Color(red: 0.02, green: 0.02, blue: 0.06), rim: Color(red: 0.2, green: 0.12, blue: 0.3))
        labels(&ctx, color: Color(red: 0.75, green: 0.8, blue: 1))
    }

    private func gpLens(_ ctx: inout GraphicsContext) {
        let center = SIMD2(0.0, 0.4)
        ctx.fill(circle(center, 4.6), with: .color(Self.fluorescein.opacity(0.16)))
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 0.2 * scale))
            layer.stroke(circle(center, 4.35), with: .color(Self.fluorescein.opacity(0.4)), lineWidth: 0.4 * scale)
        }
        ctx.stroke(circle(center, 4.6), with: .color(.black.opacity(0.5)), lineWidth: 0.06 * scale)
    }

    private func stainPoints() -> [SIMD2<Double>] {
        var rng = stream(7)
        let spread = severity.stainSpread * .pi / 180
        let cornea = Self.cornea
        switch problem.complication {
        case .threeNineStaining:
            return (0..<severity.stainDots).map { i in
                let side = i.isMultiple(of: 2) ? 0 : Double.pi
                let t = Double.random(in: -1...1, using: &rng) + .random(in: -1...1, using: &rng)
                return polar(.random(in: 4.85...(cornea - 0.2), using: &rng), side + t / 2 * spread)
            }
        case .seal:
            return (0..<severity.stainDots).map { _ in
                polar(.random(in: (cornea - 1)...(cornea - 0.35), using: &rng), -.pi / 2 + .random(in: -0.5...0.5, using: &rng) * spread)
            }
        case .inferiorStaining:
            var points: [SIMD2<Double>] = []
            while points.count < severity.stainDots {
                let r = 2.4 + (cornea - 0.35 - 2.4) * Double.random(in: 0...1, using: &rng).squareRoot()
                let p = polar(r, .pi / 2 + .random(in: -0.5...0.5, using: &rng) * spread)
                if p.y > Self.pupil { points.append(p) }
            }
            return points
        default:
            var points: [SIMD2<Double>] = []
            while points.count < severity.stainDots {
                let r = (cornea - 0.2) * Double.random(in: 0...1, using: &rng).squareRoot()
                let weight = 0.3 + 0.7 * min(1, max(0, (r - 1.8) / 2))
                let p = polar(r, .random(in: 0..<(2 * .pi), using: &rng))
                if Double.random(in: 0...1, using: &rng) < weight { points.append(p) }
            }
            return points
        }
    }

    private func stain(_ ctx: inout GraphicsContext, dots: [SIMD2<Double>]) {
        var glow = Path()
        var cores = Path()
        for dot in dots {
            glow.addPath(circle(dot, 0.12))
            cores.addPath(circle(dot, 0.055))
        }
        if severity.confluent {
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: 0.35 * scale))
                layer.fill(glow, with: .color(Self.fluorescein.opacity(0.22)))
            }
        }
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 0.1 * scale))
            layer.fill(glow, with: .color(Self.fluorescein.opacity(0.5)))
        }
        ctx.fill(cores, with: .color(Color(red: 0.75, green: 1, blue: 0.65).opacity(0.9)))
    }

    private func sealArc(_ ctx: inout GraphicsContext) {
        let span = severity.stainSpread * .pi / 180
        let radius = Self.cornea - 0.65
        if severity.confluent {
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: 0.2 * scale))
                layer.stroke(arc(radius: radius, center: -.pi / 2, span: span * 0.85), with: .color(Self.fluorescein.opacity(0.45)), style: StrokeStyle(lineWidth: 0.4 * scale, lineCap: .round))
            }
        }
        if severity.epithelialSplit {
            let split = arc(radius: radius, center: -.pi / 2, span: span * 0.6)
            ctx.stroke(split, with: .color(Color(red: 0.85, green: 1, blue: 0.75)), style: StrokeStyle(lineWidth: 0.22 * scale, lineCap: .round))
            ctx.stroke(split, with: .color(Color(red: 0.03, green: 0.06, blue: 0.14)), style: StrokeStyle(lineWidth: 0.07 * scale, lineCap: .round))
        }
    }

    // MARK: Everted lid

    private func tarsusTop(_ x: Double) -> Double { -5.6 + 0.02 * x * x }
    private func tarsusBottom(_ x: Double) -> Double { 1.4 - 0.045 * x * x }

    private func drawEvertedLid(_ ctx: inout GraphicsContext) {
        ctx.fill(Path(bounds), with: .color(Self.skin))
        var aperture = Path()
        aperture.addRect(CGRect(x: bounds.minX, y: origin.y - 1 * scale, width: bounds.width, height: 8.5 * scale))
        ctx.fill(aperture, with: .color(Color(red: 0.96, green: 0.92, blue: 0.9)))
        var eye = ctx
        eye.clip(to: aperture)
        var rng = stream(8)
        let colors = Self.irises.randomElement(using: &rng)!
        let corneaCenter = SIMD2(0.0, 5.3)
        eye.fill(circle(corneaCenter, Self.cornea), with: .radialGradient(
            Gradient(colors: [colors.0, colors.1]),
            center: pt(corneaCenter), startRadius: Self.pupil * scale, endRadius: Self.cornea * scale
        ))
        eye.fill(circle(corneaCenter, Self.pupil), with: .color(.black))

        let xs = stride(from: -12.0, through: 12.0, by: 0.5).map { $0 }
        var lowerLid = Path()
        lowerLid.addLines(xs.map { pt($0, 7.3 - 0.02 * $0 * $0) })
        lowerLid.addLine(to: CGPoint(x: bounds.maxX + 20, y: bounds.maxY + 20))
        lowerLid.addLine(to: CGPoint(x: bounds.minX - 20, y: bounds.maxY + 20))
        lowerLid.closeSubpath()
        ctx.fill(lowerLid, with: .color(Self.skin))

        let plateXs = stride(from: -9.5, through: 9.5, by: 0.25).map { $0 }
        var plate = Path()
        plate.addLines(plateXs.map { pt($0, tarsusTop($0)) } + plateXs.reversed().map { pt($0, tarsusBottom($0)) })
        plate.closeSubpath()
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 0.5 * scale))
            layer.fill(plate, with: .color(.black.opacity(0.3)))
        }
        let base = Color(red: 0.95 - 0.13 * severity.redness, green: 0.66 - 0.42 * severity.redness, blue: 0.62 - 0.36 * severity.redness)
        ctx.fill(plate, with: .linearGradient(Gradient(colors: [base, base.opacity(0.85)]), startPoint: pt(0, -5.6), endPoint: pt(0, 1.4)))

        var tarsal = ctx
        tarsal.clip(to: plate)
        var vessels = Path()
        for x in stride(from: -8.5, through: 8.5, by: 0.9) {
            vessels.move(to: pt(x, tarsusTop(x)))
            vessels.addQuadCurve(to: pt(x * 1.05, tarsusBottom(x)), control: pt(x + 0.3, (tarsusTop(x) + tarsusBottom(x)) / 2))
        }
        tarsal.stroke(vessels, with: .color(Self.red.opacity(0.5 * (1 - severity.papillaCoverage))), lineWidth: 0.08 * scale)
        papillae(&tarsal)
        for _ in 0..<severity.mucusStrands {
            let y = Double.random(in: -4 ... -0.5, using: &rng)
            let x0 = Double.random(in: -7 ... -2, using: &rng)
            let points = stride(from: x0, through: x0 + .random(in: 4...8, using: &rng), by: 0.5).map { SIMD2($0, y + 0.3 * sin($0 * 1.3)) }
            tarsal.stroke(smooth(points), with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: 0.18 * scale, lineCap: .round))
        }

        var rim = Path()
        rim.addLines(plateXs.map { pt($0, tarsusTop($0)) })
        ctx.stroke(rim, with: .color(Color(red: 0.86, green: 0.5, blue: 0.5)), lineWidth: 0.35 * scale)
        var lashes = Path()
        for x in stride(from: -9.0, through: 9.0, by: 0.32) {
            let reach = 1.1 + 0.35 * sin(x * 7.1)
            lashes.move(to: pt(x, tarsusTop(x) - 0.2))
            lashes.addQuadCurve(to: pt(x * 1.05, tarsusTop(x) - 0.2 - reach), control: pt(x, tarsusTop(x) - 0.2 - reach * 0.4))
        }
        ctx.stroke(lashes, with: .color(Color(red: 0.16, green: 0.11, blue: 0.08)), lineWidth: 0.08 * scale)
        ctx.draw(Text("\(problem.rightEye ? "OD" : "OS") · upper lid everted").font(.caption.weight(.bold)).foregroundStyle(Color(red: 0.35, green: 0.22, blue: 0.18)), at: pt(0, 7))
    }

    private func papillae(_ ctx: inout GraphicsContext) {
        var rng = stream(9)
        let size = severity.papillaSize
        let spacing = size * 1.15
        var row = 0
        var y = 1.4 - spacing / 2
        while y > -5.6 {
            var x = -9.5 + (row.isMultiple(of: 2) ? 0 : spacing / 2)
            while x < 9.5 {
                let top = tarsusTop(x), bottom = tarsusBottom(x)
                let depth = (bottom - y) / (bottom - top)
                if y < bottom - size * 0.3, y > top + size * 0.3, depth < severity.papillaCoverage {
                    let center = SIMD2(x + .random(in: -0.15...0.15, using: &rng) * spacing, y + .random(in: -0.15...0.15, using: &rng) * spacing)
                    let r = size / 2 * .random(in: 0.8...1.1, using: &rng)
                    ctx.fill(circle(center, r), with: .radialGradient(
                        Gradient(colors: [Color(red: 1, green: 0.8, blue: 0.76), Color(red: 0.86, green: 0.42, blue: 0.4), Color(red: 0.6, green: 0.2, blue: 0.2)]),
                        center: pt(center + [-r * 0.3, -r * 0.3]), startRadius: 0, endRadius: r * 1.3 * scale
                    ))
                    if size >= 0.4 {
                        ctx.fill(circle(center, r * 0.2), with: .color(Self.red.opacity(0.85)))
                    }
                }
                x += spacing
            }
            y -= spacing * 0.87
            row += 1
        }
    }
}

private nonisolated func length(_ v: SIMD2<Double>) -> Double {
    (v * v).sum().squareRoot()
}
