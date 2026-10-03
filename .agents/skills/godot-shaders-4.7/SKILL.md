---
name: godot-shaders-4.7
description: >
  Use for Godot 4.7 .gdshader and ShaderMaterial work: spatial/canvas shaders,
  uniforms, screen/depth textures, per-instance parameters, and shader performance.
---

# Godot 4.7 Shaders

Project renderer: Forward Plus. Use current Godot 4.7 shader APIs and validate version-sensitive built-ins against the engine when uncertain.

## Core rules

- Choose the correct shader type: normally `spatial` for 3D or `canvas_item` for UI/2D.
- Use `source_color` for color uniforms that represent authored sRGB colors.
- Use `hint_screen_texture`, `hint_depth_texture`, and current Godot 4 hints instead of removed Godot 3 built-ins such as `SCREEN_TEXTURE`.
- Keep reusable shader source in external `.gdshader` resources rather than embedding large shader strings in gameplay scripts.
- Expose only useful tunables; prefer named parameters over hard-coded visual constants.

## Materials and batching

- Share materials when behavior is shared.
- Prefer instance shader parameters / instance uniforms for per-instance visual variation when supported instead of duplicating an otherwise identical `ShaderMaterial`.
- Do not duplicate materials casually for a color/highlight change; check draw-call/batching impact.
- `MeshInstance3D.material_overlay` is reserved by project policy for interactive feedback/highlights.
- Preserve authored material/resource paths unless the task explicitly migrates them.

## Performance

Treat shader optimization as measured rendering work:

- expensive transparency/overdraw, screen reads, multiple texture samples, large fullscreen passes, `discard`, and complex per-pixel math can dominate before GDScript does;
- avoid adding branches/samples merely for theoretical quality;
- prefer shared/static calculations or vertex-stage work when visually equivalent;
- verify the real GPU/draw-call bottleneck before simplifying a shader.

Do not claim a shader is "cheap" based only on source length.

## Runtime parameters

- Cache stable ShaderMaterial references instead of repeatedly traversing scene paths.
- Use `set_shader_parameter()` / instance shader parameter APIs from the owning presentation layer.
- Avoid turning ShaderMaterial parameter state into authoritative gameplay state.

## Validation

When Godot AI MCP exposes shader validation, prefer the engine's shader parser/compiler feedback over visual guesswork. For shader changes:
1. validate syntax/compile diagnostics;
2. inspect only the relevant material/node state;
3. run a visual check only when explicitly requested or when correctness cannot be established without rendering;
4. measure performance on a representative scene before accepting a performance-specific change.

Source inspiration: adapted selectively from `gamedev-skills/awesome-gamedev-agent-skills` Godot shader guidance (Apache-2.0); project rules override generic guidance.
