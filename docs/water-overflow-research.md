# Natural-looking water overflow research

Research date: 2026-10-18

The current overflow effect draws three nearly parallel, continuously outlined ribbons. That reads as animated decoration because each stream has a fixed start, fixed downward direction, similar width, and a traveling highlight. A more convincing cup overflow should read as a thin film that collects at the rim, chooses a few uneven paths, and intermittently gathers into thicker rivulets or droplets.

## What the fluid literature says

- A rivulet is a narrow liquid stream on a solid surface with a curved liquid–air interface. Its cross-section is set by the balance of gravity and surface tension; the velocity field is a separate part of the problem. Perazzo and Gratton, *Journal of Fluid Mechanics* 507 (2004), describe the free-surface shape as the static equilibrium of gravity and surface tension: [Cambridge University Press article](https://www.cambridge.org/core/journals/journal-of-fluid-mechanics/article/abs/navierstokes-solutions-for-parallel-flow-in-rivulets-on-an-inclined-plane/71672116870D86D73092BA2257EBAC85), [DOI](https://doi.org/10.1017/S0022112004008791).

- A perfectly straight, uniform rivulet is a special case. Experiments on gravity-driven liquid films found strong three-dimensionality, pronounced rivulets, smooth rivulets with traveling pulses, and fronts separated by thin-film regions. Rivulet amplitude and wavelength changed with inclination and flow conditions. See Rojas et al., *Physical Review Fluids* 3, 114002 (2018): [APS article](https://journals.aps.org/prfluids/abstract/10.1103/PhysRevFluids.3.114002), [DOI](https://doi.org/10.1103/PhysRevFluids.3.114002).

- Contact-line behavior matters. Rivulet stability depends on whether the contact lines are fixed or moving and on how contact angle changes with contact-line speed. A stream therefore should not have a hard, constantly identical boundary while its interior moves. Weiland and Davis, *Journal of Fluid Mechanics* 107 (1981): [Cambridge University Press article](https://www.cambridge.org/core/journals/journal-of-fluid-mechanics/article/abs/moving-contact-lines-and-rivulet-instabilities-part-2-long-waves-on-flat-rivulets/4FA10DA525A5F9A28C0C3CB9B3CE6F97), [DOI](https://doi.org/10.1017/S0022112081001778).

- Surface texture and heterogeneity change the route of a rivulet. Experiments reported mostly vertical channels on one surface and branched, inclined paths feeding a central vertical channel on another. Thin film regions spread and merge into thicker rivulets; accumulated liquid can remain pinned until gravity overcomes the pinning force. See Thomas et al., *Langmuir* 39 (2023), “Preferred Mode of Atmospheric Water Vapor Condensation…”: [full article](https://pmc.ncbi.nlm.nih.gov/articles/PMC10116598/), especially the rivulet observations in lines 206–224 of the article.

These papers study larger-scale flows and different surfaces than a stylized iPhone cup. They support the qualitative cues below; they do not provide animation constants for this artwork.

## Translation into the Sipimals effect

These are implementation inferences from the sources and the existing 2D artwork:

1. Let overflow begin as a shallow, uneven wet band around the front rim. A small rim bead or short crest should connect the filled cup to each spill path. This removes the visual impression that independent ribbons were pasted onto the glass.
2. Use two or three paths with different widths, start positions, delays, and speeds. One can remain a thin film, one can gather into a thicker central rivulet, and one can fade into a small bead. Avoid equal spacing and equal length.
3. Make the centerline mostly gravity-directed with a small, slowly varying lateral drift. Use a smooth low-frequency spline or a few control points. Avoid a full-length sinusoid: it gives every height the same artificial periodic structure.
4. Make width vary gradually along the path and let one or two localized pulses travel downward. A pulse can broaden the rivulet for a moment, then narrow it again. The source observations of traveling pulses and changing rivulet amplitude support this better than a uniform ribbon with a repeating cosine width.
5. Add occasional accumulation and merging. A thin branch may join a nearby thicker path near the upper third, or a bead may pause at the lower end before continuing. Keep this sparse; constant branching would look like a special effect.
6. Use gravity as the dominant direction, but keep wall-attached rivulet paths mostly stationary. A supported rivulet can be pinned by contact-line friction and surface heterogeneity, so it does not need to freely accelerate as a whole. Surface tension should keep the edges rounded and smooth, so the stream should not kink sharply or flap sideways. Reserve gravity acceleration for a bead that has detached from the glass.
7. Draw water as a translucent film with a soft blue body, a narrow brighter specular streak on one side, and a subtle darker center or edge. Do not use a uniform opaque white outline around the whole stream. The outline makes the stream look like a vector ribbon instead of a curved liquid–air interface. This material advice is a visual inference rather than a direct measurement from the cited papers.
8. At the bottom, terminate paths with rounded tapered ends or a small hanging bead. A detached drop should be occasional and brief; the normal state is attached flow that gathers at the lower glass edge. The condensation study documents accumulation and release when gravity overcomes edge pinning, which is a useful qualitative model for this beat.

## Real-time rendering references and limits

NVIDIA’s *GPU Gems 2*, Chapter 19, describes a real-time refraction approximation using a rendered scene texture, a refraction mask, animated bump layers, and a Fresnel-weighted blend of reflection and refraction: [NVIDIA Developer, “Generic Refraction Simulation”](https://developer.nvidia.com/gpugems/gpugems2/part-ii-shading-lighting-and-shadows/chapter-19-generic-refraction-simulation). The current SwiftUI `Canvas` effect does not have a captured scene texture or a per-pixel refraction pass. Its translucent blue shading, soft edge highlight, and mask provide an intentional illustration approximation; they do not actually bend the panda or background through the wet glass. Adding true background refraction would require a different rendering pipeline and is out of scope for this small 2D effect.

Tatarchuk and Isidoro’s first-party SIGGRAPH 2006 course notes model droplets on glass with gravity opposed by static or dynamic friction, with surface-dependent meandering, merging, and separation: [PDF](https://www.realtimerendering.com/advances/s2006/Tatarchuk-Rain.pdf), [Eurographics record](https://diglib.eg.org/items/b4d11d22-3e3d-4ac5-b33c-6b091143add1). This supports using mostly fixed wet paths, independent moving thickness bulges, and a bead that grows and pinches off near the glass base. It does not require the whole attached rivulet to accelerate continuously.

## Recommended minimal animation model

Keep the existing `Canvas` and timeline architecture. Use two unequal, mostly stationary curved wet paths. Store only a few deterministic parameters per path: rim start, base width, path control points, delay, speed, and one thickness-pulse phase. Evaluate them every frame as follows:

- `center(y)`: a monotonic downward path with a small spline drift and no repeated oscillation. The path itself should not slide back and forth.
- `width(y)`: a smooth taper/expansion envelope multiplied by one traveling Gaussian pulse; clamp to a narrow minimum.
- `pulse`: a phase that advances downward at a slightly different speed for each path, changing thickness rather than translating the path. Use a separate short-lived gravity curve only after a bottom bead detaches.
- `opacity`: strongest at the rim and in the thicker core, softer at thin-film tails and detached beads.

The current implementation target is two unequal mostly stationary curved paths with independent traveling thickness pulses, no closed bright outlines, and bead growth/detachment at the glass base. This is intentionally a 2D stylization, not a Navier–Stokes solver. The goal is to preserve the physical hierarchy: gravity determines direction and detached-drop motion, surface tension rounds and smooths the liquid, and surface/contact variation creates uneven rivulets.

## SwiftUI constraints

SwiftUI `Canvas` is intended for rich, dynamic 2D drawing and supports paths, gradients, masks, filters, and compositing: [Apple Canvas documentation](https://developer.apple.com/documentation/swiftui/canvas), [Apple drawing and graphics overview](https://developer.apple.com/documentation/swiftui/drawing-and-graphics). `TimelineView` supplies scheduled redraws and a date to drive the phase: [Apple TimelineView documentation](https://developer.apple.com/documentation/SwiftUI/TimelineView). That is sufficient for this effect; no external graphics dependency or fluid library is justified.

Because the overflow persists while the hydration goal is met, keep the paths subtle and low contrast so the state remains legible without becoming distracting. Apple’s motion guidance recommends purposeful, precise motion and realistic feedback, and warns against gratuitous or distracting animation: [Human Interface Guidelines: Motion](https://developer.apple.com/design/human-interface-guidelines/motion). Keep the current Reduce Motion path; `EnvironmentValues.accessibilityReduceMotion` is the supported SwiftUI signal, and Apple says to avoid large animations when it is enabled: [SwiftUI accessibilityReduceMotion](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion).

## Practical acceptance criteria

- At the brim, the overflow visibly connects to the filled water surface.
- The paths are unequal in width, spacing, and timing, with no repeated equal sinusoidal bends. Both can reach the same lower glass edge.
- At least one path behaves like a thin film and one like a thicker rivulet; a small bead or pulse appears occasionally rather than continuously.
- The water stays aligned with the glass and behind the animal paws. Only detached beads fall below the outer glass base.
- The effect remains readable in light and dark mode, and Reduce Motion leaves a calm, static overflow state.
- The animation remains a bounded `Canvas` redraw and is visually checked on the iPhone simulator and device before release. Apple’s rendering-efficiency guidance recommends pausing or stopping animations when updates complete and profiling SwiftUI redraws when performance is in doubt: [Improving your app’s rendering efficiency](https://developer.apple.com/documentation/xcode/improving-your-app-s-rendering-efficiency).
