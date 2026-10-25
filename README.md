# Heliopause

**Real-time path-traced lighting for Minecraft · Maintained by [LycanW](https://github.com/LycanW)**

Heliopause continues [Zephyr Starlight](https://github.com/Kirilpro6284/zephyr-starlight)
by **Kirilpro6284**, with Intel compatibility fixes, revised lighting reconstruction,
and English and Simplified Chinese shader settings.

[Releases](https://github.com/LycanW/heliopause/releases) ·
[Report an issue](https://github.com/LycanW/heliopause/issues) ·
[Changelog](Changelog.md)

![Colored ceiling lights and reflections in a tiled corridor](assets/heliopause-colored-lighting.png)

> **v0.3.0 release preparation:** the current ReLAX integration contains translated
> NVIDIA shader source. Public release is on hold pending redistribution permission
> or a replacement implementation. See [third-party provenance](THIRD_PARTY/NRD.md).

## Features

- Path-traced diffuse lighting, multi-bounce reflections and sunlight shadows.
- Geometry-aware ray intersections and a sparse irradiance cache for indirect light.
- SVGF-family diffuse and specular denoising, labeled **SVGF (NRD-style)** in
  settings. The current kernels are translated NVIDIA NRD ReLAX shaders.
- Mirror virtual-surface reconstruction, separate mirror history control, and
  importance sampling for reflected sunlight in the irradiance cache.
- LabPBR normal and specular maps, parallax occlusion mapping (POM), and integrated
  materials for vanilla textures. Resource-pack material values take precedence.
- Physical sky, water refraction and caustics, volumetric light and subsurface scattering.
- Temporal antialiasing and upscaling, bloom, exposure, depth of field and motion blur.
- Four quality profiles and English / Simplified Chinese settings.

See [Denoising integration notes](RELAX.md) for signal inputs, controls and memory costs.

## Compatibility and installation

The current development and validation target is **Minecraft 26.3, Iris 1.11.7,
and Intel Arc A770 on Windows**. Other GPU, driver and Minecraft combinations
have not been qualified for this release. Iris must provide SSBO and custom-image
support. OptiFine and macOS are unsupported; Distant Horizons and Voxy integration
are not implemented.

When a release is available, place `Heliopause-v0.3.0.zip` in Minecraft's
`shaderpacks` directory and select it in Iris. A shaderpack ZIP must contain
`shaders/` directly at its root. For a source checkout, use the directory containing
this README and `shaders/` as the pack root.

A LabPBR resource pack is optional, but normal, height and custom specular effects
require matching material textures. For POM, set **Terrain > Parallax Occlusion
Mapping > Texture Resolution** to the resource pack's resolution; the default is
16. Height data comes from the normal texture's alpha channel.

## Quality profiles

New installations and reset options use **Balanced**. Normal and specular mapping
are enabled in every profile; POM is enabled from Balanced upward.

| Profile | Internal render scale | Diffuse / reflection / shadow samples | Reflection bounces | POM steps |
|---|---:|---:|---:|---:|
| Performance | 75% | 1 / 1 / 1 | 1 | Off |
| Balanced (default) | 100% | 1 / 1 / 2 | 3 | 32 |
| High | 100% | 1 / 2 / 2 | 4 | 64 |
| Ultra | 100% | 2 / 4 / 4 | 6 | 128 |

Diffuse and reflections run at full internal resolution. Profiles also adjust
cache sampling, denoising, volumetrics and camera effects. Performance uses three
ReLAX spatial passes; the other tiers use five. These tiers describe rendering
work, not guaranteed frame rates.

Saved shader options override defaults. Select a profile explicitly or reset
options after upgrading. Material resolution, POM depth, scene capture and memory
capacities remain independently adjustable.

## Gallery

![A sunlit opening reflected across an indoor pool](assets/heliopause-water-lighting.png)

![A tall hall lit by emissive blocks and reflected light](assets/heliopause-reflection-hall.png)

Screenshots supplied by LycanW, captured on October 25, 2026. They illustrate
development scenes and material effects, and predate the final v0.3.0 fixes.
They are not a comparison or validation capture of the release build.

## Current limitations

This is an experimental shaderpack. Shadow-placement accuracy remains under
investigation. ReLAX currently receives camera motion for static geometry;
independent entity motion, animated geometry and moving reflected objects need
further work. See [known issues](KNOWN_ISSUES.md) before reporting a problem.

Include Minecraft / Iris versions, GPU and driver, selected profile, resource
pack, and a reproducible scene when opening an issue in
[this repository](https://github.com/LycanW/heliopause/issues).

## Credits and licenses

- **LycanW** — Heliopause maintenance, compatibility fixes and subsequent changes.
- **[Kirilpro6284](https://github.com/Kirilpro6284)** — original Zephyr Starlight.
- **[NVIDIA](https://github.com/NVIDIA-RTX/NRD)** — NRD ReLAX and MathLib.
  This software contains source code provided by NVIDIA Corporation.
- **[lucysir / kadir014](https://github.com/kadir014)** — blue-noise sampling.
- **[jbritain](https://github.com/jbritain)** — upstream AMD support and blue-noise texture.
- **[agentclone8](https://github.com/agentclone8)** — BRDF function.
- **[sixthsurge](https://github.com/sixthsurge)** — debug text rendering.
- **[Player2950 / ArslanShakirov](https://github.com/ArslanShakirov)** — playtesting.

The original shaderpack and Heliopause changes retain **[CC BY-NC-SA 4.0](LICENSE)**.
NVIDIA-derived sources retain their separate **[NVIDIA RTX SDK license](THIRD_PARTY/NRD-LICENSE.txt)**;
MathLib helpers retain their **[MIT license](THIRD_PARTY/MathLib-LICENSE.txt)**.
These dependencies are not relicensed under CC BY-NC-SA. Their revisions,
translation process and current redistribution restriction are recorded in
[THIRD_PARTY/NRD.md](THIRD_PARTY/NRD.md).
