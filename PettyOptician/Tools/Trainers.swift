import SwiftUI

enum Trainer: String, CaseIterable, Identifiable {
    case lensometer, frameAdjustment, pdMeasure, prism, ansiCheck
    case keratometer, fluorescein, softLensFit, toricRotation

    var id: String { rawValue }

    var exam: ExamID {
        switch self {
        case .lensometer, .frameAdjustment, .pdMeasure, .prism, .ansiCheck: .abo
        case .keratometer, .fluorescein, .softLensFit, .toricRotation: .ncle
        }
    }

    var title: String {
        switch self {
        case .lensometer: "Lensometer"
        case .frameAdjustment: "Frame Adjusting"
        case .pdMeasure: "PD & Seg Height"
        case .prism: "Prism & Base"
        case .ansiCheck: "ANSI Job Check"
        case .keratometer: "Keratometer"
        case .fluorescein: "Fluorescein"
        case .softLensFit: "Soft Lens Fit"
        case .toricRotation: "Toric Rotation"
        }
    }

    var subtitle: String {
        switch self {
        case .lensometer: "Read lenses by hand"
        case .frameAdjustment: "Fix a frame that fits wrong"
        case .pdMeasure: "Measure on a patient"
        case .prism: "Prentice's rule, base direction"
        case .ansiCheck: "Pass or fail a finished pair"
        case .keratometer: "Align the mires, read K"
        case .fluorescein: "Judge GP fit patterns"
        case .softLensFit: "Tight, loose or good?"
        case .toricRotation: "Read rotation, apply LARS"
        }
    }

    var symbol: String {
        switch self {
        case .lensometer: "scope"
        case .frameAdjustment: "eyeglasses"
        case .pdMeasure: "ruler"
        case .prism: "triangle"
        case .ansiCheck: "checkmark.shield"
        case .keratometer: "circle.circle"
        case .fluorescein: "eye.circle"
        case .softLensFit: "circle.dashed"
        case .toricRotation: "arrow.triangle.2.circlepath"
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
        case .keratometer: KeratometerTrainerView()
        case .fluorescein: FluoresceinTrainerView()
        case .softLensFit: SoftLensFitTrainerView()
        case .toricRotation: ToricRotationTrainerView()
        }
    }
}
