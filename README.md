# implot3d-luau

Immediate-mode 3D plotting (ImPlot3D) for imgui-luau (Roblox / LÖVE).

Luau port of [ImPlot3D](https://github.com/brenocq/implot3d) for [imgui-luau](https://git.bug.tools/bug/imgui-luau) ([GitHub](https://github.com/4DBug/imgui-luau)).
Mirrors: [git.bug.tools](https://git.bug.tools/bug/implot3d-luau) / [GitHub](https://github.com/4DBug/implot3d-luau).

**Status:** full port of the ImPlot3D v0.5 WIP API: line/scatter/triangle/quad/surface/mesh/image/text/dummy items,
Log10/SymLog/custom scales, axis constraints, box rotation/scale, legends, styles, colormaps, built-in meshes,
metrics window, plus the full upstream demo (`ImPlot3DDemo.lua`, including the style editor and about window).

## Usage

```lua
local G = require(ReplicatedStorage.ImGui)
local ImPlot3D = require(ReplicatedStorage.ImPlot3D)(G)
require(ReplicatedStorage.ImPlot3DDemo)(G, ImPlot3D) -- optional: ShowDemoWindow, ShowAllDemos, ShowStyleEditor, ShowAboutWindow
local ImGui = G.ImGui

ImGui.CreateContext()
ImPlot3D.CreateContext()

-- each frame, between ImGui.NewFrame() and ImGui.Render():
ImGui.Begin("My Window")
if ImPlot3D.BeginPlot("My Plot") then
	ImPlot3D.SetupAxes("x", "y", "z")
	ImPlot3D.PlotLine("helix", Xs, Ys, Zs)                     -- count defaults to #Xs
	ImPlot3D.PlotSurface("wave", Xs2, Ys2, Zs2, N, N)           -- N*N grid, row-major
	local m = ImPlot3D.Meshes.Duck
	ImPlot3D.PlotMesh("duck", m.VtxXs, m.VtxYs, m.VtxZs, m.Idx, { FillColor = G.ImVec4(1, 0.8, 0.1, 1) })
	ImPlot3D.EndPlot()
end
ImGui.End()
ImPlot3D.ShowDemoWindow(true)
```

Full LocalScript: `examples/roblox/main.client.luau` (ImPlot3D demo window).

## API differences from C++

- **Specs are tables.** Pass `nil`, a plain table of fields (`{ LineColor = ..., Marker = ImPlot3D.ImPlot3DMarker.Circle, Flags = ... }`)
  or `ImPlot3D.ImPlot3DSpec(ImPlot3DProp.X, value, ...)` (the C++ `{Prop, value, ...}` initializer). Colors accept `ImVec4` or `ImU32`;
  per-index arrays (`LineColors`, `FillColors`, `MarkerSizes`, ...) are 1-based Luau tables.
- **Arrays are 1-based Luau tables.** `count` defaults to `#xs`. `Offset` and `Stride` are counted in **elements**, not bytes;
  `Offset` stays 0-based (ring-buffer index) like C++.
- **Mesh indices stay 0-based.** `PlotMesh(label, xs, ys, zs, idx[, vtx_count, idx_count, spec])` takes a 1-based array *holding*
  0-based vertex indices (`idx[1] == 0` is the first vertex), so upstream index data works unchanged. `ImPlot3D.Meshes.{Cube,Sphere,Duck}`
  provide `VtxXs/VtxYs/VtxZs/Idx/VtxCount/IdxCount`.
- **Pointer args become return values.** `p_open = ImPlot3D.ShowDemoWindow(p_open)` (same for `ShowMetricsWindow`, `ShowAboutWindow`);
  `t, changed = ImPlot3D.ColormapSlider(label, t, out_vec4, fmt, cmap)`; internal out-params (e.g. `GetAxesParameters`) return multiple values.
- **Overloads are dispatched at runtime** on argument types: `PlotImage` (center+axes vs 4 corners), `SetupAxisTicks` (values vs range),
  `SetupAxisScale(idx, ImPlot3DScale)` vs `SetupAxisScale(idx, forward, inverse, data)`, `SetupBoxRotation` (angles vs quaternion), ...
- **Formatters/transforms are functions**: `formatter(value, data) -> string`, `transform(value, data) -> number`;
  `SetupAxisFormat(idx, "%.2f")` takes a printf format directly.
- Enums are tables (`ImPlot3D.ImAxis3D.X`, `ImPlot3D.ImPlot3DFlags.NoClip`, ...); style `Colors` is keyed by the 0-based `ImPlot3DCol` values.
- `ImPlot3D.internal` exposes the internal API (`implot3d_internal.h`).
- Port-specific deviations are tagged `[Port]` in the source.

## TODO

- No LÖVE example yet (only `examples/roblox`).
- Upstream TODOs carried over as-is.

## Development

```sh
git clone --recursive https://git.bug.tools/bug/implot3d-luau.git
bash tools/test.sh   # tests/t_*.luau + the Roblox example in the core's Roblox mock
```

Upstream source (pinned) is in `tools/upstream/`; port-specific comments are tagged `[Port]`.

## License

MIT, see LICENSE (upstream copyright kept).
