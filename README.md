# implot3d-luau

Immediate-mode 3D plotting (ImPlot3D) for imgui-luau (Roblox / LÖVE).

Luau port of [ImPlot3D](https://github.com/brenocq/implot3d) for [imgui-luau](https://git.bug.tools/bug/imgui-luau) ([GitHub](https://github.com/4DBug/imgui-luau)).
Mirrors: [git.bug.tools](https://git.bug.tools/bug/implot3d-luau) / [GitHub](https://github.com/4DBug/implot3d-luau).

**Status: work in progress.**

```lua
local G = require(ReplicatedStorage.ImGui)
local ImPlot3D = require(ReplicatedStorage.ImPlot3D)(G)
```

## Development

```sh
git clone --recursive https://git.bug.tools/bug/implot3d-luau.git
bash tools/test.sh   # tests/t_*.luau in the core's Roblox mock
```

Upstream source (pinned) is in `tools/upstream/`; port-specific comments are tagged `[Port]`.

## License

MIT, see LICENSE (upstream copyright kept).
