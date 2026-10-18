#!/usr/bin/env python3
"""Render the actual SwiftUI companion at fixed wave phases; check cup and paw coverage.
Run on macOS with Xcode: python3 scripts/check-water-rendering.py
Review images in .build/water-review after changing any animal artwork.
"""
from pathlib import Path
import json
import os
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '.build/water-review'
OUT.mkdir(parents=True, exist_ok=True)
env = dict(os.environ, DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer')
assets = {}
for contents in (ROOT / 'PandaSip/Assets.xcassets').glob('*.imageset/Contents.json'):
    filenames = [item['filename'] for item in json.loads(contents.read_text())['images'] if 'filename' in item]
    if filenames:
        assets[contents.parent.stem] = str(contents.parent / filenames[0])
view = (ROOT / 'PandaSip/Views/PandaView.swift').read_text().split('#Preview')[0]
# Freeze only head motion; exercise the production water view with explicit wave phase and slosh.
view = view.replace('@Environment(\\.accessibilityReduceMotion) private var reduceMotion', 'private let reduceMotion = true')
# Isolate interior regressions from intentional exterior spills, then check the complete layer separately.
view = view.replace('    let animal: AnimalKind', '    var reviewShowsOverflow = false\n    var reviewShowsBrim = false\n    let animal: AnimalKind', 1)
overflow_call = 'cupOverflow(cup: cup, phase: phase)'
assert overflow_call in view, 'Update the overflow seam after changing the companion renderer'
view = view.replace(overflow_call, 'if reviewShowsOverflow { ' + overflow_call + ' }', 1)
brim_call = 'cupBrim(cup: cup)'
assert brim_call in view, 'Update the brim seam after changing the companion renderer'
view = view.replace(brim_call, 'if reviewShowsBrim { ' + brim_call + ' }', 1)
for layer in ['Body', 'Head']:
    original = 'Image("\\(animal.rawValue.capitalized)Rig' + layer + '")'
    assert original in view, 'Update the asset-loading seam after changing the companion renderer'
    view = view.replace(original, original.replace('Image(', 'reviewImage('))
source = 'import SwiftUI\nimport AppKit\n'
source += 'let reviewAssets: [String:String] = ' + json.dumps(assets).replace('{', '[').replace('}', ']') + '\n'
source += '@MainActor func reviewImage(_ name: String) -> Image { Image(nsImage: NSImage(contentsOfFile: reviewAssets[name]!)!) }\n'
source += (ROOT / 'PandaSip/Models/Animal.swift').read_text()
source += (ROOT / 'PandaSip/Models/Drink.swift').read_text()
source += view
source += r'''
extension PandaView {
    func reviewFrame(phase: Double, slosh: Double, overflow: Bool, brim: Bool) -> some View {
        var frame = self
        frame.reviewShowsOverflow = overflow
        frame.reviewShowsBrim = brim || overflow
        return frame.animalArtwork(phase: phase, slosh: slosh)
    }
}

// Independent landmarks read from the source art; do not derive expected bounds from production code.
struct CupLandmarks {
    let animal: AnimalKind
    let center: Int
    let top: Int
    let bottom: Int
    let exterior: CGRect
    let paws: [[CGPoint]]
}
func polygon(_ coordinates: [Int]) -> [CGPoint] {
    stride(from: 0, to: coordinates.count, by: 2).map { CGPoint(x: coordinates[$0], y: coordinates[$0 + 1]) }
}
let cups: [CupLandmarks] = [
    .init(animal: .panda, center: 627, top: 735, bottom: 1105, exterior: CGRect(x: 420, y: 730, width: 418, height: 380), paws: [polygon([350,780,420,780,435,800,435,815,445,840,445,855,435,875,440,895,425,915,375,942]), polygon([865,775,835,780,820,800,825,820,810,845,815,860,825,875,815,895,830,915,880,940])]),
    .init(animal: .fox, center: 723, top: 720, bottom: 1090, exterior: CGRect(x: 540, y: 715, width: 370, height: 382), paws: [polygon([485,775,540,775,565,793,568,815,579,839,568,867,572,888,545,913,495,927]), polygon([950,775,900,780,877,805,880,824,867,845,882,873,885,895,925,923,965,930])]),
    .init(animal: .rabbit, center: 627, top: 765, bottom: 1100, exterior: CGRect(x: 440, y: 760, width: 380, height: 347), paws: [polygon([400,795,440,805,462,825,460,847,470,866,451,885,440,908,408,924]), polygon([850,801,820,812,789,835,790,855,781,870,795,889,801,908,830,932,865,940])]),
    .init(animal: .capybara, center: 646, top: 695, bottom: 1065, exterior: CGRect(x: 438, y: 690, width: 420, height: 382), paws: [polygon([390,740,433,744,452,766,450,786,463,805,465,824,451,844,459,861,443,882,410,902]), polygon([890,740,850,746,837,766,846,787,829,806,824,825,839,844,832,863,848,885,887,907])]),
    .init(animal: .giraffe, center: 631, top: 740, bottom: 1105, exterior: CGRect(x: 422, y: 735, width: 420, height: 377), paws: [polygon([410,786,439,796,451,818,443,836,456,853,461,874,448,897,420,922,390,928]), polygon([865,793,831,799,809,822,813,841,799,861,795,876,807,900,836,927,875,937])]),
    .init(animal: .monkey, center: 627, top: 740, bottom: 1105, exterior: CGRect(x: 412, y: 735, width: 430, height: 377), paws: [polygon([395,770,431,778,446,800,438,821,452,841,453,856,441,875,450,891,435,912,410,930]), polygon([865,775,832,785,807,803,809,824,796,840,795,855,810,876,806,894,824,919,855,939])]),
    .init(animal: .pig, center: 631, top: 740, bottom: 1105, exterior: CGRect(x: 422, y: 735, width: 420, height: 377), paws: [polygon([415,788,442,799,462,825,461,840,451,847,463,866,462,885,442,910,415,925]), polygon([860,788,832,801,809,822,795,840,808,855,798,874,810,897,839,920,866,933])])
]

// Three finger-edge rows per animal, measured in the original artwork canvas.
let seamRows: [AnimalKind: [(left: Int, right: Int, y: Int)]] = [
    .panda: [(452, 808, 800), (461, 795, 850), (454, 802, 900)],
    .fox: [(583, 866, 800), (591, 855, 850), (578, 877, 900)],
    .rabbit: [(478, 770, 835), (483, 770, 865), (460, 783, 900)],
    .capybara: [(468, 823, 765), (478, 812, 810), (470, 821, 865)],
    .giraffe: [(465, 796, 815), (475, 781, 871), (453, 803, 910)],
    .monkey: [(463, 796, 800), (470, 780, 852), (458, 796, 900)],
    .pig: [(481, 788, 822), (475, 794, 852), (466, 798, 899)]
]

let furEdgeProbes: [AnimalKind: [(Int, Int)]] = [
    .panda: [(430, 800), (450, 850), (815, 890)],
    .fox: [(583, 807), (585, 861), (570, 907)],
    .rabbit: [(482, 874), (470, 887), (459, 904)],
    .capybara: [(468, 765), (474, 835), (468, 876)],
    .giraffe: [(475, 871), (467, 891), (453, 910)],
    .monkey: [(458, 814), (462, 868), (457, 906)],
    .pig: [(480, 837), (475, 858), (466, 899)]
]

// Independent rim anchors in the original artwork canvas, left/center/right stream.
let spillAnchors: [AnimalKind: [Int]] = [
    .panda: [519, 632, 737], .fox: [629, 727, 818], .rabbit: [530, 632, 727],
    .capybara: [538, 652, 757], .giraffe: [523, 636, 740],
    .monkey: [515, 631, 738], .pig: [523, 636, 740]
]

@main struct WaterReview {
    @MainActor static func main() throws {
        let out = URL(fileURLWithPath: CommandLine.arguments[1])
        let scale = Double(CommandLine.arguments[2])!
        let suffix = scale == 2 ? "" : "@3x"
        var checks = 0
        var failures: [String] = []
        func check(_ condition: Bool, _ message: String) {
            checks += 1
            if !condition { failures.append(message) }
        }
        func pixel(_ image: NSBitmapImageRep, x: Int, y: Int) -> NSColor {
            image.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
        }
        func delta(_ a: NSColor, _ b: NSColor) -> Double {
            max(abs(a.redComponent - b.redComponent), abs(a.greenComponent - b.greenComponent), abs(a.blueComponent - b.blueComponent)) * 255
        }
        func outputPoint(x: Int, y: Int) -> CGPoint { CGPoint(x: (Double(x) * 270 * scale / 1254).rounded(.down), y: (Double(y) * 270 * scale / 1254 + 7.5 * scale).rounded(.down)) }
        func difference(_ a: NSBitmapImageRep, _ b: NSBitmapImageRep, _ index: Int) -> Int {
            let left = a.bitmapData!, right = b.bitmapData!
            return (0..<4).map { abs(Int(left[index + $0]) - Int(right[index + $0])) }.max()!
        }
        @MainActor func render(_ animal: AnimalKind, _ level: Double, _ phase: Double, _ slosh: Double, _ dark: Bool, overflow: Bool = false, brim: Bool = false) -> NSBitmapImageRep {
            let frame = PandaView(animal: animal, progress: level, celebrating: true)
                .reviewFrame(phase: phase, slosh: slosh, overflow: overflow, brim: brim)
                .frame(width: 270, height: 285)
                .background(dark ? Color(red: 0.08, green: 0.11, blue: 0.10) : Color(red: 0.97, green: 0.94, blue: 0.85))
                .environment(\.colorScheme, dark ? .dark : .light)
            let renderer = ImageRenderer(content: frame); renderer.scale = scale
            return NSBitmapImageRep(cgImage: renderer.cgImage!)
        }
        precondition(Set(cups.map(\.animal)) == Set(AnimalKind.allCases), "Every animal needs visual landmarks")
        for dark in [false, true] {
            var waterColors = Array(repeating: [NSColor](), count: 12)
            for cup in cups {
                let name = cup.animal.rawValue
                let empty = render(cup.animal, 0, 0, 0, dark)
                let full = render(cup.animal, 1, 0, 0, dark)
                for (row, depth) in [0.15, 0.35, 0.55, 0.80].enumerated() {
                    for (column, offset) in [-0.20, 0.0, 0.20].enumerated() {
                        let point = outputPoint(x: cup.center + Int(offset * cup.exterior.width), y: cup.top + Int(depth * Double(cup.bottom - cup.top)))
                        waterColors[row * 3 + column].append(pixel(full, x: Int(point.x), y: Int(point.y)))
                    }
                }
                if cup.animal == .panda {
                    // These are bright glass in the empty artwork, not fur contour guesses.
                    for (x, y) in [(466, 850), (456, 904), (790, 850), (794, 862), (798, 871), (796, 888), (796, 900), (800, 904)] {
                        let point = outputPoint(x: x, y: y)
                        let glass = pixel(empty, x: Int(point.x), y: Int(point.y))
                        let luminance = glass.redComponent * 0.2126 + glass.greenComponent * 0.7152 + glass.blueComponent * 0.0722
                        check(luminance > 0.72, "Panda glass landmark at \(x),\(y) needs recalibration")
                        check(delta(glass, pixel(full, x: Int(point.x), y: Int(point.y))) > 50, "Panda glass beside fingers at \(x),\(y) is left unfilled @\(Int(scale))x")
                    }
                }
                for (x, y) in furEdgeProbes[cup.animal]! {
                    let point = outputPoint(x: x, y: y)
                    check(delta(pixel(empty, x: Int(point.x), y: Int(point.y)), pixel(full, x: Int(point.x), y: Int(point.y))) <= 4, "\(name): traced fur edge at \(x),\(y) is tinted @\(Int(scale))x")
                }
                for row in seamRows[cup.animal]! {
                    for (edge, direction) in [(row.left, 1), (row.right, -1)] {
                        let fur = outputPoint(x: edge - direction * 5, y: row.y)
                        let glass = outputPoint(x: edge + direction * 7, y: row.y)
                        check(delta(pixel(empty, x: Int(fur.x), y: Int(fur.y)), pixel(full, x: Int(fur.x), y: Int(fur.y))) <= 4, "\(name): paw seam at \(edge),\(row.y) is tinted @\(Int(scale))x")
                        check(delta(pixel(empty, x: Int(glass.x), y: Int(glass.y)), pixel(full, x: Int(glass.x), y: Int(glass.y))) > 18, "\(name): pale gap at \(edge),\(row.y) @\(Int(scale))x")
                        let boundary = outputPoint(x: edge, y: row.y)
                        var gap = 0
                        // The boundary pixel itself may contain fur; count only pixels toward the glass.
                        for offset in 1...3 {
                            let x = Int(boundary.x) + direction * offset, y = Int(boundary.y)
                            if delta(pixel(empty, x: x, y: y), pixel(full, x: x, y: y)) > 18 { break }
                            gap += 1
                        }
                        check(gap <= 2, "\(name): unchanged seam at \(edge),\(row.y) extends \(gap) pixels into glass @\(Int(scale))x")
                    }
                }
                precondition(empty.bitsPerSample == 8 && empty.samplesPerPixel == 4 && !empty.isPlanar)
                let pawPaths = cup.paws.map { vertices -> CGPath in
                    let path = CGMutablePath(); path.addLines(between: vertices); path.closeSubpath(); return path
                }
                var coverage: [(index: Int, outside: Bool, paw: Bool)] = []
                for y in Int(130 * scale)..<Int(267.5 * scale) { for x in Int(65 * scale)..<Int(222.5 * scale) {
                    let source = CGPoint(x: (Double(x) + 0.5) * 1254 / (270 * scale), y: (Double(y) + 0.5 - 7.5 * scale) * 1254 / (270 * scale))
                    coverage.append((y * empty.bytesPerRow + x * 4, !cup.exterior.contains(source), pawPaths.contains { $0.contains(source) }))
                } }
                let brim = render(cup.animal, 1, 0, 0, dark, brim: true)
                let spill = render(cup.animal, 1, 0, 0, dark, overflow: true)
                let movingSpill = render(cup.animal, 1, 1.7, 0, dark, overflow: true)
                let overGoal = render(cup.animal, 1.25, 0, 0, dark, overflow: true)
                let almost = render(cup.animal, 0.999, 0, 0, dark, overflow: true)
                let almostWithoutSpill = render(cup.animal, 0.999, 0, 0, dark)
                for x in spillAnchors[cup.animal]! {
                    for y in [cup.top + 8, cup.top + 150] {
                        let point = outputPoint(x: x, y: y)
                        check(delta(pixel(brim, x: Int(point.x), y: Int(point.y)), pixel(spill, x: Int(point.x), y: Int(point.y))) > 18,
                              "\(name): stream missing at rim/glass landmark \(x),\(y)")
                    }
                }
                var crestPixels = 0, tailPixels = 0, movingPixels = 0, spillOnPaws = 0
                var earlySpill = 0, overGoalMismatch = 0, straySpill = 0
                for y in 0..<spill.pixelsHigh { for x in 0..<spill.pixelsWide {
                    let index = y * spill.bytesPerRow + x * 4
                    let point = CGPoint(x: (Double(x) + 0.5) * 1254 / (270 * scale), y: (Double(y) + 0.5 - 7.5 * scale) * 1254 / (270 * scale))
                    if difference(brim, spill, index) > 6 {
                        if point.y < CGFloat(cup.top) { crestPixels += 1 }
                        if point.y > CGFloat(cup.bottom) { tailPixels += 1 }
                        if pawPaths.contains(where: { $0.contains(point) }) { spillOnPaws += 1 }
                        let spillBounds = CGRect(x: cup.exterior.minX, y: CGFloat(cup.top - 40), width: cup.exterior.width, height: CGFloat(cup.bottom - cup.top + 115))
                        if !spillBounds.contains(point) { straySpill += 1 }
                    }
                    if difference(spill, movingSpill, index) > 6 { movingPixels += 1 }
                    if difference(almost, almostWithoutSpill, index) > 4 { earlySpill += 1 }
                    if difference(spill, overGoal, index) > 4 { overGoalMismatch += 1 }
                } }
                // Water must cover the visible oval and join the front fill, not just support falling streaks.
                for (x, y) in [(cup.center, cup.top - 55), (cup.center - 80, cup.top - 30), (cup.center + 80, cup.top - 30), (cup.center, cup.top - 5)] {
                    let point = outputPoint(x: x, y: y)
                    let water = pixel(brim, x: Int(point.x), y: Int(point.y))
                    check(delta(pixel(empty, x: Int(point.x), y: Int(point.y)), water) > 30 && water.blueComponent > water.redComponent + 0.2,
                          "\(name): unfilled opening/connection at \(x),\(y)")
                }
                for (x, y) in [(cup.center, cup.top - 115), (Int(cup.exterior.minX) - 35, cup.top - 40), (Int(cup.exterior.maxX) + 35, cup.top - 40)] {
                    let point = outputPoint(x: x, y: y)
                    check(delta(pixel(empty, x: Int(point.x), y: Int(point.y)), pixel(brim, x: Int(point.x), y: Int(point.y))) <= 4,
                          "\(name): brim water escapes onto surrounding animal at \(x),\(y)")
                }
                for point in coverage where point.paw {
                    if difference(empty, brim, point.index) > 6 { spillOnPaws += 1 }
                }
                check(crestPixels > 6, "\(name): no spill over the front rim")
                check(tailPixels > 6, "\(name): no spill down past the inner glass floor")
                check(movingPixels > 20, "\(name): overflow does not flow between phases")
                check(spillOnPaws == 0, "\(name): overflow tints protected paws")
                check(earlySpill == 0, "\(name): overflow appears before the goal")
                check(overGoalMismatch == 0, "\(name): over-goal spill differs from full cup")
                check(straySpill == 0, "\(name): overflow escapes the glass front")
                for level in [0.01, 0.05, 0.25, 0.5, 0.75, 0.95, 1.0, 1.25] {
                    for (phase, slosh) in [(0.0, 0.0), (1.7, 1.0), (4.3, -1.8)] {
                        let image = render(cup.animal, level, phase, slosh, dark)
                        var leaks = 0, tintedPaws = 0, changed = 0
                        for point in coverage {
                            if difference(empty, image, point.index) > 6 {
                                changed += 1
                                if point.outside { leaks += 1 }
                                if point.paw { tintedPaws += 1 }
                            }
                        }
                        let context = "\(name) \(Int(level * 100))% phase=\(phase) slosh=\(slosh) \(dark ? "dark" : "light") @\(Int(scale))x"
                        check(leaks == 0, "\(context): \(leaks) pixels outside glass")
                        check(tintedPaws == 0, "\(context): \(tintedPaws) protected paw pixels tinted")
                        if level >= 0.05 { check(changed > 0, "\(context): no visible water") }
                        if phase == 0 && level >= 0.25 && level <= 1 {
                            var surface = cup.bottom
                            for y in (cup.top - 30)..<cup.bottom {
                                let point = outputPoint(x: cup.center, y: y)
                                if delta(pixel(empty, x: Int(point.x), y: Int(point.y)), pixel(image, x: Int(point.x), y: Int(point.y))) > 18 {
                                    surface = y; break
                                }
                            }
                            let expected = Double(cup.bottom) - Double(cup.bottom - cup.top) * level
                            check(abs(Double(surface) - expected) <= 14, "\(context): surface y=\(surface), expected \(Int(expected))")
                        }
                        if level > 1 {
                            var mismatch = 0
                            for point in coverage {
                                if difference(full, image, point.index) > 4 { mismatch += 1 }
                            }
                            check(mismatch == 0, "\(context): over-goal fill differs from full cup")
                        }
                        if phase == 0 {
                            let file = "\(name)-\(Int(level * 100))-\(dark ? "dark" : "light")\(suffix).png"
                            let reviewImage = level >= 1 ? spill : image
                            try reviewImage.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent(file))
                        }
                    }
                }
                try empty.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent("\(name)-0-\(dark ? "dark" : "light")\(suffix).png"))
            }
            for (sample, colors) in waterColors.enumerated() {
                for channel in [\NSColor.redComponent, \NSColor.greenComponent, \NSColor.blueComponent] {
                    let values = colors.map { $0[keyPath: channel] * 255 }
                    check(values.max()! - values.min()! <= 12, "Water color varies across animals at sample \(sample) by more than 12/255 in \(channel)")
                }
            }
        }
        if scale == 2 {
            for theme in ["light", "dark"] {
                for (group, animals) in [("starters", Array(AnimalKind.allCases.prefix(4))), ("unlocks", Array(AnimalKind.allCases.suffix(3)))] {
                    let width = animals.count * 540, height = 4 * 570
                    let sheet = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                    NSGraphicsContext.saveGraphicsState()
                    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: sheet)!
                    for (row, level) in [0, 25, 50, 100].enumerated() {
                        for (column, animal) in animals.enumerated() {
                            let image = NSImage(contentsOf: out.appendingPathComponent("\(animal.rawValue)-\(level)-\(theme).png"))!
                            image.draw(in: NSRect(x: column * 540, y: height - (row + 1) * 570, width: 540, height: 570))
                        }
                    }
                    NSGraphicsContext.restoreGraphicsState()
                    try sheet.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent("\(group)-\(theme).png"))
                }
            }
        }
        failures.prefix(30).forEach { print("FAIL: \($0)") }
        print("\(failures.isEmpty ? "PASS" : "FAIL"): \(checks) checks; seven animals, eight fill levels, three wave/slosh phases, light/dark @\(Int(scale))x")
        print("Review images: \(out.path)")
        if !failures.isEmpty { exit(1) }
    }
}
'''
# The raw string above is Swift source: key paths and interpolation require one backslash.
source = source.replace('\\\\', '\\')
(OUT / 'WaterReview.swift').write_text(source)
subprocess.run(['xcrun', 'swiftc', '-O', '-parse-as-library', str(OUT / 'WaterReview.swift'), '-o', str(OUT / 'water-review')], env=env, check=True)
for scale in ['2', '3']:
    subprocess.run([str(OUT / 'water-review'), str(OUT), scale], env=env, check=True)
