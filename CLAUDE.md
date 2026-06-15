# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A **lilToon custom shader extension** named `ShadowEx`, distributed as a Unity package and consumed inside a Unity project alongside the lilToon package. It adds screen-space pseudo shadows (**SSAO** + **Contact Shadow**) to lilToon, targeting VRChat avatars on the Built-in Render Pipeline. The design (`_CameraDepthTexture`-based, no GrabPass) is specified in [Docs/Impl/requirements.md](Docs/Impl/requirements.md).

There is **no CLI build/lint/test workflow**. Shaders are compiled by the Unity Editor when lilToon generates the actual `.shader` files from the `.lilcontainer`/`.lilblock` sources here. Verification = open the material in Unity, watch the Console for HLSL compile errors, and inspect the result visually. lilToon's shader generator stitches these template files together; you edit templates, not generated shaders.

## Authoritative reference

`.claudecode/skills/lilToonExtensionDevSkill/` is the project's own development guide (Japanese). **Read it before non-trivial shader/Inspector changes** — it mirrors the lilToon docs and encodes the gotchas:
- `03_custom_shader.md` — how custom shaders work (macros, insert points, Inspector)
- `04_utilities.md` — HLSL macro/function/struct reference (`LIL_SAMPLE_*`, `lilFragData`, etc.)
- `05_custom_shader_format.md` — `.lilcontainer` / `.lilblock` file spec
- `06_geometry_shader.md` — geometry shader insertion (`LIL_CUSTOM_VERT_COPY`, `Replace` blocks)
- `07_checklist.md` — post-implementation error-prevention checklist (run through it after edits)
- `SKILL.md` / `README.md` — overview, dev flow, common-error table

## Architecture

The feature is wired through five cooperating files. Editing one without the others breaks it:

1. **`Shaders/lilCustomShaderProperties.lilblock`** — ShaderLab property declarations (the Inspector-visible knobs). Pulled into every `.lilcontainer` via `lilProperties "lilCustomShaderProperties.lilblock"`.
2. **`Shaders/custom.hlsl`** — declares the matching HLSL variables in `LIL_CUSTOM_PROPERTIES` / `LIL_CUSTOM_TEXTURES`, and chooses **insert points** via `BEFORE_xx` / `OVERRIDE_xx` / `LIL_CUSTOM_VERTEX_*` macros. The shadow is applied with `#define BEFORE_OUTPUT lilApplyScreenSpaceShadow(...)`. `LIL_V2F_FORCE_POSITION_WS` forces world position into v2f because the effect needs it.
3. **`Shaders/custom_insert.hlsl`** — the actual HLSL logic (the SSAO/Contact-Shadow functions). Included via `lilCustomShaderInsert.lilblock` (`lilSubShaderInsert`), which injects it **right after the Unity library `#include`, before lilToon helpers exist**. Consequence: use Unity stock functions only (`UnityWorldToClipPos`, `LinearEyeDepth`, `UNITY_MATRIX_V`), not `lilTransform*`. Pass-specific code is gated with `#if defined(LIL_PASS_FORWARD)` etc.
4. **`Editor/CustomInspector.cs`** — `lilToon.ShadowExInspector : lilToonInspector`. `LoadCustomProperties()` binds each property by exact name via `FindProperty`; `DrawCustomProperties()` draws the GUI; `ReplaceToCustomShaders()` maps every shipped shader variation to `Shader.Find(...)`.
5. **`Shaders/*.lilcontainer`** — the shader variation definitions (opaque/cutout/transparent × outline × lite × tessellation × multi). `*LIL_SHADER_NAME*` / `*LIL_EDITOR_NAME*` placeholders are filled at generation time. `ltspass_*.lilcontainer` are the per-rendering-mode pass collections.

Data flow at generation: `.lilcontainer` (variation) → pulls in properties block + `lilCustomShaderDatas.lilblock` (names) → inserts `custom_insert.hlsl` after Unity includes → lilToon's own forward pass includes `custom.hlsl`, expanding the `BEFORE_OUTPUT` macro into the pixel shader.

## Critical invariants

**Name consistency across 4 places** (the most frequent bug — one mismatch breaks the Inspector or hides the shader):
- `Shaders/lilCustomShaderDatas.lilblock`: `ShaderName "ShadowEx"` and `EditorName "lilToon.ShadowExInspector"`
- `Editor/ShadowEx.asmdef`: `"name"` field **and the filename itself**
- `Editor/CustomInspector.cs`: class name, `namespace`, and the `shaderName` constant

Symptoms: shader missing from list → `ShaderName` ≠ `shaderName`; Inspector falls back to default → `EditorName` ≠ fully-qualified class name; Inspector shows magenta/error → HLSL compile error (check Console).

**`LIL_CUSTOM_PROPERTIES` macro formatting** — every line ends with `\` **except the last**; no whitespace/comments after a `\`. Textures go in `LIL_CUSTOM_TEXTURES`, never mixed into `LIL_CUSTOM_PROPERTIES`.

**Deleted variations stay deleted.** Special variations (Refraction / Fur / FurOnly / Gem / FakeShadow / Overlay and their Multi forms) were removed to slim the build. Their `.lilcontainer` files are gone and the corresponding `Shader.Find(...)` lines in `ReplaceToCustomShaders()` are removed — do **not** re-add `Shader.Find` for a variation that has no `.lilcontainer` (it leaves a permanent null). The git status showing deleted `lts_fur*`, `lts_gem*`, `lts_ref*`, `lts_overlay*`, etc. reflects this deliberate slimming.

**`custom_insert.hlsl` runs before lilToon helpers** — Unity stock functions only there; don't redeclare `_CameraDepthTexture` (lilToon already declares it as `Texture2D`, so sample with `.SampleLevel(...)`, not `SAMPLE_DEPTH_TEXTURE`).

## Conventions

- Code comments in this repo are written in **Japanese**; match that when editing.
- `.lilcontainer`/`.lilblock` are whitespace- and line-ending-sensitive (especially geometry-shader `Replace` blocks, which must match lilToon's generated code byte-for-byte, including `\r\n`). Preserve exact formatting.
- VRChat performance: keep `_SSAO_Samples` + `_ContactShadow_Steps` ≤ 12 total (loop counts dominate cost in crowded instances).
