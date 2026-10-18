import SwiftUI

struct PandaView: View {
    private static let rigCanvasSize: CGFloat = 1254
    private static let rigOverlap: CGFloat = 24

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
                paused: reduceMotion || scenePhase != .active || (!fillIsMoving && displayedProgress == 0)
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
        let cup = cupInteriorBounds.applying(CGAffineTransform(scaleX: side / Self.rigCanvasSize, y: side / Self.rigCanvasSize))

        return ZStack {
            animalCharacterArtwork

            cupBrim(cup: cup)

            ZStack {
                LiquidWave(level: displayedProgress, phase: phase * 0.7, waves: 1.25, amplitude: 1.8, slosh: slosh)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.35, green: 0.76, blue: 0.94), Color(red: 0.18, green: 0.62, blue: 0.89)],
                        startPoint: .top,
                        endPoint: .bottom
                    ).opacity(0.92))
                LiquidWave(level: displayedProgress, phase: -phase, waves: 1.75, amplitude: 2.6, slosh: slosh)
                    .fill(Color(red: 0.16, green: 0.60, blue: 0.88).opacity(0.58))
            }
            .frame(width: cup.width, height: cup.height)
            .mask(CupInterior())
            .position(x: cup.midX, y: cup.midY)
            .frame(width: side, height: side)
            .mask(Rectangle().subtracting(AnimalPawOcclusion(animal: animal)))

            cupOverflow(cup: cup, phase: phase)

            goalSparkles
                .opacity(isHappy ? 1 : 0)
        }
        .frame(width: side, height: side)
        .compositingGroup()
        .position(x: 135, y: 142.5)
    }

    private var cupInteriorBounds: CGRect {
        // Bounds follow each illustrated front rim and inner floor, not the outer glass base.
        switch animal {
        case .panda: CGRect(x: 427, y: 735, width: 402, height: 370)
        case .fox: CGRect(x: 548, y: 720, width: 351, height: 370)
        case .rabbit: CGRect(x: 447, y: 765, width: 363, height: 335)
        case .capybara: CGRect(x: 445, y: 695, width: 405, height: 370)
        case .giraffe: CGRect(x: 430, y: 740, width: 403, height: 365)
        case .monkey: CGRect(x: 420, y: 740, width: 413, height: 365)
        case .pig: CGRect(x: 430, y: 740, width: 403, height: 365)
        }
    }

    private var cupOpeningBounds: CGRect {
        // The oval opening sits above the front rim used by the main liquid mask.
        switch animal {
        case .panda: CGRect(x: 414, y: 667, width: 429, height: 61)
        case .fox: CGRect(x: 538, y: 653, width: 370, height: 57)
        case .rabbit: CGRect(x: 435, y: 694, width: 383, height: 58)
        case .capybara: CGRect(x: 425, y: 619, width: 443, height: 62)
        case .giraffe: CGRect(x: 418, y: 668, width: 420, height: 60)
        case .monkey: CGRect(x: 412, y: 673, width: 430, height: 55)
        case .pig: CGRect(x: 417, y: 668, width: 422, height: 59)
        }
    }

    private func cupBrim(cup: CGRect) -> some View {
        let opening = cupOpeningBounds.applying(CGAffineTransform(scaleX: 270 / Self.rigCanvasSize, y: 270 / Self.rigCanvasSize))
        var volume = Path(ellipseIn: opening)
        volume.move(to: CGPoint(x: opening.minX, y: opening.midY))
        volume.addLine(to: CGPoint(x: opening.maxX, y: opening.midY))
        volume.addLine(to: CGPoint(x: cup.maxX, y: cup.minY + 0.5))
        volume.addLine(to: CGPoint(x: cup.minX, y: cup.minY + 0.5))
        volume.closeSubpath()

        return ZStack {
            volume.fill(Color(red: 0.35, green: 0.76, blue: 0.94).opacity(0.92))
            volume.fill(Color(red: 0.16, green: 0.60, blue: 0.88).opacity(0.58))
            Ellipse()
                .fill(LinearGradient(colors: [.white.opacity(0.20), .clear], startPoint: .top, endPoint: .bottom))
                .overlay { Ellipse().stroke(.white.opacity(0.65), lineWidth: 0.6) }
                .frame(width: opening.width, height: opening.height)
                .position(x: opening.midX, y: opening.midY)
        }
        .frame(width: 270, height: 270)
        .mask(Rectangle().subtracting(AnimalPawOcclusion(animal: animal)))
        .modifier(CupTopVisibility(level: displayedProgress, goalReached: progress >= 1))
        .allowsHitTesting(false)
    }

    private var animalCharacterArtwork: some View {
        ZStack {
            Image("\(animal.rawValue.capitalized)RigBody")
                .resizable()
                .frame(width: 270, height: 270 * (Self.rigCanvasSize - headSplitY + Self.rigOverlap) / Self.rigCanvasSize)
                .frame(width: 270, height: 270, alignment: .bottom)

            if reduceMotion || scenePhase != .active {
                animalHeadLayer
            } else {
                animalHeadLayer
                    .phaseAnimator([0.0, -1.0, 0.0, 1.0]) { content, angle in
                        content
                            .rotationEffect(
                                .degrees(angle),
                                anchor: UnitPoint(x: 0.5, y: headPivotY)
                            )
                    } animation: { _ in
                        .easeInOut(duration: 3.2)
                    }
            }
        }
        .frame(width: 270, height: 270)
    }

    private var animalHeadLayer: some View {
        Image("\(animal.rawValue.capitalized)RigHead")
            .resizable()
            .frame(width: 270, height: 270 * (headSplitY + Self.rigOverlap) / Self.rigCanvasSize)
            .frame(width: 270, height: 270, alignment: .top)
    }

    private var headSplitY: CGFloat {
        switch animal {
        case .panda: 640
        case .fox: 620
        case .rabbit: 650
        case .capybara: 570
        case .giraffe: 630
        case .monkey: 650
        case .pig: 670
        }
    }

    private var headPivotY: CGFloat { headSplitY / Self.rigCanvasSize }

    private func cupOverflow(cup: CGRect, phase: Double) -> some View {
        // Canvas needs drawing space above the lip and below the outer glass base for detached drops.
        let height = cup.height * 1.24 + 20
        return CupOverflow(phase: phase, surge: isOverflowing ? 1 : 0, cupHeight: cup.height)
            .frame(width: cup.width, height: height)
            .position(x: cup.midX, y: cup.minY - 6 + height / 2)
            .frame(width: 270, height: 270)
            .mask(Rectangle().subtracting(AnimalPawOcclusion(animal: animal)))
            .modifier(CupTopVisibility(level: displayedProgress, goalReached: progress >= 1))
            .allowsHitTesting(false)
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

nonisolated private struct CupTopVisibility: AnimatableModifier {
    var level: Double
    let goalReached: Bool

    var animatableData: Double {
        get { level }
        set { level = newValue }
    }

    func body(content: Content) -> some View {
        // Match LiquidWave's spring presentation, not the @State target that jumps ahead of it.
        content.opacity(goalReached ? min(max((level - 0.995) / 0.005, 0), 1) : 0)
    }
}

nonisolated private struct CupOverflow: View, Animatable {
    let phase: Double
    var surge: Double
    let cupHeight: CGFloat

    var animatableData: Double {
        get { surge }
        set { surge = newValue }
    }

    var body: some View {
        Canvas { context, size in
            context.translateBy(x: 0, y: 6)
            let seconds = phase / 1.5
            // shortcut: gravity-led pulses and edge shading approximate wet glass; use refraction shaders for optical accuracy.
            for stream in [(x: 0.29, width: 0.043, drift: 0.026, period: 2.7, offset: 0.17),
                           (x: 0.69, width: 0.024, drift: -0.019, period: 3.8, offset: 0.63)] {
                let x = size.width * stream.x
                let length = cupHeight * 1.24
                let width = size.width * stream.width * (1 + 0.22 * surge)
                let cycle = (seconds / stream.period + stream.offset).truncatingRemainder(dividingBy: 1)
                let pulse = -0.25 + cycle * 1.65
                func center(_ t: Double) -> CGFloat {
                    x + size.width * stream.drift * (3 * t * t - 2 * t * t * t)
                }
                func halfWidth(_ t: Double) -> CGFloat {
                    let bulge = exp(-pow((t - pulse) / 0.085, 2))
                    return width * (0.20 + 0.95 * exp(-t * 14) + 0.65 * bulge)
                }
                var film = Path()
                for step in 0...48 {
                    let t = Double(step) / 48
                    let point = CGPoint(x: center(t) - halfWidth(t), y: -2 + length * t)
                    if step == 0 { film.move(to: point) } else { film.addLine(to: point) }
                }
                for step in stride(from: 48, through: 0, by: -1) {
                    let t = Double(step) / 48
                    film.addLine(to: CGPoint(x: center(t) + halfWidth(t) * 0.75, y: -2 + length * t))
                }
                film.addQuadCurve(
                    to: CGPoint(x: center(0) - halfWidth(0), y: -2),
                    control: CGPoint(x: center(0), y: -5)
                )
                film.closeSubpath()
                context.fill(film, with: .linearGradient(
                    Gradient(stops: [
                        .init(color: .white.opacity(0.36), location: 0),
                        .init(color: .white.opacity(0.08), location: 0.28),
                        .init(color: .clear, location: 0.55),
                        .init(color: Color(red: 0.06, green: 0.27, blue: 0.38).opacity(0.18), location: 0.85),
                        .init(color: .white.opacity(0.16), location: 1)
                    ]),
                    startPoint: CGPoint(x: x - width, y: 0), endPoint: CGPoint(x: x + width, y: 0)
                ))

                // Only the curved pulse catches a strong glint; the wet path stays nearly transparent.
                var highlight = Path()
                for step in 0...16 {
                    let t = pulse - 0.10 + Double(step) / 16 * 0.16
                    guard t >= 0 && t <= 1 else { continue }
                    let point = CGPoint(x: center(t) - halfWidth(t) * 0.65, y: -2 + length * t)
                    if highlight.isEmpty { highlight.move(to: point) } else { highlight.addLine(to: point) }
                }
                let glint = min(1, max(0, (pulse + 0.1) * 8)) * min(1, max(0, (1.1 - pulse) * 8))
                context.stroke(highlight, with: .color(.white.opacity(glint * 0.65)), style: StrokeStyle(lineWidth: 0.75, lineCap: .round))

                // A bead grows at the lower glass edge, pinches off, then accelerates through the air.
                let beadPeriod = stream.period * 1.17
                let beadCycle = (seconds / beadPeriod + stream.offset).truncatingRemainder(dividingBy: 1)
                let release = 1 - 0.22 / beadPeriod
                let falling = max(0, (beadCycle - release) * beadPeriod / 0.22)
                let radius = 0.65 + min(beadCycle / release, 1) * 0.85
                let drop = CGRect(x: center(1) - radius, y: length - 2 + falling * falling * 9,
                                  width: radius * 2, height: radius * 2 * (1 + falling * 0.55))
                var beadContext = context
                beadContext.opacity = min(1, beadCycle / 0.12) * (1 - falling)
                beadContext.fill(Path(ellipseIn: drop), with: .linearGradient(
                    Gradient(colors: [.white.opacity(0.6), Color(red: 0.35, green: 0.72, blue: 0.87).opacity(0.22), .white.opacity(0.35)]),
                    startPoint: CGPoint(x: drop.minX, y: drop.minY), endPoint: CGPoint(x: drop.maxX, y: drop.maxY)
                ))
            }
        }
        .accessibilityHidden(true)
    }
}

private struct AnimalPawOcclusion: Shape {
    let animal: AnimalKind

    func path(in rect: CGRect) -> Path {
        // shortcut: these contours follow the bundled 1254-point artwork; retrace them when artwork changes.
        let edges: (left: [(CGFloat, CGFloat)], right: [(CGFloat, CGFloat)])
        switch animal {
        case .panda:
            edges = (
                [(390, 746), (400, 752), (420, 756), (422, 760), (426, 764), (432, 768), (437, 772),
                 (442, 776), (445, 780), (448, 784), (450, 788), (452, 792), (452, 796), (452, 800),
                 (450, 804), (449, 808), (447, 812), (447, 816), (448, 820), (445, 824), (449, 828),
                 (454, 832), (457, 836), (460, 840), (462, 844), (462, 848), (460, 852), (459, 856),
                 (457, 860), (456, 864), (451, 868), (451, 872), (454, 876), (456, 880), (457, 884),
                 (457, 888), (456, 892), (456, 896), (454, 900), (453, 904), (448, 908), (446, 912),
                 (440, 916), (437, 920), (434, 924), (426, 928), (420, 932), (420, 936), (406, 940)],
                [(870, 746), (856, 752), (834, 756), (832, 760), (829, 764), (826, 768), (823, 772),
                 (821, 776), (816, 780), (814, 784), (812, 788), (810, 792), (809, 796), (808, 800),
                 (808, 804), (809, 808), (809, 812), (811, 816), (818, 820), (813, 824), (807, 828),
                 (802, 832), (799, 836), (796, 840), (796, 844), (795, 848), (795, 852), (796, 856),
                 (798, 860), (799, 864), (802, 868), (806, 872), (809, 876), (806, 880), (802, 884),
                 (801, 888), (801, 892), (801, 896), (802, 900), (804, 904), (809, 908), (812, 912),
                 (815, 916), (818, 920), (821, 924), (827, 928), (835, 932), (835, 936), (849, 940)]
            )
        case .fox:
            edges = (
                [(500, 748), (545, 757), (569, 776), (583, 795), (583, 807), (576, 814), (589, 830),
                 (593, 847), (585, 861), (578, 865), (587, 880), (583, 893), (570, 907), (548, 919), (518, 930)],
                [(935, 747), (903, 758), (881, 778), (866, 798), (863, 810), (870, 820), (859, 834),
                 (855, 850), (860, 865), (872, 872), (869, 881), (875, 898), (895, 914), (919, 928), (947, 937)]
            )
        case .rabbit:
            edges = (
                [(402, 770), (435, 780), (464, 799), (479, 818), (478, 834), (472, 841), (484, 857),
                 (482, 874), (470, 887), (458, 890), (459, 904), (445, 920), (422, 932)],
                [(854, 780), (826, 788), (795, 805), (777, 823), (769, 839), (774, 847), (768, 865),
                 (774, 883), (787, 891), (783, 904), (799, 923), (822, 937), (849, 947)]
            )
        case .capybara:
            edges = (
                [(410, 709), (439, 723), (458, 744), (468, 765), (465, 780), (462, 785), (476, 800),
                 (480, 817), (474, 835), (465, 843), (473, 858), (468, 876), (450, 892), (424, 908)],
                [(884, 711), (854, 725), (833, 745), (823, 765), (827, 779), (833, 787), (816, 803),
                 (810, 820), (814, 836), (825, 845), (819, 860), (824, 878), (844, 896), (873, 916)]
            )
        case .giraffe:
            edges = (
                [(412, 763), (439, 775), (457, 794), (465, 815), (460, 830), (456, 834),
                 (469, 850), (475, 871), (467, 891), (453, 910), (431, 926), (410, 936)],
                [(856, 770), (830, 778), (808, 795), (796, 813), (791, 831), (799, 837),
                 (785, 853), (781, 874), (789, 895), (807, 915), (831, 932), (855, 942)]
            )
        case .monkey:
            edges = (
                [(411, 746), (436, 758), (452, 779), (463, 800), (458, 814), (451, 819), (465, 834),
                 (470, 852), (462, 868), (454, 873), (462, 889), (457, 906), (440, 925), (413, 941)],
                [(855, 748), (828, 758), (808, 776), (796, 795), (791, 810), (796, 816), (783, 833),
                 (780, 852), (788, 867), (797, 875), (792, 889), (798, 907), (817, 927), (844, 945)]
            )
        case .pig:
            edges = (
                [(422, 758), (448, 775), (467, 800), (481, 822), (480, 837), (468, 846),
                 (475, 858), (477, 878), (466, 899), (448, 918), (422, 934)],
                [(850, 762), (825, 775), (804, 794), (788, 816), (780, 837), (786, 849),
                 (794, 852), (786, 866), (788, 885), (802, 906), (826, 925), (852, 940)]
            )
        }

        var path = Path()
        // The measured panda silhouette needs no glass-side buffer; padding recreates the pale finger halo.
        let clearance: CGFloat = animal == .panda ? 0 : 3
        for (edge, outsideX, inset) in [(edges.left, CGFloat(0), clearance), (edges.right, CGFloat(1254), -clearance)] {
            let points = edge.map {
                CGPoint(x: rect.minX + ($0.0 + inset) / 1254 * rect.width, y: rect.minY + $0.1 / 1254 * rect.height)
            }
            let outside = rect.minX + outsideX / 1254 * rect.width
            path.move(to: CGPoint(x: outside, y: points[0].y))
            // Preserve the traced finger tips; rounding this contour leaves blue fur or pale seams.
            path.addLines(points)
            path.addLine(to: CGPoint(x: outside, y: points[points.count - 1].y))
            path.closeSubpath()
        }
        return path
    }
}

private struct CupInterior: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.15, y: rect.minY + rect.height * 0.96),
            control: CGPoint(x: rect.minX + rect.width * 0.03, y: rect.minY + rect.height * 0.60)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.15, y: rect.minY + rect.height * 0.96),
            control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.04)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - rect.width * 0.03, y: rect.minY + rect.height * 0.60)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.03)
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
