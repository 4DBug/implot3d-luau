-- Opens every demo section (+ style editor tabs, metrics, about) for 60 frames; every demo plot must begin
local RS = game:GetService("ReplicatedStorage")
local G = require(RS:WaitForChild("ImGui"))
local ImPlot3D = require(RS:WaitForChild("ImPlot3D"))(G)
require(RS:WaitForChild("ImPlot3DDemo"))(G, ImPlot3D)
local ImGui = G.ImGui

ImGui.CreateContext()
G.ImGui_ImplRoblox.Init()
G.ImGui_ImplRoblox.SetRenderRate(0)
ImPlot3D.CreateContext()
local io = ImGui.GetIO()

-- force every DemoHeader / metrics tree open, and select one tab per phase
local TreeNodeEx, TreeNode, BeginTabItem = ImGui.TreeNodeEx, ImGui.TreeNode, ImGui.BeginTabItem
ImGui.TreeNodeEx = function(label, ...)
    ImGui.SetNextItemOpen(true)
    return TreeNodeEx(label, ...)
end
ImGui.TreeNode = function(label, ...)
    ImGui.SetNextItemOpen(true)
    return TreeNode(label, ...)
end
local tabs = { "Plots", "Axes", "Tools", "Custom", "Config", "Help" }
local style_tabs = { "Variables", "Colors", "Colormaps" }
local phase, seen = 1, {}
ImGui.BeginTabItem = function(label, p_open, flags)
    if label == tabs[phase] or label == style_tabs[(phase - 1) % 3 + 1] then
        flags = bit32.bor(flags or 0, G.ImGuiTabItemFlags.SetSelected)
    end
    local r = BeginTabItem(label, p_open, flags)
    if r then seen[label] = true end
    return r
end

local BeginPlot, plotted = ImPlot3D.BeginPlot, {}
ImPlot3D.BeginPlot = function(title, ...)
    local r = BeginPlot(title, ...)
    if r then plotted[title] = true end
    return r
end

local frame, done = 0, false
game:GetService("RunService").Stepped:Connect(function()
    if done then return end
    frame += 1
    phase = math.floor((frame - 1) / 10) % #tabs + 1
    G.ImGui_ImplRoblox.NewFrame()
    io.DeltaTime = 1 / 60
    io.DisplaySize = G.ImVec2(1000, 30000)
    ImGui.NewFrame()
    -- tall window so every open demo is visible (clipped plots return false from BeginPlot)
    if frame > 1 then ImGui.SetWindowSize("ImPlot3D Demo", G.ImVec2(900, 30000)) end
    assert(ImPlot3D.ShowDemoWindow(true) == true)
    ImGui.Begin("Style Editor (ImPlot3D)")
    ImPlot3D.ShowStyleEditor()
    ImGui.End()
    assert(ImPlot3D.ShowMetricsWindow(true) == true)
    assert(ImPlot3D.ShowAboutWindow(true) == true)
    ImGui.Render()
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if frame == 60 then
        done = true
        for _, t in tabs do assert(seen[t], "tab never opened: " .. t) end
        for _, t in style_tabs do assert(seen[t], "style editor tab never opened: " .. t) end
        for _, p in { "Line Plots", "Scatter Plots", "Triangle Plots", "Quad Plots", "Surface Plots", "Mesh Plots", "Scrolling Plot",
            "Image Plot", "Plot Flags Demo", "##strideoffset", "Legend Options Demo", "##MarkerStyles", "##NaNValues", "Colorful Lines",
            "Colorful Scatter", "Colorful Triangles", "Colorful Quads", "Gouraud Duck", "##BoxScale", "##BoxRotation", "Log Plot 3D",
            "SymLog Plot", "##Ticks", "##AxisConstraints", "##EqualAxes", "##AutoFitting", "Mouse Picking", "Seaborn Style",
            "##CustomRend", "##CustomOverlay", "##PerPointStyle", "Preview" } do
            assert(plotted[p], "plot never began: " .. p)
        end
        ImPlot3D.DestroyContext()
        print("OK")
    end
end)
