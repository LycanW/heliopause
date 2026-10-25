# ReLAX logical resource layout

| ID | Lifetime / contents |
|---:|---|
| 0 | Current noisy diffuse, then noisy specular; RGB radiance, A first-segment distance |
| 1 | Current world normal / perceptual roughness in NRD encoding 2; A2 surface class |
| 2 | PrePass output |
| 3, 4 | Diffuse slow / fast history |
| 5, 6, 7 | Previous diffuse normal / material ID / history length |
| 8, 9 | Shared temporal and Atrous ping / pong |
| 10 | Current history length |
| 11, 12 | Specular slow / fast history |
| 13, 14, 15 | Previous specular normal / material ID / history length |
| 16, 17 | Specular hit distance ping / pong, selected by frame parity |
| 18 | Specular reprojection confidence |
| 19 | Unused atlas tile |
| 100 | Current linear positive view depth |
| 101, 102 | Previous diffuse / specular view depth |
| -1 | Constant zero tile mask / absent optional input |
| -10 | Final output to colortex2, row-flipped back to Minecraft |

IDs 0-15 occupy nrPool0, IDs 16-19 occupy nrPool1, and 100-102 occupy nrDepth.
Histories for each signal retain independent previous normals, materials and
depths because diffuse runs before the reflection tracer and specular denoiser.

| Pass | Reads (signal-dependent history IDs abbreviated) | Writes |
|---|---|---|
| Prepare | Minecraft depth/material and colortex2 | 0, 1, 100 |
| PrePass | 0, 1, 100 | 2 |
| TemporalAccumulation | 2, 1, 100, previous metadata and histories | 8, 9, 10; specular also 16/17, 18 |
| HistoryFix | 8, 10, 1, 100 | 9 |
| HistoryClamping | 2, 8, 9, 10 | Slow history, fast history, previous history length |
| AtrousSmem | Slow history, 10, 1, 100; specular also 18 | 8, previous normal/material/depth |
| Atrous index 1 | 8, 10, 1, 100 | 9 or final output |
| Atrous index 2 | 9, 10, 1, 100 | 8 or final output |
| Atrous index 3 | 8, 10, 1, 100 | 9 or final output |
| Atrous index 4 | 9, 10, 1, 100 | Final output |

The filter pass count is 2-5 including AtrousSmem. Dispatch local sizes are taken
from each translated official shader, not assumed to be 8x8. Inputs and metadata
are top-left oriented throughout NRD. Atlas offsets use integer internal target
dimensions; atlas allocation can contain unused padding at fractional render scales.

Diffuse preparation writes primary-surface guides. Reflection tracing replaces
guides 1/100 with the virtual receiving surface for perfect planar mirrors and
writes a separate two-tile RGBA16F `nrMirrorPayload`: deterministic prefix radiance
and specular throughput. Reflection preparation copies only the noisy specular
signal to layer 0, preserving those guides. Surface class 0 denotes an ordinary
primary surface and class 1 a replacement surface. Previous normal textures retain
their packed normal/roughness alpha, not an A2 material ID.

R8 metadata layers 6, 7, 10, 14, 15 and 18 are quantized to UNORM8 on stores and
point loads; layer 1 alpha is quantized to A2. This emulates the SDK's discrete
formats inside FP16 storage. The total NRD and mirror allocation is 188 bytes per
internal pixel; the cache's independent SSBO snapshot is additional.
