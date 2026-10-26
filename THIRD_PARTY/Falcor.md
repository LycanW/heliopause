# Falcor SVGF provenance

Heliopause adopts the SVGF filter implementation from NVIDIA Falcor and adds
independent NRD-inspired history and reflection handling for Iris.

- Revision: `759aad033ff610fb0d82c74f7e0a508d0096d5f2`.
- Source: https://github.com/NVIDIAGameWorks/Falcor/tree/759aad033ff610fb0d82c74f7e0a508d0096d5f2/Source/RenderPasses/SVGFPass
- License: BSD-3-Clause, reproduced in [Falcor-LICENSE.txt](Falcor-LICENSE.txt).
- Adapted sources: `SVGFCommon.slang`, `SVGFReproject.ps.slang`,
  `SVGFFilterMoments.ps.slang`, and `SVGFAtrous.ps.slang`.
- Derived files: `shaders/program/svgf/common.glsl`, `temporal.glsl`,
  `history.glsl`, and `atrous.glsl`. Their original copyright and license
  notices are retained. Heliopause-specific adapters and additions retain
  the shaderpack's license.

Changes include native GLSL compute interfaces, geometry-aware four-tap
reprojection, separate geometric and shading normals, independent luminance change detection and responsive RGB integration,
local change-driven temporal integration, view-dependent specular reuse,
virtual mirror receiver guides and explicit history publication boundaries.
The original filter's raw-sample NaN substitution and secondary reprojection
search are not adopted. Invalid geometric correspondence starts new history.

NRD is a design reference, not a code dependency of this implementation.
Official NRD-translated kernels, NRD encoding and their resource adapters have
been removed from the current source tree. No NVIDIA RTX SDK code or MathLib
helpers are used by the replacement. Historical snapshots remain separate
research evidence; this note does not erase or relicense earlier commits.

Algorithm references:

- Schied et al., 2017, Spatiotemporal Variance-Guided Filtering:
  https://research.nvidia.com/labs/rtr/publication/schied2017spatiotemporal/
- NRD public integration guidance (history and PSR concepts):
  https://github.com/NVIDIA-RTX/NRD/blob/e06852bd545973cb224eb28820b891205cfc1624/README.md

Controlled compilation, Iris loading, numerical, quality and complete-cost checks
have completed on Intel Arc A770 for static opaque scenes and camera motion.
Animated geometry, per-object motion and other GPUs remain unqualified. See [DENOISING.md](../DENOISING.md).
