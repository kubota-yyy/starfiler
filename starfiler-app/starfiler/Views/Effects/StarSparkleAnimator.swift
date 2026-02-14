import AppKit

final class StarSparkleAnimator: NSObject, CAAnimationDelegate {
    private static let maxParticles = 12

    static func burst(count: Int, in layer: CALayer, at point: CGPoint, color: NSColor, size: CGFloat = 6, duration: CFTimeInterval = 0.35) {
        let clampedCount = min(count, maxParticles)
        for _ in 0 ..< clampedCount {
            let starLayer = CAShapeLayer()
            starLayer.path = starPath(size: size)
            starLayer.fillColor = color.cgColor
            starLayer.position = point
            starLayer.opacity = 0
            layer.addSublayer(starLayer)

            let angle = CGFloat.random(in: 0 ..< .pi * 2)
            let distance = CGFloat.random(in: 30 ... 60)
            let endPoint = CGPoint(
                x: point.x + cos(angle) * distance,
                y: point.y + sin(angle) * distance
            )

            let positionAnim = CABasicAnimation(keyPath: "position")
            positionAnim.fromValue = NSValue(point: point)
            positionAnim.toValue = NSValue(point: endPoint)

            let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
            scaleAnim.fromValue = 0.3
            scaleAnim.toValue = 1.0

            let opacityAnim = CAKeyframeAnimation(keyPath: "opacity")
            opacityAnim.values = [1.0, 0.8, 0.0]
            opacityAnim.keyTimes = [0, 0.4, 1.0]

            let group = CAAnimationGroup()
            group.animations = [positionAnim, scaleAnim, opacityAnim]
            group.duration = duration
            group.timingFunction = CAMediaTimingFunction(name: .easeOut)
            group.isRemovedOnCompletion = false
            group.fillMode = .forwards

            let delegate = StarSparkleAnimator()
            delegate.layerToRemove = starLayer
            group.delegate = delegate

            starLayer.add(group, forKey: "burstAnimation")
        }
    }

    static func singleStar(in layer: CALayer, at point: CGPoint, color: NSColor, size: CGFloat = 12, duration: CFTimeInterval = 0.45, rotation: CGFloat = .pi) {
        let starLayer = CAShapeLayer()
        starLayer.path = starPath(size: size)
        starLayer.fillColor = color.cgColor
        starLayer.position = point
        starLayer.opacity = 0

        layer.addSublayer(starLayer)

        let scaleAnim = CAKeyframeAnimation(keyPath: "transform.scale")
        scaleAnim.values = [0.3, 1.2, 1.0]
        scaleAnim.keyTimes = [0, 0.5, 1.0]

        let rotationAnim = CABasicAnimation(keyPath: "transform.rotation.z")
        rotationAnim.fromValue = 0
        rotationAnim.toValue = rotation

        let opacityAnim = CAKeyframeAnimation(keyPath: "opacity")
        opacityAnim.values = [1.0, 1.0, 0.0]
        opacityAnim.keyTimes = [0, 0.6, 1.0]

        let group = CAAnimationGroup()
        group.animations = [scaleAnim, rotationAnim, opacityAnim]
        group.duration = duration
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards

        let delegate = StarSparkleAnimator()
        delegate.layerToRemove = starLayer
        group.delegate = delegate

        starLayer.add(group, forKey: "singleStarAnimation")
    }

    static func shootingStar(
        in layer: CALayer,
        accentColor: NSColor,
        glowColor: NSColor,
        duration: CFTimeInterval = 1.05
    ) {
        let bounds = layer.bounds
        guard bounds.width > 120, bounds.height > 80 else {
            return
        }

        let startY = bounds.maxY * CGFloat.random(in: 0.62 ... 0.9)
        let startPoint = CGPoint(x: bounds.minX - 96, y: startY)
        let deltaY = bounds.height * CGFloat.random(in: 0.22 ... 0.36)
        let endY = max(bounds.minY + 36, startY - deltaY)
        let endPoint = CGPoint(x: bounds.maxX + 72, y: endY)

        let flightLayer = CALayer()
        flightLayer.frame = bounds
        flightLayer.masksToBounds = true
        flightLayer.zPosition = 9_999
        layer.addSublayer(flightLayer)

        let headingLayer = CALayer()
        headingLayer.position = startPoint
        headingLayer.transform = CATransform3DMakeRotation(
            atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x),
            0,
            0,
            1
        )
        flightLayer.addSublayer(headingLayer)

        let trailLength = min(max(bounds.width * 0.22, 90), 180)
        let trailPath = CGMutablePath()
        trailPath.move(to: CGPoint(x: -trailLength, y: 0))
        trailPath.addLine(to: .zero)

        let trailLayer = CAShapeLayer()
        trailLayer.path = trailPath
        trailLayer.strokeColor = glowColor.withAlphaComponent(0.9).cgColor
        trailLayer.lineWidth = 2.8
        trailLayer.lineCap = .round
        trailLayer.opacity = 0
        trailLayer.shadowColor = glowColor.cgColor
        trailLayer.shadowOpacity = 0.9
        trailLayer.shadowRadius = 7
        trailLayer.shadowOffset = .zero
        headingLayer.addSublayer(trailLayer)

        let coreLayer = CAShapeLayer()
        coreLayer.path = starPath(size: 12)
        coreLayer.fillColor = accentColor.cgColor
        coreLayer.position = .zero
        coreLayer.opacity = 0
        coreLayer.shadowColor = glowColor.cgColor
        coreLayer.shadowOpacity = 0.95
        coreLayer.shadowRadius = 9
        coreLayer.shadowOffset = .zero
        headingLayer.addSublayer(coreLayer)

        let haloLayer = CAShapeLayer()
        haloLayer.path = starPath(size: 20)
        haloLayer.fillColor = glowColor.withAlphaComponent(0.32).cgColor
        haloLayer.position = .zero
        haloLayer.opacity = 0
        headingLayer.addSublayer(haloLayer)

        let movement = CABasicAnimation(keyPath: "position")
        movement.fromValue = NSValue(point: startPoint)
        movement.toValue = NSValue(point: endPoint)
        movement.duration = duration
        movement.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 0.61, 0.36, 1)

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0.0, 1.0, 1.0, 0.0]
        opacity.keyTimes = [0.0, 0.08, 0.82, 1.0]
        opacity.duration = duration
        opacity.isRemovedOnCompletion = false
        opacity.fillMode = .forwards

        let coreScale = CAKeyframeAnimation(keyPath: "transform.scale")
        coreScale.values = [0.45, 1.0, 0.8]
        coreScale.keyTimes = [0.0, 0.15, 1.0]
        coreScale.duration = duration
        coreScale.isRemovedOnCompletion = false
        coreScale.fillMode = .forwards

        let haloScale = CAKeyframeAnimation(keyPath: "transform.scale")
        haloScale.values = [0.3, 1.0, 1.2]
        haloScale.keyTimes = [0.0, 0.25, 1.0]
        haloScale.duration = duration
        haloScale.isRemovedOnCompletion = false
        haloScale.fillMode = .forwards

        let impactX = bounds.maxX - 18
        let denominator = endPoint.x - startPoint.x
        let impactProgress = denominator == 0 ? 1 : (impactX - startPoint.x) / denominator
        let clampedImpactProgress = min(max(impactProgress, 0), 1)
        let impactPoint = CGPoint(
            x: startPoint.x + (endPoint.x - startPoint.x) * clampedImpactProgress,
            y: startPoint.y + (endPoint.y - startPoint.y) * clampedImpactProgress
        )

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            burst(
                count: 8,
                in: layer,
                at: impactPoint,
                color: glowColor,
                size: 6,
                duration: 0.35
            )
            flightLayer.removeFromSuperlayer()
        }

        headingLayer.add(movement, forKey: "shootingStarMove")
        trailLayer.add(opacity, forKey: "shootingStarTrailOpacity")
        coreLayer.add(opacity, forKey: "shootingStarCoreOpacity")
        coreLayer.add(coreScale, forKey: "shootingStarCoreScale")
        haloLayer.add(opacity, forKey: "shootingStarHaloOpacity")
        haloLayer.add(haloScale, forKey: "shootingStarHaloScale")
        CATransaction.commit()
    }

    private static func starPath(size: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let points = 5
        let outerRadius = size / 2
        let innerRadius = outerRadius * 0.38

        for i in 0 ..< points * 2 {
            let angle = CGFloat(i) * .pi / CGFloat(points) - .pi / 2
            let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
            let x = cos(angle) * radius
            let y = sin(angle) * radius

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }

    static func makeRemovalDelegate(for layer: CALayer) -> StarSparkleAnimator {
        let instance = StarSparkleAnimator()
        instance.layerToRemove = layer
        return instance
    }

    private var layerToRemove: CALayer?

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        layerToRemove?.removeFromSuperlayer()
        layerToRemove = nil
    }
}
