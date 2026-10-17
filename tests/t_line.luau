-- PlotLine/PlotScatter of 500 points add vertices; auto-fit limits match data; clicking a legend entry hides the item
local RS = game:GetService("ReplicatedStorage")
local G = require(RS:WaitForChild("ImGui"))
local ImPlot3D = require(RS:WaitForChild("ImPlot3D"))(G)
local ImGui, ImVec2 = G.ImGui, G.ImVec2
ImGui.CreateContext()
ImGui.GetIO().Fonts:AddFontDefault()
G.ImGui_ImplRoblox.Init()
ImPlot3D.CreateContext()
local io = ImGui.GetIO()
local internal, IG = ImPlot3D.internal, ImPlot3D.internal.ItemGroup

local N = 500
local xs, ys, zs = {}, {}, {}
for i = 1, N do
    local t = (i - 1) / (N - 1)
    xs[i], ys[i], zs[i] = math.cos(t * 20) * t * 3, math.sin(t * 20) * t * 2, t * 5 - 1
end
local function minmax(a) local lo, hi = math.huge, -math.huge for _, v in a do lo = math.min(lo, v) hi = math.max(hi, v) end return lo, hi end
local spec = ImPlot3D.ImPlot3DSpec(ImPlot3D.ImPlot3DProp.Marker, ImPlot3D.ImPlot3DMarker.Square)

local f, done, entry, hidden_at = 0, false, nil, nil
local vtx_line, vtx_scatter
game:GetService("RunService").Stepped:Connect(function()
    if done then return end
    f += 1
    G.ImGui_ImplRoblox.NewFrame()
    if entry then
        if f == 10 then io:AddMousePosEvent(entry.x, entry.y) end
        if f == 11 then io:AddMouseButtonEvent(0, true) end
        if f == 12 then io:AddMouseButtonEvent(0, false) end
    end
    ImGui.NewFrame()
    ImGui.SetNextWindowPos(ImVec2(0, 0))
    ImGui.SetNextWindowSize(ImVec2(600, 600))
    ImGui.Begin("Plot window")
    local wdl = ImGui.GetWindowDrawList()
    assert(ImPlot3D.BeginPlot("Lines", ImVec2(-1, 500)), "BeginPlot")
    local plot = internal.GetCurrentPlot()
    local dl3 = plot.DrawList
    local v0 = dl3.VtxBuffer.Size
    ImPlot3D.PlotLine("Line", xs, ys, zs, N)
    local v1 = dl3.VtxBuffer.Size
    ImPlot3D.PlotScatter("Scatter", xs, ys, zs, spec)
    local v2 = dl3.VtxBuffer.Size
    assert(dl3.ZSize * 3 == dl3.IdxSize, "one depth per triangle")
    local before = wdl.VtxBuffer.Size
    ImPlot3D.EndPlot()
    assert(wdl.VtxBuffer.Size >= before + v2, "vertices moved to window draw list")
    assert(dl3.VtxBuffer.Size == 0, "3D draw list reset")
    local line = IG.GetItem(plot.Items, "Line")
    if f == 5 then
        vtx_line, vtx_scatter = v1 - v0, v2 - v1
        assert(vtx_line >= (N - 1) * 4, "PlotLine adds vertices: " .. vtx_line)
        assert(vtx_scatter >= N * 4, "PlotScatter adds vertices: " .. vtx_scatter)
        for i, a in { xs, ys, zs } do
            local lo, hi = minmax(a)
            local r = plot.Axes[i - 1].Range
            assert(math.abs(r.Min - lo) < 1e-9 and math.abs(r.Max - hi) < 1e-9, ("auto-fit axis %d: [%g, %g] vs [%g, %g]"):format(i - 1, r.Min, r.Max, lo, hi))
        end
        assert(IG.GetLegendCount(plot.Items) == 2, "two legend entries")
        local legend = plot.Items.Legend
        local h = ImGui.GetTextLineHeight()
        local pad = ImPlot3D.GetStyle().LegendInnerPadding
        entry = ImVec2(legend.Rect.Min.x + pad.x + h * 0.5, legend.Rect.Min.y + pad.y + h * 0.5) -- first entry icon
        assert(line.Show, "visible before click")
    end
    if f > 13 and not hidden_at then
        assert(not line.Show, "clicking legend entry hides item")
        assert(v1 == v0, "hidden line adds no vertices")
        assert(IG.GetItem(plot.Items, "Scatter").Show, "other item still shown")
        hidden_at = f
    end
    ImGui.End()
    ImGui.Render(); G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if f == 20 then assert(hidden_at, "hidden"); done = true; print("OK") end
end)
