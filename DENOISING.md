# Heliopause SVGF denoising

Heliopause adapts Falcor SVGF to native Iris GLSL compute passes and adds
NRD-inspired change response and reflection handling. It uses no NRD SDK shader
kernels. See [Falcor provenance and license](THIRD_PARTY/Falcor.md).

This is a finite-history estimator. A static scene retains some Monte Carlo noise;
it does not accumulate indefinitely to an unchanging offline result. Static
geometry and camera motion have a defined reprojection model. Animated entities,
waving geometry, moving reflected objects and POM displacement still lack their
own motion inputs. Direct-shadow placement is outside this filter's responsibility.

## Signals and correspondence

- Primary diffuse stores illumination before the primary albedo multiplication.
  It accumulates on a canonical pixel grid and is reconstructed with geometric and shading-normal support at the current
  jittered sample before material composition and screen-lighting reuse.
- Primary rough reflection accumulates its complete physical contribution,
  including primary Fresnel, on the canonical grid. Composition does not multiply
  Fresnel again. The same temporal weight integrates the shading-normal first
  moment and squared GGX alpha. Spatial reconstruction uses their mean direction
  and angular spread rather than this frame's independently jittered normal.
- A flat perfect mirror replaces the primary surface with a virtual receiver.
  Specular receiver history keeps the jittered-point correspondence. Pure mirror
  conductors have no primary diffuse signal: those diffuse history/moment slots
  store the receiver's diffuse illumination independently. Other mirror paths use
  a unified receiver signal. Actual emission remains outside the stochastic filter;
  sampled lighting and visibility do not become a deterministic prefix.
- Split receiver diffuse is multiplied by its actual throughput/albedo factor;
  receiver specular is remodulated separately. The primary mirror Fresnel is
  applied during composition. No raw stochastic segment length guides the spatial
  RGB filter. Filtered alpha carries no segment-distance estimate.
- Current and previous geometric/shading guides remain distinct. Four bilinear
  history taps are checked for surface class, plane separation and relevant normal
  agreement. Specular correspondence also accounts for the reflected direction.
  View-angle attenuation uses atan of cross/dot rather than acos of a nearly unit
  dot product, avoiding a false angle from stationary-view rounding.
  Supported weights normalize RGB, moments and age together. Missing correspondence
  starts new history; there is no second reprojection search or whole-screen reset.
- Coordinates follow Minecraft's bottom-left convention and unjittered Iris
  matrices. Reprojection applies camera translation once. Primary canonical
  histories omit previous jitter; virtual specular history uses previous jitter.
  Camera-attached hands start new world-space history each frame.

## Reconstruction and response

The current sample receives eight rotating, geometry/shading-guided taps plus the
center. Both RGB accumulation and change detection observe that same estimate.
A wrapping unsigned Weyl phase drives rotation without losing fractional phase
at large frame counters.

The fast state stores **fast luminance, independent reference luminance,
reference age and response hold**, not a second RGB reconstruction. Detection
windows cover 16 jitter phases, or 32 frames for sparse virtual specular paths.
`SVGF_FAST_HISTORY` controls the short RGB response window (default six frames).
The detector reference evolves independently of partial RGB response corrections.
A confirmed change rebases it to the fast luminance estimate.

A geometry-weighted median of nine signed relative changes controls the response.
Sorting is unnecessary when the weighted median is provably within the response
function's zero interval. Two newly confirmed neighbors can extend the response
by one stencil, provided the recipient also observes contrast. Copied holds start
one frame lower, so they cannot propagate a response wave. Correction is a convex
mix that increases the integration weight; it does not clamp radiance samples.

First and second luminance moments accumulate in FP32. Falcor's geometry-aware
7x7 reconstruction bootstraps histories younger than four frames. The configured
2-5 a-trous iterations use a 5x5 kernel, a 3x3 variance estimate and squared-weight
variance propagation. Scratch alpha stores standard deviation in FP16; persistent
moments remain FP32. Spatial output is not fed back (Falcor FeedbackTap = -1).

Reduced-float history/scratch writes explicitly round to nearest, ties to even.
The R11/G11/B10 temporary detector write is rounded explicitly as well. This
avoids a persistent downward integration bias on the tested Intel image-store path.

## Passes and resource lifetime

| Signal | Stages |
|---|---|
| Primary diffuse | `deferred1` guides; `2` temporal; `2_a` response; `3` history/bootstrap; `4`-`8` a-trous; `9` canonical resolve and screen-lighting copy |
| Split virtual diffuse | `deferred21_a` temporal; `_b` response; `_c` history/bootstrap; `_d`, `_e` a-trous; resolve folded into specular temporal |
| Specular | `deferred21` tracing/guides; `22` temporal; `22_a` response; `22_b` history/bootstrap; `22_c`-`22_f`, `23` a-trous |

The primary diffuse resolve publishes `colortex12` directly; the separate
`deferred12` copy remains enabled only without denoising and declares the matching
R11/G11/B10 image format. Virtual diffuse resolves
inside specular temporal while its scratch result is immutable. Its factor in
`colortex10` is read at the same pixel before that buffer becomes specular detector
output. The following response dispatch reads that detector after Iris's barrier.
`colortex10` is overwritten by normal post-processing before its later consumers.
Reserved mirror pixels restore their absent primary diffuse contribution to zero
in `colortex12` after the temporary virtual-diffuse detector has been consumed.

Iris's default non-concurrent compute dispatch inserts image/texture/storage
barriers. Temporal history reads finish before history publication. No dispatch
reads neighboring pixels that it concurrently overwrites. Inactive classes publish
an invalid previous guide and defined reconstruction zero; unrelated stale RGB
need not be cleared. Reserved primary diffuse slots retain virtual receiver history
until its later stage. Iris clears custom images on allocation and resize.

## Storage and settings

| Custom image | Format / logical tiles | B/internal pixel |
|---|---|---:|
| `svgfHistory` | RGBA16F x4: diffuse slow/state, specular slow/state | 32 |
| `svgfStats` | RG32F x4: persistent diffuse/specular moments, current moments, current age/padding | 32 |
| `svgfGeometry` | RGBA16UI x3: current, previous diffuse, previous specular | 24 |
| `svgfDepth` | R32F x3: corresponding positive view depths | 12 |
| `svgfScratch` | RGBA16F x3: temporal staging, then spatial ping/pong | 24 |
| `svgfMirror` | RGBA16F x2: prefix and receiver factor; primary normal-mean staging | 16 |
| Total | Existing inputs/outputs and fractional-scale padding excluded | **140** |

At 1920x1080 this is 276.855 MiB, compared with the preceding 188 B/pixel layout's
371.777 MiB. Logical allocation is separate from driver/process memory and traffic.
Without denoising only the 16 B/pixel mirror payload remains. Atlases use floored
internal-resolution tile addresses; relative allocation may include padding.

Each 64-bit guide stores geometric oct8x2, shading oct12x2, roughness UNORM9,
mean-normal length UNORM12 and a three-bit surface class. Depth stays FP32.
Class zero means absent signal, not a valid zero-light estimate. Primary, hand,
split/unified virtual receiver, mirror miss and reserved diffuse slots have distinct
meanings.

Default limits are 48 diffuse, 128 primary specular and 96 virtual receiver frames.
The response threshold is 0.20; primary diffuse/specular prefilter radii are 24/4
internal pixels. FAST selects three spatial iterations; other profiles select five.
Split receiver diffuse uses two spatial iterations. `SVGF_*` replaces `RELAX_*`;
select a profile explicitly after upgrading. Test authorization and local acceptance
receipts remain outside this shaderpack repository.
