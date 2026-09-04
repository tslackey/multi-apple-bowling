#if os(macOS) || os(tvOS)
import RealityKit
import BowlingGameCore
import simd
#if os(macOS)
import AppKit
#else
import UIKit
#endif

@MainActor
final class LaneScene {
    let root = Entity()

    private var ball = Entity()
    private var pins: [Entity] = []
    private var pinRest: [SIMD3<Float>] = []
    private var library: Entity?

    func build() async {
        root.name = "Alley"
        root.components.set(PhysicsSimulationComponent())
        addLights()
        addCamera()
        addPitAndGutters()
        await addVisuals()
        addBall()
        addPins()
    }

    func apply(_ commit: ThrowCommit) {
        resetBallPose()
        var start = LaneMetrics.ballStart
        start.x = max(-0.38, min(0.38, Float(commit.approachOffset)))
        ball.position = start
        let velocity = ThrowMapper.laneVelocity(from: commit)
        ball.components.set(
            PhysicsMotionComponent(
                linearVelocity: velocity.linear,
                angularVelocity: velocity.angular
            )
        )
    }

    func reset() {
        resetBallPose()
        for (pin, position) in zip(pins, pinRest) {
            pin.position = position
            pin.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
            pin.components.set(PhysicsMotionComponent())
        }
    }

    func standingPinCount() -> Int {
        pins.filter { pin in
            let up = pin.convert(direction: SIMD3<Float>(0, 1, 0), to: nil)
            return up.y > 0.68 && pin.position.y > LaneMetrics.surfaceY - 0.04
        }.count
    }

    func isSettled(minimumTimeElapsed: Bool) -> Bool {
        guard minimumTimeElapsed else { return false }
        let ballSpeed = length(motion(of: ball).linearVelocity)
        guard ballSpeed < 0.22 else { return false }
        return pins.allSatisfy { length(motion(of: $0).linearVelocity) < 0.18 }
    }

    private func motion(of entity: Entity) -> PhysicsMotionComponent {
        entity.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
    }

    private func resetBallPose() {
        ball.position = LaneMetrics.ballStart
        ball.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
        ball.components.set(PhysicsMotionComponent())
    }

    private func addCamera() {
        let camera = Entity()
        camera.name = "Camera"
        camera.components.set(PerspectiveCameraComponent(near: 0.05, far: 80, fieldOfViewInDegrees: 48))
        camera.look(
            at: SIMD3<Float>(0, 0.22, -6.2),
            from: SIMD3<Float>(0, 1.62, 4.15),
            relativeTo: nil
        )
        root.addChild(camera)
    }

    private func addLights() {
        let sun = Entity()
        var directional = DirectionalLightComponent()
        directional.intensity = 1800
        sun.components.set(directional)
        sun.look(at: SIMD3<Float>(0, 0, -4), from: SIMD3<Float>(3.5, 8, 6), relativeTo: nil)
        root.addChild(sun)

        let key = Entity()
        var point = PointLightComponent()
        point.intensity = 2500
        point.attenuationRadius = 24
        key.components.set(point)
        key.position = SIMD3(0, 4.5, -3)
        root.addChild(key)

        let pinLight = Entity()
        var spot = PointLightComponent()
        spot.intensity = 1600
        spot.attenuationRadius = 10
        pinLight.components.set(spot)
        pinLight.position = SIMD3(0, 3.2, LaneMetrics.pinHeadZ)
        root.addChild(pinLight)
    }

    private func addPitAndGutters() {
        let laneLength = LaneMetrics.playfieldLength + 4
        let laneCenterZ = (2.5 + (LaneMetrics.lastSectionZ - 2)) / 2

        addStaticBox(
            name: "LaneCollision",
            size: [LaneMetrics.laneWidth, 0.08, laneLength],
            position: [0, LaneMetrics.surfaceY - 0.04, laneCenterZ],
            visible: false
        )

        for sign: Float in [-1, 1] {
            let x = sign * ((LaneMetrics.laneWidth / 2) + (LaneMetrics.gutterWidth / 2))
            addStaticBox(
                name: sign < 0 ? "LeftGutter" : "RightGutter",
                size: [LaneMetrics.gutterWidth, 0.06, laneLength],
                position: [x, LaneMetrics.surfaceY - 0.09, laneCenterZ],
                visible: false
            )
            addStaticBox(
                name: sign < 0 ? "LeftWall" : "RightWall",
                size: [0.06, 0.22, laneLength],
                position: [sign * (LaneMetrics.packWidth / 2), LaneMetrics.surfaceY + 0.05, laneCenterZ],
                visible: false
            )
        }

        addStaticBox(
            name: "Pit",
            size: [2.4, 0.08, 2.2],
            position: [0, -0.35, LaneMetrics.pinHeadZ - 1.6],
            visible: false
        )
        addStaticBox(
            name: "Backstop",
            size: [2.4, 1.4, 0.12],
            position: [0, 0.4, LaneMetrics.pinHeadZ - 2.55],
            visible: false
        )
    }

    private func addVisuals() async {
        if let url = Bundle.main.url(forResource: "LeagueNight", withExtension: "usdz") {
            library = try? await Entity(contentsOf: url)
        }
        if library == nil {
            library = try? await Entity(named: "LeagueNight")
        }

        if let library {
            for index in 0..<LaneMetrics.sectionCount {
                if let section = clone(library, "lane_section") {
                    section.position = SIMD3(0, 0, -Float(index) * LaneMetrics.sectionLength)
                    root.addChild(section)
                }
            }
            if let approach = clone(library, "lane_approach") {
                approach.position = SIMD3(0, 0, 2.99)
                root.addChild(approach)
            }
            if let pinsetter = clone(library, "pinsetter") {
                pinsetter.position = SIMD3(0, 0, LaneMetrics.pinsetterZ)
                root.addChild(pinsetter)
                addStaticBox(
                    name: "PinsetterCollision",
                    size: [1.17, 1.0, 1.03],
                    position: [0, 0.52, LaneMetrics.pinsetterZ],
                    visible: false
                )
            }
            if let ballReturn = clone(library, "ball_return") {
                ballReturn.position = SIMD3(1.28, 0, 1.4)
                root.addChild(ballReturn)
            }
            if let rack = clone(library, "ball_rack") {
                rack.position = SIMD3(-1.32, 0, 1.35)
                root.addChild(rack)
            }
            if let balls = clone(library, "house_balls") {
                balls.position = SIMD3(-1.32, 0, 1.35)
                root.addChild(balls)
            }
            if let bench = clone(library, "lane_bench_row") {
                bench.position = SIMD3(-1.85, 0, 2.4)
                root.addChild(bench)
            }
            if let sign = clone(library, "bowl_sign") {
                sign.position = SIMD3(2.1, 0, LaneMetrics.pinHeadZ - 2.2)
                root.addChild(sign)
            }
        } else {
            addPrimitiveLane()
        }
    }

    private func clone(_ library: Entity, _ name: String) -> Entity? {
        library.findEntity(named: name)?.clone(recursive: true)
    }

    private func shade(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> SimpleMaterial.Color {
        SimpleMaterial.Color(red: red, green: green, blue: blue, alpha: 1)
    }

    private func addPrimitiveLane() {
        addStaticBox(
            name: "LaneVisual",
            size: [LaneMetrics.laneWidth, 0.08, LaneMetrics.playfieldLength + 3],
            position: [0, LaneMetrics.surfaceY - 0.04, -3.2],
            visible: true,
            color: shade(0.76, 0.55, 0.32)
        )
        addStaticBox(
            name: "ApproachVisual",
            size: [LaneMetrics.laneWidth, 0.08, 1.2],
            position: [0, LaneMetrics.surfaceY - 0.04, 2.9],
            visible: true,
            color: shade(0.62, 0.44, 0.26)
        )
        for sign: Float in [-1, 1] {
            addStaticBox(
                name: "GutterVisual",
                size: [LaneMetrics.gutterWidth, 0.05, LaneMetrics.playfieldLength + 3],
                position: [
                    sign * ((LaneMetrics.laneWidth / 2) + LaneMetrics.gutterWidth / 2),
                    LaneMetrics.surfaceY - 0.09,
                    -3.2,
                ],
                visible: true,
                color: shade(0.12, 0.12, 0.14)
            )
        }
    }

    private func addBall() {
        ball = Entity()
        ball.name = "Ball"
        let radius = LaneMetrics.ballRadius
        let mesh = MeshResource.generateSphere(radius: radius)
        var material = SimpleMaterial()
        material.color = .init(tint: shade(0.08, 0.12, 0.28))
        ball.components.set(ModelComponent(mesh: mesh, materials: [material]))
        let shape = ShapeResource.generateSphere(radius: radius)
        ball.components.set(CollisionComponent(shapes: [shape]))
        var body = PhysicsBodyComponent(
            massProperties: .init(mass: 6.4),
            material: PhysicsMaterialResource.generate(staticFriction: 0.28, dynamicFriction: 0.22, restitution: 0.18),
            mode: .dynamic
        )
        body.linearDamping = 0.12
        body.angularDamping = 0.28
        ball.components.set(body)
        ball.components.set(PhysicsMotionComponent())
        ball.position = LaneMetrics.ballStart
        root.addChild(ball)
    }

    private func addPins() {
        pinRest = LaneMetrics.pinPositions()
        let pinMesh: MeshResource
        let pinModel: Entity?
        if let library, let template = clone(library, "bowling_pin") {
            pinModel = template
            pinMesh = MeshResource.generateCylinder(height: LaneMetrics.pinHeight, radius: LaneMetrics.pinRadius)
        } else {
            pinModel = nil
            pinMesh = MeshResource.generateCylinder(height: LaneMetrics.pinHeight, radius: LaneMetrics.pinRadius)
        }

        var pinMaterial = SimpleMaterial()
        pinMaterial.color = .init(tint: shade(0.93, 0.9, 0.82))
        let shape = ShapeResource.generateCapsule(
            height: LaneMetrics.pinHeight - LaneMetrics.pinRadius * 2,
            radius: LaneMetrics.pinRadius
        )

        for (index, position) in pinRest.enumerated() {
            let pin = Entity()
            pin.name = "Pin\(index + 1)"
            if let pinModel {
                let visual = pinModel.clone(recursive: true)
                pin.addChild(visual)
            } else {
                pin.components.set(ModelComponent(mesh: pinMesh, materials: [pinMaterial]))
            }
            pin.components.set(CollisionComponent(shapes: [shape]))
            var body = PhysicsBodyComponent(
                massProperties: .init(mass: 1.5),
                material: PhysicsMaterialResource.generate(staticFriction: 0.2, dynamicFriction: 0.16, restitution: 0.42),
                mode: .dynamic
            )
            body.linearDamping = 0.2
            body.angularDamping = 0.18
            pin.components.set(body)
            pin.components.set(PhysicsMotionComponent())
            pin.position = position
            root.addChild(pin)
            pins.append(pin)
        }
    }

    private func addStaticBox(
        name: String,
        size: SIMD3<Float>,
        position: SIMD3<Float>,
        visible: Bool,
        color: SimpleMaterial.Color = SimpleMaterial.Color(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
    ) {
        let entity = Entity()
        entity.name = name
        let mesh = MeshResource.generateBox(size: size)
        if visible {
            var material = SimpleMaterial()
            material.color = .init(tint: color)
            entity.components.set(ModelComponent(mesh: mesh, materials: [material]))
        }
        let shape = ShapeResource.generateBox(size: size)
        entity.components.set(CollisionComponent(shapes: [shape]))
        entity.components.set(
            PhysicsBodyComponent(
                massProperties: .default,
                material: PhysicsMaterialResource.generate(staticFriction: 0.4, dynamicFriction: 0.32, restitution: 0.08),
                mode: .static
            )
        )
        entity.position = position
        root.addChild(entity)
    }
}
#endif
