import SwiftUI

enum Trainer: String, CaseIterable, Identifiable {
    case lensometer, frameAdjustment, pdMeasure, prism, ansiCheck, lensChoice
    case keratometer, fluorescein, softLensFit, toricRotation, lensProblems

    var id: String { rawValue }

    var exam: ExamID {
        switch self {
        case .lensometer, .frameAdjustment, .pdMeasure, .prism, .ansiCheck, .lensChoice: .abo
        case .keratometer, .fluorescein, .softLensFit, .toricRotation, .lensProblems: .ncle
        }
    }

    var title: String {
        switch self {
        case .lensometer: "Lensometer"
        case .frameAdjustment: "Frame Adjusting"
        case .pdMeasure: "PD & Seg Height"
        case .prism: "Prism & Base"
        case .ansiCheck: "ANSI Job Check"
        case .lensChoice: "Lens Choice"
        case .keratometer: "Keratometer"
        case .fluorescein: "Fluorescein"
        case .softLensFit: "Soft Lens Fit"
        case .toricRotation: "Toric Rotation"
        case .lensProblems: "Lens Problems"
        }
    }

    var subtitle: String {
        switch self {
        case .lensometer: "Read lenses by hand"
        case .frameAdjustment: "Fix a frame that fits wrong"
        case .pdMeasure: "Measure on a patient"
        case .prism: "Prentice's rule, base direction"
        case .ansiCheck: "Pass or fail a finished pair"
        case .lensChoice: "Pick material, design, coatings"
        case .keratometer: "Align the mires, read K"
        case .fluorescein: "Judge GP fit patterns"
        case .softLensFit: "Tight, loose or good?"
        case .toricRotation: "Read rotation, apply LARS"
        case .lensProblems: "Name it, grade it, next step"
        }
    }

    var symbol: String {
        switch self {
        case .lensometer: "scope"
        case .frameAdjustment: "eyeglasses"
        case .pdMeasure: "ruler"
        case .prism: "triangle"
        case .ansiCheck: "checkmark.shield"
        case .lensChoice: "square.stack.3d.up"
        case .keratometer: "circle.circle"
        case .fluorescein: "eye.circle"
        case .softLensFit: "circle.dashed"
        case .toricRotation: "arrow.triangle.2.circlepath"
        case .lensProblems: "cross.case"
        }
    }

    static func available(for exam: ExamID) -> [Trainer] { allCases.filter { $0.exam == exam } }

    @MainActor @ViewBuilder
    var screen: some View {
        switch self {
        case .lensometer: LensometerTrainerView()
        case .frameAdjustment: FrameAdjustmentTrainerView()
        case .pdMeasure: PDMeasureTrainerView()
        case .prism: PrismDirectionTrainerView()
        case .ansiCheck: ANSIJobCheckView()
        case .lensChoice: LensChoiceTrainerView()
        case .keratometer: KeratometerTrainerView()
        case .fluorescein: FluoresceinTrainerView()
        case .softLensFit: SoftLensFitTrainerView()
        case .toricRotation: ToricRotationTrainerView()
        case .lensProblems: LensComplicationTrainerView()
        }
    }
}
