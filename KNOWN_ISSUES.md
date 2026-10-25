# Heliopause known issues

Maintained by LycanW. Updated October 26, 2026.

| Issue | Current status |
|---|---|
| Shadow placement and temporal fluctuations | Still under investigation. The mirror repair does not establish direct-shadow accuracy. |
| Static flat-mirror brightness pulses | Reproduced and repaired in a controlled Arc A770 scene. Finite sampling and output dithering still produce small residual variation. |
| Mirror screen-edge fragments after ReLAX integration | Missing compute synchronization was corrected; dependent passes now run sequentially. |
| Dynamic geometry and reflections | ReLAX currently receives static-world camera motion. Separate motion for entities, waving geometry, displaced POM hits and moving reflected objects is not supplied. |
| Normal maps in reflections | Remains an upstream limitation. |
| Rain particles | Remains an upstream limitation. |
| Brief light leaks when breaking cave blocks | Remains an upstream limitation. |
| Incomplete terrain capture in some scenes | Report the scene and configured triangle / voxel capacities; increasing capacities may help when the pools are exhausted. |
| Initial shader loading time | The first compilation can be slow. |
| OrthoCamera | Upstream support is incomplete; not qualified for this version. |

## Release status

v0.3.0 publication is pending resolution of translated NVIDIA shader source
redistribution. See [THIRD_PARTY/NRD.md](THIRD_PARTY/NRD.md).

## Reporting a problem

Use [Heliopause issues](https://github.com/LycanW/heliopause/issues). Include the
Minecraft and Iris versions, GPU and driver, selected quality profile, resource
pack, and reproduction steps. A short recording helps distinguish persistent
artifacts, convergence, camera motion and exposure changes.
