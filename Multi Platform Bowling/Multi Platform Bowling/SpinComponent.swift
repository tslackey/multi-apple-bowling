//
//  SpinComponent.swift
//  Multi Platform Bowling
//
//  Created by Scott Lackey on 9/4/26.
//

import RealityKit

/// A component that spins the entity around a given axis.
struct SpinComponent: Component {
    let spinAxis: SIMD3<Float> = [0, 1, 0]
}
