# Procedural Backgrounds

Seeded, procedurally generated painterly backgrounds for SwiftUI: ink-wash
landscapes adapted from Chinese *shan shui* painting, a watercolor garden wall,
a painted night sky, and Mondrian-style watercolor compositions. A small preview
harness app lets you browse the designs. Within a build, the same seed always
produces the same geometry. The scrolling designs generate an endless horizontal
world chunk by chunk and render it with Metal.

Requires Xcode 26+ and targets iOS 26 / macOS 26 or later. The package uses
Swift 6 language mode and has no external dependencies. The ink designs need a
Metal-capable device.

| Design | Type | Renderer |
| --- | --- | --- |
| `LayeredHillsDesign` | Still | SwiftUI `Canvas` |
| `ShanShuiDesign` | Still: one-mountain ink study | Metal |
| `ShanShuiLandscapeDesign` | Still: seeded composed landscape | Metal |
| `ShanShuiElementDesign` | Still: tree, pavilion and boat studies | Metal |
| `ShanShuiScrollingDesign` | Endless horizontal scroll | Metal |
| `GardenWallDesign` | Endless horizontal scroll | Metal |
| `NightSkyDesign` | Endless horizontal scroll | Metal |
| `MondrianDesign` | Still | Metal |
| `MondrianScrollingDesign` | Endless horizontal scroll | Metal |
| `PaperDesign` | Plain paper, no seed | SwiftUI |

## Installation

Add the package with Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/gifton/ProceduralBackgrounds.git", branch: "main")
]
```

Then link `BackgroundUI` for the SwiftUI designs, or only `BackgroundCore` if
you just need scene generation:

```swift
.target(name: "MyApp", dependencies: [
    .product(name: "BackgroundUI", package: "ProceduralBackgrounds")
])
```

## Run the harness

Open `Harness/BackgroundHarness.xcodeproj`, select the **BackgroundHarness**
scheme, choose **My Mac** or an **iPhone Simulator**, and Run (⌘R). Mac builds
use local ad hoc signing. For a physical iPhone, select your development team in
the harness target's Signing & Capabilities settings.

Choose **Layered hills**, **Shan Shui**, **Shan Shui landscape**, **Shan Shui scrolling**, **Shan Shui
elements**, **Garden Wall**, **Night Sky**, **Mondrian watercolor**, **Mondrian scrolling**, or **Plain paper** from the Design menu. **Shan Shui** retains the
original one-mountain study. **Shan Shui elements** shows an additional Element
menu: **Leafy tree**, **Bare tree**, **Pavilion**, or **Boat with figure**.
The seed stepper changes the procedural designs; Reset returns to seed 42.
For **Shan Shui scrolling**, **Garden Wall**, **Night Sky**, and **Mondrian scrolling**, drag/swipe to explore, or use **Pause/Play** for slow
automatic movement. Reset also returns its camera to the start, even at seed 42,
and preserves the Play/Pause choice. Switching designs preserves the seed.
Seed controls are disabled for paper, which has no procedural geometry. Resize
the Mac window or rotate the simulator to inspect different proportions.

## Structure

```text
ProceduralBackgrounds/
├── Package.swift
├── Sources/
│   ├── BackgroundCore/          # Seed → design-specific scene data; no UI imports
│   │   ├── Ink/                # Shared RGB/grayscale scenes, chunks and clipping
│   │   ├── GardenWall/         # Continuous masonry, plants, pots and cats
│   │   ├── NightSky/           # Canonical sky washes, stars and moon layouts
│   │   ├── Mondrian/           # Unequal color fields, canonical dividers and pigment
│   │   └── ShanShui/           # Mountain, landscape and element studies
│   └── BackgroundUI/            # BackgroundDesign + SwiftUI renderers
│       ├── Ink/                # Shared static/scrolling hosts and worker preparation
│       ├── Mondrian/           # Public still and scrolling painting designs
│       ├── NightSky/           # Public SwiftUI design using the shared host
│       └── ShanShui/           # Mesh compiler, MetalKit host and shaders
├── Tests/                      # Core geometry, triangulation and GPU readback
└── Harness/
    ├── BackgroundHarness.xcodeproj
    └── BackgroundHarness/      # App, preview controls, typed design catalog
```

Dependency direction: `Harness → BackgroundUI → BackgroundCore`. Both library
modules are exported as package products; the harness is not a library dependency.
See [Installation](#installation) to depend on the package from another app, or
add a local checkout as a local package dependency.

```swift
import BackgroundUI

// Inside a SwiftUI body:
LayeredHillsDesign().makeView(seed: 42)
```

`BackgroundGenerator` associates each generator with its own `Sendable` scene type.
`BackgroundDesign` associates each design with its concrete SwiftUI view. The
example builds normalized hill ridgelines on the CPU; a Canvas view scales and
fills them. It uses no display timer and performs generation outside the drawing
closure. The seed contract is tested within a build; geometry is not a versioned
serialization format or a promise of bit-identical output across OS/math libraries.

## Add another background

1. If it needs procedural geometry, add a scene value and `BackgroundGenerator`
   conformer to `BackgroundCore`. Test the design's seed and geometry contracts.
2. Add a `BackgroundDesign` conformer to `BackgroundUI`. For example:

   ```swift
   import SwiftUI

   public struct DuskDesign: BackgroundDesign {
       public static let title: String = "Dusk"
       public init() {}

       public func makeView(seed: UInt64) -> some View {
           LinearGradient(colors: [.indigo, .black],
                          startPoint: .top, endPoint: .bottom)
               .accessibilityHidden(true)
       }
   }
   ```

3. In the harness's `PreviewDesign.swift`, add a case, its title, and its
   `makeView(seed:)` switch branch, and `supportsPlayback` gate. `CaseIterable` adds it to the picker. The
   exhaustive switches require each entry to supply a concrete view, without
   `AnyView` or a plugin registry. If the design ignores the seed, extend the
   controls' disabled condition in `HarnessView`.

## Shan Shui ink study

**Shan Shui** currently renders textured paper and one mountain with tapered
outlines, faint washes and interior contour marks. It was the first study for
evaluating ink quality. The mountain treatment and its seed sequence remain
available as a reference alongside the composed landscape. The existing
hills example remains independent.

`ShanShuiGenerator` produces an immutable `ShanShuiScene` containing ordered
`InkPrimitive` washes and strokes in an 800 × 800 world. It has no UI dependency.
`InkMeshCompiler` triangulates simple polygons and expands strokes with capped
joins. A Metal renderer draws these triangles into a white ink surface with
supported MSAA, then multiplies it over procedural paper. Opaque white washes
cover earlier ink while retaining paper grain in the composite.

The study fits the viewport with uniform scaling. A worker actor performs scene
and mesh generation. A seed-keyed view task checks cancellation before installing
the result. Renderer state lives on the main actor; buffers persist until the
scene changes and textures until the drawable size changes. `MTKView` draws on
view/seed changes with its internal draw loop paused. Failures display an explicit
message rather than an unexplained blank surface.

Xcode builds compile the shader resource into the package bundle. Command-line
SwiftPM builds copy its source and the renderer compiles that packaged source
when no compiled library is present. GPU tests exercise that path on a Metal-capable
Mac. The implementation uses the established Metal command-buffer APIs so the
same renderer can be tested in the iPhone Simulator.

This is an adaptation of [shan-shui-inf](https://github.com/LingDong-/shan-shui-inf)
with its own random sequence and renderer, not JavaScript seed compatibility.
See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for upstream credit and license.

## Shan Shui landscape — seeded composition

**Shan Shui landscape** combines pale distant mountains, two nearer mountains,
open water and a rocky bank. The seed changes mountain spacing and scale, the
shoreline profile, tree clusters and the presence of a pavilion or boat. Scenes
can face either direction. Pine, leafy and bare trees share the foreground;
buildings and boats appear occasionally so the landscape retains open space.
The original mountain study and its drawing algorithm remain unchanged.

`ShanShuiLandscapeGenerator` produces the same ordered `ShanShuiScene` format in
a 1200 × 800 world. `ShanShuiLandscapeDesign` shares the study's worker generation,
SwiftUI host and Metal renderer. Geometry fits uniformly in the available preview;
paper fills the surrounding space on portrait or wider views. The composition
does not regenerate for each aspect ratio. This choice remains one finite scene;
the separate scrolling design explores indexed world chunks.

`ShanShuiComposition` is an internal layout value. Separate terrain, tree,
building, rock and boat random streams determine placement before ink is drawn.
Roots sit inside a generated shore polygon. A pavilion's full platform sits below
the lowest shore surface across its footprint. Water waves leave a clear area
around the boat, including its figure, pole and local ripples. Foreground items
are painted from their farther supports to their nearer supports, preserving
white silhouette occlusion. The composer scales canonical element studies as a
whole so fixed branch lengths and small architectural details retain their
proportions. Bare trees near a world edge shrink to fit a conservative branch
envelope; primitive coordinates are never clipped. Near mountains paint in order
of their support depth while retaining their own ink strength. Adding an element
need not change the Metal renderer.

Core tests check seed replay, changing populations, land support, open water and
the presence of planned subjects in the final ink. Placement tests sweep 131
seeds; geometry and whole-scene mesh tests cover 40 seeds including UInt64
boundaries and a reproduced branch-boundary case. A separate mesh test checks
placed bare trees, including stroke joins, in both reflected and unreflected
scenes. Depth-order tests include overlapping mountains. GPU tests render
wide then tall output through the same renderer and check visible ink and paper
margins after texture resizing. Mac and Simulator builds are checked with Xcode 27.

## Shan Shui scrolling — deterministic chunks

**Shan Shui scrolling** explores a horizontal world built from adjacent seeded
1200 × 800 landscapes. Chunk zero reproduces the still scene for the selected
seed; the signed chunk index determines every other chunk independently. Returning
to an evicted location regenerates the same ink within a build, regardless of
travel direction or visit order. Open paper and water between the bounded
compositions form the transitions; continuous terrain crossing chunk edges and
parallax remain later work.

```swift
import BackgroundUI
ShanShuiScrollingDesign(isPlaying: true).makeView(seed: 42)
```

The camera scales the world height uniformly to the drawing area. Portrait views
show a narrower part of the scenery; wider views show more. Resize preserves the
camera center. Extremely wide, short views show at most four chunk widths, with
paper margins around that span. The separate still scene retains its fit behavior.

Movement is 20 world units per second, with approximately 30 redraw opportunities
per second. Dragging temporarily suspends automatic movement; releasing resumes
the selected Play/Pause state. Pause and the system's Reduce Motion preference
stop automatic movement while leaving manual exploration available. Inactive
scenes stop the clock. Changing seed or returning from another design starts at
chunk zero. A retained view returning after disappearance also starts a fresh
session with the same seed. The harness's Reset returns to seed 42 and the
starting camera.

BackgroundCore exposes `ShanShuiLandscapeChunkGenerator`, `ShanShuiCamera` and
`ShanShuiScrollViewport`. The camera keeps an Int64 index plus a local Double
offset, so meshes and GPU transforms use nearby coordinates throughout travel.
Each individual movement accepts finite distances up to 1e9 world units; invalid
inputs and signed-index overflow throw explicit errors.

A worker actor generates and compiles visible chunks plus one neighbor on each
side. An accepted window holds at most seven chunks; an incoming replacement can
temporarily bring that to fourteen. Rapid requests keep one active preparation
and one replaceable pending request. Superseded results do not enter the cache.
The last drawable camera waits when the next visible chunk is not prepared.
Overlapping GPU buffers are reused; camera-only movement changes transforms,
and all chunks share one ink surface and a stationary, world-seeded paper pass.

Core checks exercise replay, signed-index extremes, camera normalization and
viewport limits. Cache tests cover reuse, eviction, cancellation and discarded
window lifetime. Controller tests suspend preparation to check coalescing,
same-seed Reset, both completion orders, enlarged viewports, retained-view
reappearance and every playback gate. Production GPU tests exercise buffer
reuse, both directions across boundaries, wide/tall resizing, paper stability
and switching back to static rendering. These are functional checks, not a
rendering performance benchmark.

## Garden Wall — a continuous watercolor garden

**Garden Wall** adds weathered warm-gray masonry, sage ivy and grasses, dusty
pink and cream flowers, occasional terracotta pots, and a small charcoal-outlined
cat. Leafy wall plants form clumps of 4–8 hanging sprays, with a seeded count and
varied shape at each existing planting spot. Seed 42 starts with a sleeping cat
near the camera; seed 43 starts with a sitting cat. Later chunks sometimes have
no cat. Subjects stay still while the
camera moves. It shares Shan Shui scrolling's Pause/Play, drag, seed and Reset
controls, viewport scaling, cancellation and bounded window ownership.

```swift
import BackgroundUI
GardenWallDesign(isPlaying: true).makeView(seed: 42)
```

`GardenWallChunkGenerator` returns `InkChunk` values with local 1200 × 800
`InkScene` geometry. World-seeded courses run across every chunk. Staggered
stones that cross a boundary share a canonical cell identity and random stream;
each chunk clips its portion. The mesh compiler also clips expanded strokes to
chunk bounds, preventing overlapping ink at joins. Component streams separate
masonry, layout and subject drawing. Returning to a chunk reproduces its scene
within the same build.

`InkPrimitive` supports straight RGB and grayscale washes/strokes. The existing
ordered Metal ink pass blends both before one paper composite; the neutral
`InkScene`/`InkChunk` names have compatibility aliases for the Shan Shui APIs.
The colors and layered washes are a stylized watercolor treatment, without a
pigment simulation or animated subjects.

To add another scrolling ink design, supply an indexed local chunk generator and
an immutable `InkScrollSource` whose factory creates a fresh worker per view
lifetime. Use a distinct source ID in the view identity and buffer reuse key.
Wrap the shared `InkScrollingView` in a public `BackgroundDesign`, then add its
typed harness entry and playback gate. Other renderers can still conform to
`BackgroundDesign` independently.

The shared host accepts at most seven prepared chunks, plus up to seven incoming
chunks during replacement. That ownership limit is not a measured memory
footprint. Garden Wall tests cover canonical joins against an unclipped reference
through the production GPU path, portrait cat coverage, color, resize, stable
paper, deterministic replay, and same-seed switches between scrolling designs.
Energy use and rendering throughput have not been profiled.

## Night Sky — a painted celestial sky

**Night Sky** fills the preview with indigo paper, overlapping blue/violet washes,
sparse warm stars, wispy clouds, and occasional softly glowing moons. Seed 42
starts with a crescent; seed 43 starts with a rounded moon. At least four moon-free
chunks separate successive moons. The subjects stay still as the camera travels,
using the same Pause/Play, drag/swipe, seed, Reset, and Reduce Motion behavior as
the other scrolling designs.

```swift
import BackgroundUI
NightSkyDesign(isPlaying: true).makeView(seed: 42)
```

`NightSkyChunkGenerator` produces local 1200 × 800 `InkChunk` values. Separate
seed streams determine washes, cloud placement, stars, moon slots, and drawing
details. A wash crossing a boundary retains its canonical owner and paint order
in both chunks; each chunk draws only its clipped portion. The crescent has an
open cutout, and stars/clouds reserve space around the moon's halo. Revisiting a
chunk recreates its geometry within a build; no cross-version serialization
contract is implied.

The shared source supplies `NightSkyChunkGenerator.surfaceColor` and requests a
dark appearance for the preview's loading/error text. The renderer clears the
whole ink surface to that color before drawing, so portrait and very wide margins
also stay indigo. Its existing paper pass still supplies stationary grain.
`InkScrollSource` defaults to white and the inherited appearance for existing
designs; static scene installation restores the white ink surface. Within
`BackgroundUI`, the source forwards that color to `ShanShuiRenderer.installWorld`;
other hosts can use the public generator's surface color with their own renderer.
The generated scene itself contains the artwork, not an opaque background fill.

The design adds no shader pass, bitmap assets, or independently animated effects.
Core and GPU checks cover replay, signed-index boundaries, subject envelopes,
the crescent opening, portrait coverage, all three scrolling-source transitions,
and joins against full unclipped canonical descriptions. Functional checks and
the existing bounded chunk ownership do not measure memory footprint or energy
use; those remain profiling work on a device.

## Mondrian watercolor — a seeded still painting

**Mondrian watercolor** presents unequal red, blue, yellow, white, and black
rectangles separated by charcoal dividers. A large colored field anchors each
composition, with smaller fields and a modest black accent. The initial palette
balances roughly half primary color and half white/black, excluding dividers;
these are soft area goals rather than a fixed quota for each seed.

```swift
import BackgroundUI
MondrianDesign().makeView(seed: 42)
```

`MondrianGenerator` produces a finite 1200 × 800 `InkScene`. Integer rectangle
partitions cover the canvas. Canonical boundary segments retain T junctions
without painting shared boundaries twice. Separate seed streams control layout,
color, pigment, and divider details. Bounded cell-local washes layer restrained
pigment pools and darker edge deposits over strong primary fields; white cells
retain paper grain. Black accents use charcoal variation. This is stylized paint,
not a fluid or pigment simulation, and seed replay is a within-build contract.

The painting fits uniformly, with paper margins in portrait or wider previews.
Seed and Reset work as in the existing still studies; this still design has no
playback control. The separate **Mondrian scrolling** route continues the painting horizontally.

The neutral `InkSceneView` and observable `InkSceneModel` now host Mondrian and
the three existing Shan Shui still studies. A fresh `InkSceneBuilder` worker per
host generates the scene and mesh away from the main actor. Generation tickets
and cancellation checks prevent obsolete preparations from installing after a
newer request or disappearance. The previous drawable remains available if a
replacement fails. Static clipping is enabled for Mondrian; the original studies
retain their existing unclipped geometry. Render passes and shaders are unchanged.
Each submitted frame retains its error callback, so a late error from an older
scene cannot be reassigned to a newer scene's generation ticket.

Geometry and production GPU checks cover partitions, replay, cell clipping,
primary color/pigment, connected junctions, lifecycle ordering, and dark-to-light
installation with wide/portrait resizing. These functional checks do not measure
memory footprint, energy use, or device throughput.

## Mondrian scrolling — an endless watercolor painting

**Mondrian scrolling** continues unequal primary-color, white, and charcoal fields
horizontally. Irregular composition regions have large red or blue bridge cells
across their boundaries; the 1200-unit rendering chunks contribute no frame or
divider geometry. The finite **Mondrian watercolor** study remains available.

```swift
import BackgroundUI
MondrianScrollingDesign(isPlaying: true).makeView(seed: 42)
```

`MondrianChunkGenerator().generate(seed:index:)` is a throwing Core API returning
an `InkChunk`. It reconstructs five nearby ownership groups, with at most 24 cells
per group. Structured signed addresses keep geometry local, including at both
Int64 chunk extrema. Separate seed streams control layout, palette, pigment, and
dividers. Returning after eviction reproduces the same painting within a build.
Full-cell pigment and complete canonical dividers are generated before translation;
the UI compiler clips finished triangles to each receiving chunk. Shared triangle
edges use consistent intersection arithmetic. These bounds describe construction,
not measured memory or energy performance.

The fourth `InkScrollSource` uses the existing fresh-worker, cancellation, bounded
window, and buffer reuse lifecycle. Automatic movement, Pause/Play, drag/swipe,
seed changes, camera Reset, resize, and Reduce Motion follow the shared controls.
Portrait shows a narrower crop rather than rearranging the painting. A phone crop
need not contain every palette color. The watercolor treatment and material shaders
are unchanged; physical-device energy and memory profiling remain future work.

The Mondrian scrolling checks include 192 production-GPU frames against an unclipped seven-group
reference, strict join and translucent-opacity fixtures, signed extrema, replay
after eviction, and all twelve directed transitions between the four scrolling
sources. Manual acceptance on a native Mac covered all ten routes,
all four element subjects, Reduce Motion, wide/tall views, and forward/return travel
over twenty chunk widths. Manual iPhone 17 / iOS 27 Simulator checks covered portrait
and landscape rotation, swiping, playback, seed/Reset, and Night Sky restoration.
These results establish functional behavior on the tested Mac and Simulator;
physical-device profiling remains unmeasured.

## Shan Shui elements

**Shan Shui elements** isolates four subjects on an 800 × 600 paper study. The
leafy tree uses a tapered white trunk and overlapping pointed leaf blobs. The
bare tree uses curved, shrinking branches with bounded recursion. The pavilion
has open posts, perspective rails and curved eaves. The boat includes a posed
figure, robe, broad hat, pole and faint water marks.

These are Swift adaptations of the original drawing routines named in
`THIRD_PARTY_NOTICES.md`. They use our local random sequence, geometry sampling
and Metal ink renderer, so matching JavaScript seed numbers do not imply matching
images. The current mountain study and composed landscape remain separate choices.

`ShanShuiElementGenerator(element:)` produces the existing `ShanShuiScene` format.
Its internal drawing helpers take positions and dimensions; the landscape places
uniformly scaled copies of these canonical studies. `ShanShuiElementDesign(element:)` shares the existing worker/Metal host;
changing the subject replaces the view identity so a previous subject cannot
install its result into the new study. The harness preserves the subject while
switching designs and preserves the seed while switching subjects. Reset changes
only the seed to 42.

```swift
import BackgroundUI

ShanShuiElementDesign(element: .boat).makeView(seed: 42)
```

To add a subject, extend `ShanShuiElement`, add its drawing routine and generator
branch, then add its display title in `BackgroundUI`. The harness's Element menu
uses `allCases`. Check seed replay, finite/bounded ink and actual mesh/GPU output.
The mesh test sweeps 130 seeds per subject, including UInt64 boundaries. It also
covers folded garments: their white fill is a union of small triangles, avoiding
self-crossing offset polygons at bent joints.

## Check changes

From this directory:

```sh
swift test
swift test -c release
xcodebuild -project Harness/BackgroundHarness.xcodeproj \
  -scheme BackgroundHarness -destination 'platform=macOS' build
xcodebuild -project Harness/BackgroundHarness.xcodeproj \
  -scheme BackgroundHarness -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

The package tests exercise seed replay, distinct-seed variation, finite points,
width/sample agreement, triangulation of concave/degenerate fixtures and stroke
joins, including seed boundaries. GPU readback tests use the production renderer
to check paper texture, mountain marks, drawing order and the Swift/Metal buffer
layout. A Metal device is required for those rendering tests.
The app scheme has no separate test target; use `swift test` for those checks.
For UI changes, also run the harness, switch all designs, change/reset the seed,
and check a narrow window or phone. No rendering performance target is claimed.

## License

Released under the [MIT License](LICENSE). The Shan Shui studies adapt drawing
routines from [shan-shui-inf](https://github.com/LingDong-/shan-shui-inf) by
Lingdong Huang (MIT). See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
