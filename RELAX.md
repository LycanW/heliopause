# Heliopause SVGF denoising (NRD-style)

Heliopause runs the actual NVIDIA NRD ReLAX diffuse and specular shaders through
Iris compute passes. The HLSL algorithm was compiled with DXC and translated to
GLSL by SPIRV-Cross. The GLSL resource and constant interface is adapted to Iris;
the filters are not a replacement approximation with the same name.
The menu label describes the denoiser family; it does not mean an independent
implementation or a complete native NRD SDK integration. Source identity and licensing are recorded in [THIRD_PARTY/NRD.md](THIRD_PARTY/NRD.md).
This is a local experimental integration, not a redistributable release package.

## Signals and pass order

Both signals run at the full internal render resolution. The former half-resolution
diffuse/specular paths and their SVGF temporal/spatial filters have been removed.
The diffuse result is still available to the reflection tracer in the same frame.

Each signal runs input preparation, PrePass, TemporalAccumulation, HistoryFix,
HistoryClamping, AtrousSmem and the remaining Atrous passes. Diffuse occupies
`deferred1` through `deferred10`. Specular starts at `deferred22`, uses its compute
suffixes, and ends at `deferred26`. The first Atrous pass uses shared memory;
the default total is five Atrous passes per signal.

The current integration uses no checkerboard input, hit-distance reconstruction,
history confidence input, anti-firefly pass, or tile classification pass. A zero
tile mask runs all tiles; the official depth and viewport checks still apply.
History acceleration and lighting-change reset amounts start at zero, as suggested
by the NRD integration guidance for establishing a stable baseline.

Solar shadows retain their own original denoising path. ReLAX does not denoise
these shadow samples. TAA and auto exposure also remain independent.

## Input meaning

- Diffuse carries the existing primary-material-independent indirect illumination.
  The primary albedo is applied by the original downstream lighting consumer.
- Specular carries reflected radiance before the primary Fresnel factor. A flat
  perfect mirror follows its deterministic reflection prefix and supplies the
  first receiving surface's reflected position, normal and roughness to ReLAX
  (primary surface replacement). Emission, direct light and cached diffuse light
  in this prefix retain their texture detail outside the specular filter. Later
  stochastic reflection is demodulated by the prefix throughput before filtering
  and remodulated on composition. Rough primary reflections retain their usual
  signal and primary-surface guides.
- Alpha carries the mean first-segment ray distance in world units. ReLAX receives
  linear positive view depth, world-space shading normals and perceptual roughness.
  Heliopause passes GGX alpha to VNDF sampling, so the adapter supplies its square root
  to NRD. The normal/roughness packing matches NRD normal encoding 2.
- The adapter flips Minecraft's bottom-left image rows to NRD's top-left convention.
  NRD receives non-jittered matrices and frustum vectors; jitter is expressed in
  pixels. Discrete R8/A2 metadata is quantized on atlas stores and point loads so
  FP16 rounding cannot change material comparisons or reset history counters.
- Motion currently describes static world geometry under camera movement. Separate
  per-object motion for entities, waving geometry, moving POM hits and moving
  reflected objects is not supplied. These cases still need dedicated validation.

## Settings

Open **Path Tracing > SVGF (NRD-style)** (Chinese: **路径追踪 > SVGF 时空降噪（NRD 风格）**).

| Setting | Default |
|---|---:|
| Diffuse history limit | 32 |
| Reflection history limit | 32 |
| Fast history length | 6 |
| Atrous passes | 5 |
| Diffuse prefilter radius | 30 pixels |
| Reflection prefilter radius | 50 pixels |

Performance selects three Atrous passes; the other profiles select five. Every
profile restores all six ReLAX settings when selected. Larger history limits can
reduce temporal noise while delaying response to lighting changes. Fewer spatial
passes reduce work while leaving more residual noise. Depth/normal controls for
the independent legacy shadow filter are in the shadow settings menu.

Two additional controls are available in every profile. **Cache sunlight
importance sampling**, in the irradiance-cache menu, defaults on. It combines
hemisphere samples with up to three GGX proposals for principal-axis receiving
surfaces, using balance-heuristic MIS. The actual ray intersection determines the
surface class; other geometry, sky, emission and diffuse paths retain hemisphere
sampling. This reduces rare, very bright reflected-sun samples without clamping
them or dropping their energy. Direct specular visibility is traced at the hit.
Zero-albedo lobes no longer request diffuse-cache entries they cannot consume.

**Perfect mirror history**, under antialiasing, defaults to 32 frames. It applies
to valid static replacement surfaces, drops toward the general TAA limit with
camera motion and uses the available NRD history for newly exposed surfaces.
The cache also distinguishes quantized surface normals in its identity; screen
lighting reuse requires agreement in the actual source plane and normals.

## Storage and costs

Iris custom images store the logical NRD textures in two RGBA16F atlases (4x4 and
2x2 logical tiles), plus three R32F depth tiles. Passes read and write disjoint
logical tiles; Iris provides barriers between dispatches. Per-tile clamping keeps
linear filtering and gathers from sampling adjacent histories. HLSL out-of-range
loads explicitly return zero.

`allowConcurrentCompute` is explicitly false: dependent compute suffixes require
Iris's per-dispatch image, texture-fetch and storage barriers. The original pack's
concurrent setting cannot be retained for this graph.

The two-tile mirror payload stores deterministic radiance and specular throughput.
This allocation uses approximately **188 bytes per internal pixel**, or **372 MiB
at 1920x1080**, in addition to other shaderpack resources. It trades storage
precision/format optimization for a direct first integration within Iris's image
binding limits. The former full-screen SVGF history targets are retired to 1x1
slots. The largest atlas requires four times the internal width and height to fit
within the GPU's maximum 2D texture size.

Reflection tracing now performs four times as many pixel launches as the former
half-width/half-height path at the same internal resolution. Denoiser timing must
be separated from this changed ray-tracing work before attributing performance
differences to ReLAX itself.

The reported flat-mirror slow brightness pulses were reproduced and traced through
the cache producer and both reconstruction stages. Local Arc A770 acceptance
includes a frozen-world static sequence, camera rotation and translation, lighting
changes and fractional render scaling. Finite Monte Carlo sampling and output
dithering still leave sub-code-level temporal noise. This is not a guarantee for
all scene content or dynamic objects; the independent shadow-placement issue and
missing per-object motion remain separate work.

## Irradiance cache update ordering

`composite19` retires expired cache entries and copies the complete table to a
read-only update source at SSBO binding 6. `composite19_a` reads each entry and
all recursive lighting lookups from that source, and writes the updated lighting
to the live table at binding 2. The pack explicitly selects sequential compute so
Iris supplies the storage barrier between the two dispatches. Do not enable
concurrent compute without supplying an equivalent synchronization boundary.

Cache requests still update the live table's rank, last-used frame and trace
origin. New allocations during the update are retained for the next update;
they do not enter the current read snapshot. Retirement happens before requests
can be inserted, so an invocation for an old empty slot cannot erase a new request.
Normal rendering continues to consume the live table after updates are published.

The snapshot costs another 32 bytes per configured cache slot: 1 MiB at the
default 32768 slots, scaling to 8 MiB at 262144 slots. Each frame adds one compute
dispatch and a full-table read/copy write (about 2 MiB of logical transfer at the
default capacity), plus the relocated retirement writes. This is a storage and
work accounting, not measured GPU timing. Sampling positions, sample counts,
cache blending and ReLAX settings are unchanged by this ordering change.
