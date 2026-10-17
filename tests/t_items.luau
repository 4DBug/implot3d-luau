-- PlotTriangle/PlotQuad/PlotSurface/PlotMesh/PlotImage/PlotText each add vertices over 10 frames; ImPlot3D.Meshes counts match upstream
local RS = game:GetService("ReplicatedStorage")
local G = require(RS:WaitForChild("ImGui"))
local ImPlot3D = require(RS:WaitForChild("ImPlot3D"))(G)
local ImGui, ImVec2 = G.ImGui, G.ImVec2
ImGui.CreateContext()
ImGui.GetIO().Fonts:AddFontDefault()
G.ImGui_ImplRoblox.Init()
ImPlot3D.CreateContext()
local internal = ImPlot3D.internal
local P = ImPlot3D.ImPlot3DPoint

local M = ImPlot3D.Meshes
assert(M.Cube.VtxCount == 8 and #M.Cube.VtxXs == 8 and M.Cube.IdxCount == 36 and #M.Cube.Idx == 36, "cube counts")
assert(#M.Sphere.VtxZs == 162 and #M.Sphere.Idx == 960, "sphere counts")
assert(#M.Duck.VtxYs == 254 and #M.Duck.Idx == 1428, "duck counts")
assert(M.Cube.Idx[1] == 0 and M.Cube.VtxXs[1] == -1, "0-based upstream indices")

local tx, ty, tz = { 0, 1, 0, 0, -1, 0 }, { 0, 0, 1, 0, 0, -1 }, { 0, 0, 0, 1, 1, 1 }
local qx, qy, qz = { -1, 1, 1, -1 }, { -1, -1, 1, 1 }, { 0, 0, 0, 0 }
local N = 20
local sx, sy, sz = {}, {}, {}
for j = 0, N - 1 do
    for i = 0, N - 1 do
        local x, y = i / (N - 1) * 2 - 1, j / (N - 1) * 2 - 1
        local k = i + j * N + 1
        sx[k], sy[k], sz[k] = x, y, math.sin(x * 3) * math.cos(y * 3)
    end
end
local tex = G.ImTextureRef(1234)
local lines = ImPlot3D.ImPlot3DSpec(ImPlot3D.ImPlot3DProp.LineColor, 0xFF00FF00)

local f, done = 0, false
game:GetService("RunService").Stepped:Connect(function()
    if done then return end
    f += 1
    G.ImGui_ImplRoblox.NewFrame()
    ImGui.NewFrame()
    ImGui.SetNextWindowPos(ImVec2(0, 0))
    ImGui.SetNextWindowSize(ImVec2(600, 600))
    ImGui.Begin("Plot window")
    local wdl = ImGui.GetWindowDrawList()
    assert(ImPlot3D.BeginPlot("Items", ImVec2(-1, 500)), "BeginPlot")
    local dl3 = internal.GetCurrentPlot().DrawList
    local function adds(name, fn)
        local v0 = dl3.VtxBuffer.Size
        fn()
        assert(dl3.VtxBuffer.Size > v0, name .. " adds vertices (frame " .. f .. ")")
    end
    adds("PlotTriangle", function() ImPlot3D.PlotTriangle("Tri", tx, ty, tz) end)
    adds("PlotQuad", function() ImPlot3D.PlotQuad("Quad", qx, qy, qz) end)
    adds("PlotSurface", function() ImPlot3D.PlotSurface("Surf", sx, sy, sz, N, N) end)
    local cube = M.Cube
    adds("PlotMesh", function() ImPlot3D.PlotMesh("Cube", cube.VtxXs, cube.VtxYs, cube.VtxZs, cube.Idx, cube.VtxCount, cube.IdxCount, lines) end)
    adds("PlotMesh duck", function() ImPlot3D.PlotMesh("Duck", M.Duck.VtxXs, M.Duck.VtxYs, M.Duck.VtxZs, M.Duck.Idx) end)
    adds("PlotImage", function() ImPlot3D.PlotImage("Img", tex, P(0, 0, 0), P(0.5, 0, 0), P(0, 0.5, 0)) end)
    local wv = wdl.VtxBuffer.Size
    ImPlot3D.PlotText("hello", 0, 0, 0)
    assert(wdl.VtxBuffer.Size > wv, "PlotText adds vertices")
    local before = wdl.VtxBuffer.Size
    ImPlot3D.EndPlot()
    assert(wdl.VtxBuffer.Size > before, "moved to window draw list")
    local found = false
    for i = 1, wdl.CmdBuffer.Size do
        local c = wdl.CmdBuffer.Data[i]
        if c.TexRef == tex and c.ElemCount == 6 then found = true end
    end
    assert(found, "image quad gets its own ImDrawCmd with the image texture")
    assert(wdl._CmdHeader.TexRef ~= tex, "default texture restored")
    ImGui.End()
    ImGui.Render(); G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if f == 10 then done = true; print("OK") end
end)
