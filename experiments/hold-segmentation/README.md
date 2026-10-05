# Hold segmentation experiments

Preserved on 2026-10-05 from the October 3 local Mac/web prototypes. These experiments have **not** been integrated into the iPhone app. [Evidence and limitations](../../docs/linewise_status_2026-10-05.md#4-分割与交互原型已经做了什么) · [Product proposal](../../docs/linewise_hold_segmentation_proposal_2026-09-13.md).

## Source map

| Entry | Purpose |
| --- | --- |
| `shared.swift` | Raster/mask helpers, Core ML SAM wrapper and contour rendering |
| `compare/main.swift` | Circles, colour flood, Apple Vision and SAM Tiny/Small comparison; click-jitter stability |
| `auto/main.swift` | Seeded same-colour line search and GIF experiment |
| `wall/main.swift` | Whole-wall candidate extraction and polygon/colour JSON |
| `ui/` | Static saved-result interaction and stick-figure simulation prototype |
| `benchmark-summary.json` | Aggregate metrics from historical records and saved JSON; no personal fixtures |

## Build on macOS

Requires Xcode command-line tools. From this directory:

```sh
./build.sh
```

Outputs are `.build/proto`, `.build/autoroute`, `.build/wallseg`. Building needs no model or photo. Running inference needs private fixtures and the corresponding Apple `coreml-sam2.1-tiny` / `coreml-sam2.1-small` FLOAT16 model packages described in the proposal; keep their downloaded notices with them.

## Private inputs and inference

Keep inputs under ignored `data/`, model directories under `models/`, outputs under `out/`, or pass existing absolute local paths. Never commit real wall photos, model weights or generated media.

A cases JSON is an array of objects with `name`, image filename (relative to the JSON), and `taps` containing normalized `x`, `y`, `r`. The seeded colour experiment also requires `seed`, a zero-based index into `taps`. All inputs must be valid; these are exploratory programs, not production parsers.

```sh
.build/proto data/cases.json out/compare models
.build/autoroute data/seeded-cases.json out/auto models/coreml-sam2.1-tiny
.build/wallseg data/cases.json out/wall models/coreml-sam2.1-tiny saliency
```

Comparison expects both model directories inside `models/`; the other entries accept the Tiny directory itself. Whole-wall modes include `grid`, `hybrid`, `saliency` and the diagnostic `taps` mode.

The original local inputs and outputs remain in `.scratch/hold-seg-proto/` at the repository root; the models remain in `.scratch/models/`.

## Web preview

Copy the existing private `wall-yellow.json`, `wall-white.json` and matching JPEGs from `.scratch/hold-seg-proto/ui/` into `ui/data/` (ignored), then run:

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory ui
```

Open `http://127.0.0.1:8765`. This preview loads saved segmentation JSON; its scan animation is a fixed 2.2 seconds and does not measure inference. Missing private fixtures prevent the scene from loading. Browser recording is WebM, not the planned iOS GIF/MP4 export. Body-to-wall scale is adjustable and does not establish a real-world centimetre measurement.

## Evidence boundary

The current App inference core has a separate [native check](../../docs/demo-a-implementation.md#验证): `bash native-check.sh <private-cases.json> <Tiny-models-directory>`. It compiles the App's actual domain and inference sources, validates bounded contours and emits aggregate Mac timings. It needs private inputs and weights; no network download occurs. The current iOS Simulator decoder limitation is documented with the Demo A evidence.

The saved metrics are Mac observations from two compressed wall photos, not an iPhone acceptance test. 21/24 counts contours that survived click/area filtering; jitter IoU compares perturbed clicks, not manual ground truth. Whole-wall counts are candidates, not validated holds. For the current delivery gate use [Demo A](../../docs/roadmap.md).
