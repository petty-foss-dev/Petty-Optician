import Foundation

struct SpheroCylinder: Equatable, Sendable {
    var sphere: Double
    var cylinder: Double
    var axis: Int
}

enum OpticsMath {
    static func transpose(_ rx: SpheroCylinder) -> SpheroCylinder {
        let axis = rx.axis > 90 ? rx.axis - 90 : rx.axis + 90
        return SpheroCylinder(sphere: rx.sphere + rx.cylinder, cylinder: -rx.cylinder, axis: axis)
    }

    static func sphericalEquivalent(sphere: Double, cylinder: Double) -> Double {
        sphere + cylinder / 2
    }

    /// Power needed at a new vertex position; `moveMM` is positive when the lens moves toward the eye.
    static func compensatedPower(_ power: Double, moveMM: Double) -> Double {
        power / (1 - (moveMM / 1000) * power)
    }

    static func prenticePrism(decentrationMM: Double, power: Double) -> Double {
        abs(decentrationMM / 10 * power)
    }

    /// Power in a meridian `degrees` away from the cylinder axis (sin² approximation).
    static func obliquePower(_ rx: SpheroCylinder, meridian: Int) -> Double {
        let theta = Double(meridian - rx.axis) * .pi / 180
        return rx.sphere + rx.cylinder * pow(sin(theta), 2)
    }

    static func keratometricDiopters(radiusMM: Double) -> Double { 337.5 / radiusMM }

    static func radiusMM(diopters: Double) -> Double { 337.5 / diopters }

    /// Tear lens power: base curve steeper than flat K → plus tear lens.
    static func tearLensPower(baseCurveMM: Double, flatKMM: Double) -> Double {
        keratometricDiopters(radiusMM: baseCurveMM) - keratometricDiopters(radiusMM: flatKMM)
    }

    static func minimumBlankSize(effectiveDiameter: Double, framePD: Double, patientPD: Double) -> Double {
        effectiveDiameter + (framePD - patientPD) + 2
    }

    /// Near PD by similar triangles; 27 mm ≈ 13 mm vertex + 14 mm to center of rotation.
    static func nearPD(distancePD: Double, workingDistanceMM: Double) -> Double {
        distancePD * workingDistanceMM / (workingDistanceMM + 27)
    }

    /// LARS: rotation to the examiner's left (clockwise) adds; to the right subtracts.
    static func compensatedToricAxis(_ axis: Int, rotation: Int, toLeft: Bool) -> Int {
        let raw = (axis + (toLeft ? rotation : -rotation)) % 180
        let wrapped = raw <= 0 ? raw + 180 : raw
        return wrapped
    }

    /// RGP power: spectacle sphere at the cornea minus the tear-lens power.
    static func rigidLensPower(sphere: Double, vertexMM: Double, baseCurveMM: Double, flatKDiopters: Double) -> Double {
        compensatedPower(sphere, moveMM: vertexMM) - tearLensPower(baseCurveMM: baseCurveMM, flatKMM: radiusMM(diopters: flatKDiopters))
    }

    /// Dk/t in ×10⁻⁹ units from Dk (×10⁻¹¹) and center thickness in mm.
    static func oxygenTransmissibility(dk: Double, thicknessMM: Double) -> Double {
        dk / (thicknessMM * 10)
    }

    /// Exact sagitta (mm) of a surface of power F for a chord of half-diameter y (mm).
    static func sagitta(power: Double, index: Double, semiDiameterMM y: Double) -> Double? {
        guard power != 0 else { return 0 }
        let r = 1000 * (index - 1) / abs(power)
        guard r > y else { return nil }
        return r - (r * r - y * y).squareRoot()
    }

    static func roundToQuarter(_ value: Double) -> Double { (value * 4).rounded() / 4 }

    static func formatPower(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        if rounded == 0 { return "0.00" }
        return (rounded > 0 ? "+" : "−") + String(format: "%.2f", abs(rounded))
    }
}
