import SwiftUI

struct ConfettiView: View {
    private let started = Date()
    private let particles: [Particle] = (0..<48).map { index in
        var generator = SeededGenerator(seed: UInt64(index + 1) * 9_973)
        return Particle(
            x: CGFloat.random(in: 0.05...0.95, using: &generator),
            delay: Double.random(in: 0...0.4, using: &generator),
            speed: CGFloat.random(in: 280...520, using: &generator),
            drift: CGFloat.random(in: -36...36, using: &generator),
            spin: Double.random(in: 0...6, using: &generator),
            color: [Color.red, Color.orange, Color.yellow, Color.green, Color.blue, Color.pink][index % 6]
        )
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSince(started)
                for particle in particles {
                    let age = time - particle.delay
                    guard age > 0, age < 2.6 else { continue }
                    let y = age * particle.speed
                    let x = particle.x * size.width + sin(age * particle.spin) * particle.drift
                    let rect = CGRect(x: x, y: y, width: 8, height: 14)
                    var piece = context
                    piece.translateBy(x: rect.midX, y: rect.midY)
                    piece.rotate(by: .degrees(age * 140))
                    piece.fill(
                        Path(roundedRect: CGRect(x: -4, y: -7, width: 8, height: 14), cornerRadius: 2),
                        with: .color(particle.color)
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

private struct Particle {
    var x: CGFloat
    var delay: TimeInterval
    var speed: CGFloat
    var drift: CGFloat
    var spin: Double
    var color: Color
}

private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1
        return state
    }
}
