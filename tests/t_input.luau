-- HandleInput: right drag rotates, wheel zooms (range shrinks), left double click refits
local RS = game:GetService("ReplicatedStorage")
local G = require(RS:WaitForChild("ImGui"))
local ImPlot3D = require(RS:WaitForChild("ImPlot3D"))(G)
local ImGui, ImVec2 = G.ImGui, G.ImVec2
ImGui.CreateContext()
ImGui.GetIO().Fonts:AddFontDefault()
G.ImGui_ImplRoblox.Init()
ImPlot3D.CreateContext()
local io = ImGui.GetIO()

local f, done = 0, false
local center, rot0, sizes0, fit0
local function sizes(plot) return { plot.Axes[0].Range:Size(), plot.Axes[1].Range:Size(), plot.Axes[2].Range:Size() } end
game:GetService("RunService").Stepped:Connect(function()
    if done then return end
    f += 1
    G.ImGui_ImplRoblox.NewFrame()
    if center then
        if f == 5 then io:AddMousePosEvent(center.x, center.y) end
        if f == 6 then io:AddMouseButtonEvent(1, true) end
        if f >= 7 and f <= 10 then io:AddMousePosEvent(center.x + 5 * (f - 6), center.y + 2 * (f - 6)) end
        if f == 11 then io:AddMouseButtonEvent(1, false) end
        if f == 12 then io:AddMousePosEvent(center.x, center.y) end
        if f == 14 then io:AddMouseWheelEvent(0, 1) end
        if f == 18 or f == 20 then io:AddMouseButtonEvent(0, true) end
        if f == 19 or f == 21 then io:AddMouseButtonEvent(0, false) end
    end
    ImGui.NewFrame()
    ImGui.SetNextWindowPos(ImVec2(0, 0))
    ImGui.SetNextWindowSize(ImVec2(600, 600))
    ImGui.Begin("Plot window")
    assert(ImPlot3D.BeginPlot("Input", ImVec2(-1, 500)), "BeginPlot")
    local plot = ImPlot3D.internal.GetCurrentPlot()
    ImPlot3D.SetupLock()
    plot:ExtendFit(ImPlot3D.ImPlot3DPoint(-2, -3, -4))
    plot:ExtendFit(ImPlot3D.ImPlot3DPoint(2, 3, 4))
    center = plot.PlotRect:GetCenter()
    if f == 6 then rot0 = plot.Rotation end
    ImPlot3D.EndPlot()
    if f == 4 then fit0 = sizes(plot) end
    if f == 12 then assert(plot.Rotation:Dot(rot0) < 0.9999, "right drag rotates") end
    if f == 13 then sizes0 = sizes(plot) end
    if f == 15 then
        local s, shrunk = sizes(plot), false
        for i = 1, 3 do
            assert(s[i] <= sizes0[i] + 1e-9, "zoom grew axis " .. i)
            shrunk = shrunk or s[i] < sizes0[i] - 1e-9
        end
        assert(shrunk, "wheel zooms")
    end
    if f == 23 then
        local s = sizes(plot)
        for i = 1, 3 do assert(math.abs(s[i] - fit0[i]) < 1e-9, ("double click refits axis %d: %g vs %g"):format(i, s[i], fit0[i])) end
    end
    ImGui.End()
    ImGui.Render(); G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if f == 23 then done = true; print("OK") end
end)
