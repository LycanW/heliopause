# Heliopause known issues

Maintained by LycanW. Updated October 26, 2026.

| Issue | Current status |
|---|---|
| Shadow placement and temporal fluctuations | Still under investigation. The mirror repair does not establish direct-shadow accuracy. |
| Static flat-mirror brightness pulses | Controlled static opaque mirror cases meet the native filter's temporal-noise and physical-energy gates on Arc A770. Finite history retains residual noise. |
| Mirror texture contrast | The measured mirror ROI retains about 98% of linear HDR local contrast and 94% in final SDR. It does not meet a 95% final-SDR contrast requirement. |
| Lighting response | Controlled phase-averaged added response is 1-9 frames; individual noisy phase crossings can exceed 16 frames. |
| Mirror screen-edge fragments after ReLAX integration | No added fragments were observed in the controlled native edge, resize and scaling tests on Arc A770. Other scenes and GPUs remain unqualified. |
| Dynamic geometry and reflections | The replacement reconstructs static-world camera motion. Separate motion for entities, waving geometry, displaced POM hits and moving reflected objects is not supplied. |
| Normal maps in reflections | Remains an upstream limitation. |
| Rain particles | Remains an upstream limitation. |
| Brief light leaks when breaking cave blocks | Remains an upstream limitation. |
| Incomplete terrain capture in some scenes | Report the scene and configured triangle / voxel capacities; increasing capacities may help when the pools are exhausted. |
| Initial shader loading time | The first compilation can be slow. |
| OrthoCamera | Upstream support is incomplete; not qualified for this version. |

## Release status

Controlled native validation has completed for static opaque scenes, camera motion,
large lighting changes and representative lifecycle settings on Arc A770. Sparse
secondary specular estimates can still enter shorter responsive history and retain
local normalized-signal bias; qualified recomposed mirror output does not establish
per-lobe or whole-scene unbiasedness. These are the controlled validation limits
of v0.3.0, not an all-scene acceptance claim.
See [DENOISING.md](DENOISING.md) and [provenance](THIRD_PARTY/Falcor.md).

## Reporting a problem

Use [Heliopause issues](https://github.com/LycanW/heliopause/issues). Include the
Minecraft and Iris versions, GPU and driver, selected quality profile, resource
pack, and reproduction steps. A short recording helps distinguish persistent
artifacts, convergence, camera motion and exposure changes.
