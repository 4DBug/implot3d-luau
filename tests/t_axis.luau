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
local ctx = ImPlot3D.CreateContext()
local plot = ctx.Plots:GetOrAddByKey(123)
assert(ctx.Plots:GetByKey(123) == plot and plot.Axes[0].Range.Max == 1)
plot:ExtendFit(ImPlot3D.ImPlot3DPoint(1, 2, 3))
assert(plot.Axes[2].FitExtents.Max == 3)

print("OK")
