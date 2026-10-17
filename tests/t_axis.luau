local RS = game:GetService("ReplicatedStorage")
local G = require(RS:WaitForChild("ImGui"))
local ImPlot3D = require(RS:WaitForChild("ImPlot3D"))(G)
local I = ImPlot3D.internal
local ImGui = G.ImGui
-- no font/frame in headless test: stub text measurement
ImGui.CalcTextSize = function(s) return G.ImVec2(#s * 7, 13) end

local function near(a, b) return math.abs(a - b) < 1e-9 end

-- Ticker for 0..10
local t = I.ImPlot3DTicker()
I.Locator_Default(t, ImPlot3D.ImPlot3DRange(0, 10), 400, I.Formatter_Default, "%g")
assert(t:TickCount() > 2, "ticks")
local majors = 0
for _, tk in t.Ticks do
    assert(tk.PlotPos >= 0 and tk.PlotPos <= 10)
    if tk.Major then majors += 1 end
end
assert(majors >= 2 and t:GetText(0) == "0", "major ticks/label")
t:Reset()
assert(t:TickCount() == 0)
t:AddTick(1, true, true, "one")
assert(t:GetText(0) == "one")

-- Axis fit
local ax = I.ImPlot3DAxis()
ax:ExtendFit(-3); ax:ExtendFit(7); ax:ExtendFit(0 / 0); ax:ExtendFit(math.huge)
ax:ApplyFit()
assert(ax.Range.Min == -3 and ax.Range.Max == 7, "ApplyFit")
assert(ax.FitExtents.Min == math.huge)
ax:ExtendFit(2); ax:ApplyFit()
assert(ax.Range.Min == 1.5 and ax.Range.Max == 2.5, "degenerate fit")
ax.Flags = ImPlot3D.ImPlot3DAxisFlags.LockMin
ax:ExtendFit(0); ax:ExtendFit(10); ax:ApplyFit()
assert(ax.Range.Min == 1.5 and ax.Range.Max == 10, "locked min")
assert(not ax:SetMin(0) and ax:SetMax(20) and ax.Range.Max == 20)
ax:SetRange(5, -5)
assert(ax.Range.Min == -5 and ax.Range.Max == 5)
assert(near(ax:NDCToPlot(ax:PlotToNDC(3.3)), 3.3))

-- Plot + context pool
ImGui.CreateContext()
local ctx = ImPlot3D.CreateContext()
local plot = ctx.Plots:GetOrAddByKey(123)
assert(ctx.Plots:GetByKey(123) == plot and plot.Axes[0].Range.Max == 1)
plot:ExtendFit(ImPlot3D.ImPlot3DPoint(1, 2, 3))
assert(plot.Axes[2].FitExtents.Max == 3)

-- Setup API + NDC round trip
ctx.CurrentPlot = plot
ctx.CurrentItems = plot.Items
plot.FrameRect = G.ImRect(0, 0, 400, 300)
ImPlot3D.SetupAxes("x", "y##hidden", "##z")
assert(plot.Axes[1]:GetLabel() == "y##hidden" and not plot.Axes[2]:HasLabel())
ImPlot3D.SetupAxesLimits(0, 10, -1, 1, 100, 200)
assert(plot.Axes[0].Range.Max == 10 and not plot.FitThisFrame)
ImPlot3D.SetupAxisFormat(0, "%.1f")
ImPlot3D.SetupAxisTicks(1, -1, 1, 3, nil, true)
assert(plot.Axes[1].Ticker:TickCount() == 3)
ImPlot3D.SetupBoxScale(1, 2, 1)
ImPlot3D.SetupBoxRotation(30, 45)
ImPlot3D.SetupBoxInitialRotation(10, 20)
ImPlot3D.SetupLegend(ImPlot3D.ImPlot3DLocation.South)
assert(plot.Items.Legend.Location == ImPlot3D.ImPlot3DLocation.South)
plot.Axes[2].Flags = ImPlot3D.ImPlot3DAxisFlags.Invert
-- headless: stub SetupLock's drawing (rendering is covered by t_plot)
ImGui.GetWindowDrawList = function() return setmetatable({}, { __index = function() return function() end end }) end
ImGui.PushClipRect = function() end
I.RenderPlotBox = function() end
ImPlot3D.SetupLock()
assert(plot.SetupLocked and plot.Axes[0].Ticker:TickCount() > 0 and plot.Axes[0].Ticker:GetText(0) == "0.0")
local p = ImPlot3D.ImPlot3DPoint(2.5, 0.3, 175)
local ndc = ImPlot3D.PlotToNDC(p)
assert(near(ndc.x, -0.25) and near(ndc.y, 0.3) and near(ndc.z, -0.25), "ndc")
local back = ImPlot3D.NDCToPlot(ndc)
assert(near(back.x, 2.5) and near(back.y, 0.3) and near(back.z, 175), "round trip")
local pix = ImPlot3D.PlotToPixels(2.5, 0.3, 175)
local pix2 = ImPlot3D.NDCToPixels(ndc)
assert(near(pix.x, pix2.x) and near(pix.y, pix2.y))

print("OK")
