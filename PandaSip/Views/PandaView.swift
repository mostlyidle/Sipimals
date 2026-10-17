import SwiftUI

struct PandaView: View {
    let animal: AnimalKind
    let progress: Double
    var celebrating: Bool = false
    var loggedDrink: DrinkEntry? = nil
    var loggedDrinkOverflows: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var displayedProgress: Double
    @State private var fillIsMoving = false
    @State private var isOverflowing = false
    @State private var sloshStartedAt: Date?
    @State private var sloshStrength = 0.0
    @State private var animationCycle = 0
    @State private var lastAnimatedLogID: UUID?

    init(
        animal: AnimalKind = .panda,
        progress: Double,
        celebrating: Bool = false,
        loggedDrink: DrinkEntry? = nil,
        loggedDrinkOverflows: Bool = false
    ) {
        self.animal = animal
        self.progress = progress
        self.celebrating = celebrating
        self.loggedDrink = loggedDrink
        self.loggedDrinkOverflows = loggedDrinkOverflows
        _displayedProgress = State(initialValue: min(max(progress, 0), 1))
        _lastAnimatedLogID = State(initialValue: loggedDrink?.id)
    }

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 1 / 60,
                paused: reduceMotion || scenePhase != .active || (!fillIsMoving && (displayedProgress == 0 || displayedProgress == 1))
            )
        ) { context in
            GeometryReader { proxy in
                let scale = min(proxy.size.width / 270, proxy.size.height / 285)
                let seconds = context.date.timeIntervalSinceReferenceDate
                let phase = reduceMotion ? 0 : seconds * 1.5
                let slosh = sloshAt(context.date)

                animalArtwork(phase: phase, slosh: slosh)
                    .frame(width: 270, height: 285)
                    .scaleEffect(scale)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
        .aspectRatio(270.0 / 285.0, contentMode: .fit)
        .task(id: progress) {
            let clamped = min(max(progress, 0), 1)
            guard clamped != displayedProgress else { return }
            fillIsMoving = !reduceMotion
            updateProgress(to: clamped)
            if fillIsMoving {
                try? await Task.sleep(for: .seconds(1.2))
                if !Task.isCancelled { fillIsMoving = false }
            }
        }
        .task(id: animationCycle) {
            guard let loggedDrink, loggedDrink.creditedML > 0,
                  loggedDrink.id != lastAnimatedLogID else { return }
            lastAnimatedLogID = loggedDrink.id
            guard !reduceMotion else {
                fillIsMoving = false
                updateProgress(to: progress)
                return
            }
            fillIsMoving = true

            let now = Date.now
            if let sloshStartedAt, now.timeIntervalSince(sloshStartedAt) < 1.4 {
                sloshStrength = min(sloshStrength + 0.65, 1.8)
            } else {
                sloshStartedAt = now
                sloshStrength = 1
            }

            if loggedDrinkOverflows {
                withAnimation(.easeOut(duration: 0.18)) { isOverflowing = false }
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled, !reduceMotion else { return }
                withAnimation(.easeOut(duration: 0.3)) { isOverflowing = true }
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled, !reduceMotion else { return }
                withAnimation(.easeOut(duration: 0.28)) { isOverflowing = false }
            }

            try? await Task.sleep(for: .milliseconds(1_050))
            if !Task.isCancelled { fillIsMoving = false }
        }
        .onChange(of: reduceMotion) { _, isReduced in
            if isReduced {
                fillIsMoving = false
                isOverflowing = false
            }
            animationCycle += 1
            updateProgress(to: progress)
        }
        .onChange(of: loggedDrink?.id) { _, newID in
            if newID != nil { animationCycle += 1 }
        }
        .onDisappear {
            fillIsMoving = false
            isOverflowing = false
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(animal.accessibilityName)
        .accessibilityValue(accessibilityValue)
    }

    private var isHappy: Bool {
        celebrating || displayedProgress >= 1
    }

    private var accessibilityValue: String {
        let percentage = Int((min(max(progress, 0), 1) * 100).rounded(.down))
        return percentage >= 100 ? "Cup full. Goal reached" : "Cup \(percentage) percent full"
    }

    private func updateProgress(to newValue: Double) {
        let clamped = min(max(newValue, 0), 1)
        if reduceMotion {
            displayedProgress = clamped
        } else {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.84)) {
                displayedProgress = clamped
            }
        }
    }

    private func sloshAt(_ date: Date) -> Double {
        guard !reduceMotion, let sloshStartedAt else { return 0 }
        let elapsed = date.timeIntervalSince(sloshStartedAt)
        guard elapsed >= 0, elapsed < 1.4 else { return 0 }
        return sloshStrength * exp(-2.8 * elapsed) * sin(10 * elapsed)
    }

    private func animalArtwork(phase: Double, slosh: Double) -> some View {
        let side: CGFloat = 270
        let cupCenter = CGPoint(x: side * (animal == .fox ? 0.58 : 0.5), y: side * 0.70)
        let cupSize = CGSize(width: side * 0.39, height: side * 0.42)

        return ZStack {
            Image(animal.artworkName)
                .resizable()
                .scaledToFit()
                .frame(width: side, height: side)

            ZStack {
                LiquidWave(level: displayedProgress, phase: phase * 0.7, waves: 1.25, amplitude: 1.8, slosh: slosh)
                    .fill(Color(red: 0.35, green: 0.76, blue: 0.94).opacity(0.62))
                LiquidWave(level: displayedProgress, phase: -phase, waves: 1.75, amplitude: 2.6, slosh: slosh)
                    .fill(Color(red: 0.16, green: 0.60, blue: 0.88).opacity(0.58))
            }
            .frame(width: cupSize.width, height: cupSize.height)
            .mask(CupInterior())
            .blendMode(.multiply)
            .position(cupCenter)

            overflowDrops(cupCenter: cupCenter, cupHeight: cupSize.height)

            goalSparkles
                .opacity(isHappy ? 1 : 0)
        }
        .frame(width: side, height: side)
        .compositingGroup()
        .position(x: 135, y: 142.5)
    }

    private func overflowDrops(cupCenter: CGPoint, cupHeight: CGFloat) -> some View {
        // shortcut: flattened animal art keeps overflow to droplets above the shared cup rim.
        let offsets: [CGFloat] = [-13, 0, 13]
        return ForEach(0..<offsets.count, id: \.self) { index in
            Image(systemName: "drop.fill")
                .font(.system(size: index == 1 ? 12 : 10, weight: .semibold))
                .foregroundStyle(Color(red: 0.16, green: 0.60, blue: 0.88))
                .rotationEffect(.degrees(Double(index - 1) * 16))
                .position(x: cupCenter.x + offsets[index], y: cupCenter.y - cupHeight * 0.36)
                .offset(x: isOverflowing ? offsets[index] * 0.8 : 0, y: isOverflowing ? -3 : 0)
                .scaleEffect(isOverflowing ? 1 : 0.35)
                .opacity(isOverflowing ? 0.95 : 0)
                .animation(.easeOut(duration: 0.3).delay(Double(index) * 0.035), value: isOverflowing)
        }
    }

    private var goalSparkles: some View {
        ZStack {
            sparkle(size: 17, x: 38, y: 47, rotation: -12)
            sparkle(size: 13, x: 226, y: 40, rotation: 15)
            sparkle(size: 11, x: 244, y: 111, rotation: -18)
            sparkle(size: 9, x: 25, y: 124, rotation: 20)
        }
        .frame(width: 270, height: 270)
        .foregroundStyle(Color(red: 0.91, green: 0.65, blue: 0.17))
    }

    private func sparkle(size: CGFloat, x: CGFloat, y: CGFloat, rotation: Double) -> some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .semibold))
            .rotationEffect(.degrees(rotation))
            .position(x: x, y: y)
    }
}

private struct CupInterior: Shape {
    func path(in rect: CGRect) -> Path {
        // shortcut: all animals share one cup interior shape; add per-animal masks if their cups diverge.
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.13))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.maxY - rect.height * 0.08),
            control: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.maxY - rect.height * 0.18)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.24, y: rect.maxY - rect.height * 0.08),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.minY + rect.height * 0.13),
            control: CGPoint(x: rect.maxX - rect.width * 0.10, y: rect.maxY - rect.height * 0.18)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.13),
            control: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.17)
        )
        path.closeSubpath()
        return path
    }
}

private struct LiquidWave: Shape {
    var level: Double
    var phase: Double
    let waves: Double
    let amplitude: Double
    var slosh: Double

    var animatableData: Double {
        get { level }
        set { level = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let clampedLevel = min(max(level, 0), 1)
        let surface = rect.maxY - rect.height * CGFloat(clampedLevel)
        let edgeScale = sin(.pi * clampedLevel)
        let waveHeight = CGFloat((amplitude + abs(slosh) * 4.5) * edgeScale)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: surface + CGFloat(sin(phase)) * waveHeight))

        let steps = 72
        for step in 1...steps {
            let fraction = Double(step) / Double(steps)
            let angle = fraction * .pi * 2 * waves + phase
            let naturalSurface = sin(angle) * 0.62
                + sin(angle * 1.73 + phase * 0.72) * 0.25
                + sin(angle * 0.61 - phase * 0.55) * 0.13
            let tilt = CGFloat(slosh * (fraction - 0.5) * 15) * edgeScale
            path.addLine(to: CGPoint(
                x: rect.minX + rect.width * CGFloat(fraction),
                y: surface + tilt + CGFloat(naturalSurface) * waveHeight
            ))
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    PandaView(progress: 0.68)
        .frame(width: 270, height: 285)
        .padding()
        .background(Color(red: 0.97, green: 0.94, blue: 0.85))
}
