#if os(macOS) || os(tvOS)
import Foundation
import simd

enum LaneMetrics {
    static let surfaceY: Float = 0.085
    static let sectionLength: Float = 4
    static let sectionCount = 3
    static let laneWidth: Float = 1.05
    static let packWidth: Float = 1.55
    static let gutterWidth: Float = 0.25
    static let pinHeight: Float = 0.38
    static let pinRadius: Float = 0.06
    static let ballRadius: Float = 0.108
    static let pinSpacing: Float = 0.3048

    static var playfieldLength: Float {
        Float(sectionCount) * sectionLength
    }

    static var lastSectionZ: Float {
        -Float(sectionCount - 1) * sectionLength
    }

    /// Pin 1 sits near the far end of the last 4 m lane section.
    static var pinHeadZ: Float {
        lastSectionZ - 1.35
    }

    static var ballStart: SIMD3<Float> {
        SIMD3(0, surfaceY + ballRadius + 0.002, 1.45)
    }

    static var pinsetterZ: Float {
        pinHeadZ - 1.15
    }

    static func pinPositions() -> [SIMD3<Float>] {
        let spacing = pinSpacing
        let rowDepth = spacing * Float(3).squareRoot() / 2
        let z = pinHeadZ
        let y = surfaceY
        let layout: [(Float, Float)] = [
            (0, z),
            (-spacing / 2, z - rowDepth), (spacing / 2, z - rowDepth),
            (-spacing, z - 2 * rowDepth), (0, z - 2 * rowDepth), (spacing, z - 2 * rowDepth),
            (-1.5 * spacing, z - 3 * rowDepth), (-0.5 * spacing, z - 3 * rowDepth),
            (0.5 * spacing, z - 3 * rowDepth), (1.5 * spacing, z - 3 * rowDepth),
        ]
        return layout.map { SIMD3($0.0, y, $0.1) }
    }
}
#endif
