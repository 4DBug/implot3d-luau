-- BeginPlot/EndPlot inside a real window: renders vertices, box corners project inside the plot rect, auto-fit runs
local RS = game:GetService("ReplicatedStorage")
local G = require(RS:WaitForChild("ImGui"))
local ImPlot3D = require(RS:WaitForChild("ImPlot3D"))(G)
local ImGui, ImVec2 = G.ImGui, G.ImVec2
ImGui.CreateContext()
ImGui.GetIO().Fonts:AddFontDefault()
G.ImGui_ImplRoblox.Init()
ImPlot3D.CreateContext()

local f, done = 0, false
game:GetService("RunService").Stepped:Connect(function()
    if done then return end
    f += 1
    G.ImGui_ImplRoblox.NewFrame()
    ImGui.NewFrame()
    ImGui.SetNextWindowSize(ImVec2(600, 600))
    ImGui.Begin("Plot window")
    local vtx_before = ImGui.GetWindowDrawList().VtxBuffer.Size
    if ImPlot3D.BeginPlot("My Plot", ImVec2(-1, 500)) then
        ImPlot3D.SetupAxes("X label", "Y label", "Z label")
        ImPlot3D.SetupAxis(2, "Z label", ImPlot3D.ImPlot3DAxisFlags.AutoFit)
        local plot = ImPlot3D.internal.GetCurrentPlot()
        local pos, size = ImPlot3D.GetPlotRectPos(), ImPlot3D.GetPlotRectSize() -- locks setup, like plotting an item
        plot:ExtendFit(ImPlot3D.ImPlot3DPoint(-2, -3, -4)) -- what items do after SetupLock
        plot:ExtendFit(ImPlot3D.ImPlot3DPoint(2, 3, 4 + f))
        assert(size.x > 0 and size.y > 0, "plot rect size")
        assert(ImPlot3D.GetPlotDrawList() == ImGui.GetWindowDrawList())
        if f == 20 then
            for _, x in { plot.Axes[0].Range.Min, plot.Axes[0].Range.Max } do
                for _, y in { plot.Axes[1].Range.Min, plot.Axes[1].Range.Max } do
                    for _, z in { plot.Axes[2].Range.Min, plot.Axes[2].Range.Max } do
                        local p = ImPlot3D.PlotToPixels(x, y, z)
                        assert(p.x >= pos.x and p.x <= pos.x + size.x and p.y >= pos.y and p.y <= pos.y + size.y,
                            ("corner %g,%g,%g -> %g,%g outside plot rect"):format(x, y, z, p.x, p.y))
                    end
                end
            end
        end
        ImPlot3D.EndPlot()
        -- initial fit (frame 1) and AutoFit z (every frame) applied
        assert(plot.Axes[0].Range.Min == -2 and plot.Axes[0].Range.Max == 2, "x fit")
        assert(plot.Axes[2].Range.Min == -4 and plot.Axes[2].Range.Max == 4 + f, "z autofit")
    else
        error("BeginPlot returned false")
    end
    assert(ImGui.GetWindowDrawList().VtxBuffer.Size > vtx_before + 100, "plot added vertices")
    ImGui.End()
    ImGui.Render(); G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if f == 20 then done = true; print("OK") end
end)
