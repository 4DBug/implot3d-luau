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

print("OK")
