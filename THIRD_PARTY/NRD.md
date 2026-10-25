# NVIDIA NRD ReLAX provenance

- Upstream: https://github.com/NVIDIA-RTX/NRD
- Revision: `e06852bd545973cb224eb28820b891205cfc1624` (NRD 4.18).
- Shader dependency: NVIDIA-RTX/MathLib v11,
  `aa432ad9a80691eb8c3ec4d576bbad5ac100fdc8`.
- NVIDIA-derived files: `shaders/program/relax/official_*.glsl` and the normal
  encoding function in `shaders/program/relax/guides.glsl`.
- License: [unmodified upstream NVIDIA RTX SDKs LICENSE](NRD-LICENSE.txt).
- MathLib: [unmodified NVIDIA MIT license](MathLib-LICENSE.txt), including its
  2021 copyright and permission notice for the compiled mathematical helpers.

This software contains source code provided by NVIDIA Corporation.
NVIDIA-derived source retains its own license and notices. Adding the license
file does not relicense this source under the shaderpack's CC BY-NC-SA license.

## Redistribution status

The current license grants distribution in object-code form under section 1(c).
On September 11, 2026, an NRD maintainer explicitly stated that distributing
translated WGSL shader source is not permitted under the current terms:
[official clarification](https://github.com/NVIDIA-RTX/NRD/issues/80#issuecomment-5628546589).
The later suggestion was to distribute SPIR-V binaries instead:
[follow-up](https://github.com/NVIDIA-RTX/NRD/issues/80#issuecomment-5659669548).

Heliopause currently delivers translated GLSL source to Iris, rather than an
object-code-only integration. The WGSL answer does not explicitly discuss GLSL,
but it means that source redistribution cannot be assumed permitted merely
because the source was produced by a compiler. No separate redistribution
permission has been obtained for this integration. Public release is on hold
until permission is obtained or the dependency is replaced. Retaining notices
and license files does not by itself resolve this restriction.

## Translation

For each of `PrePass`, `TemporalAccumulation`, `HistoryFix`, `HistoryClamping`,
`AtrousSmem`, and `Atrous`, compile the matching upstream
`Shaders/RELAX_<name>.cs.hlsl` with DXC:

```
-spirv -T cs_6_0 -E main -O3 -fspv-target-env=vulkan1.1
-D NRD_INTERNAL=1 -D NRD_SIGNAL=1 -D NRD_MODE=0
```

Repeat with `NRD_SIGNAL=2` for specular. Include NRD's `Shaders`, MathLib and the
directory containing this `NRDConfig.hlsli`:

```c
#define NRD_NORMAL_ENCODING 2
#define NRD_ROUGHNESS_ENCODING 1
#define NRD_SUPPORTS_VIEWPORT_OFFSET 0
#define NRD_SUPPORTS_CHECKERBOARD 0
#define NRD_SUPPORTS_HISTORY_CONFIDENCE 0
#define NRD_SUPPORTS_DISOCCLUSION_THRESHOLD_MIX 0
#define NRD_SUPPORTS_ANTIFIREFLY 1
#define NRD_SUPPORTS_QUAD_INTRINSICS 0
#define REBLUR_PERFORMANCE_MODE 0
```

Translate each SPIR-V binary with `spirv-cross --version 430 --no-es`. The local
translation additionally passed `LAST_PASS=1` for Atrous; upstream does not use
that preprocessor symbol in this revision. Its actual last-pass decision remains
the `gIsLastPass` constant supplied separately for every Iris dispatch.

The port replaces the generated UBO member prefix with the constants in
`constants.glsl`. Combined samplers expand to a logical texture ID and filter
mode. Fetch/sample/gather/store calls use `resources.glsl`. The generated
algorithm arithmetic, control flow and shared-memory work remain in the official
files. Runtime wrappers supply each Atrous index and last-pass constant.

Logical resource assignments are documented alongside the adapter in
`shaders/program/relax/RESOURCE_LAYOUT.md`.
