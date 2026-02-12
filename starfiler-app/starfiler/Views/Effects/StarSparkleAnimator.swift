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
