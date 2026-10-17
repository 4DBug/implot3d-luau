local RS = game:GetService("ReplicatedStorage")
local G = require(RS:WaitForChild("ImGui"))
local ImPlot3D = require(RS:WaitForChild("ImPlot3D"))(G)
local ImGui, ImVec2, ImVec4 = G.ImGui, G.ImVec2, G.ImVec4
local P, Q = ImPlot3D.ImPlot3DPoint, ImPlot3D.ImPlot3DQuat

local function near(a, b) return math.abs(a - b) < 1e-9 end
local function pnear(p, x, y, z) return near(p.x, x) and near(p.y, y) and near(p.z, z) end
local function qnear(a, b) return near(a.x, b.x) and near(a.y, b.y) and near(a.z, b.z) and near(a.w, b.w) end

-- Point ops
local a = P(1, 2, 3)
assert(a + P(1, 1, 1) == P(2, 3, 4) and 2 * a == a * 2 and -a == P(-1, -2, -3) and a[2] == 3)
assert(P(1, 0, 0):Cross(P(0, 1, 0)) == P(0, 0, 1) and a:Dot(a) == 14)

-- Rotate X by 90 deg around Z gives Y
local rz = Q(math.pi / 2, P(0, 0, 1))
assert(pnear(rz * P(1, 0, 0), 0, 1, 0), "rotation")
assert(pnear(rz:Inverse() * (rz * a), 1, 2, 3) and pnear(rz:Conjugate() * P(0, 1, 0), 1, 0, 0))
local ft = Q.FromTwoVectors(P(1, 0, 0), P(0, 1, 0))
assert(qnear(ft, rz), "FromTwoVectors")
assert(pnear(Q.FromTwoVectors(P(1, 0, 0), P(-1, 0, 0)) * P(1, 0, 0), -1, 0, 0), "opposite")
assert(near(Q(1, 2, 3, 4):Normalize():Length(), 1))
assert(near(Q.FromElAz(0.3, 0.7):Length(), 1))

-- Slerp endpoints / midpoint
local q0, q1 = Q(), rz
assert(qnear(Q.Slerp(q0, q1, 0), q0) and qnear(Q.Slerp(q0, q1, 1), q1), "slerp endpoints")
assert(qnear(Q.Slerp(q0, q1, 0.5), Q(math.pi / 4, P(0, 0, 1))), "slerp mid")

-- Box clip
local box = ImPlot3D.ImPlot3DBox(P(0, 0, 0), P(1, 1, 1))
local c0, c1, ok = box:ClipLineSegment(P(-1, 0.5, 0.5), P(2, 0.5, 0.5))
assert(ok and pnear(c0, 0, 0.5, 0.5) and pnear(c1, 1, 0.5, 0.5))
assert(select(3, box:ClipLineSegment(P(-1, 2, 0), P(2, 2, 0))) == false)

-- Context + style push/pop
ImGui.CreateContext()
local ctx = ImPlot3D.CreateContext()
assert(ImPlot3D.GetCurrentContext() == ctx)
local Col, Var = ImPlot3D.ImPlot3DCol, ImPlot3D.ImPlot3DStyleVar
local style = ImPlot3D.GetStyle()
assert(style.MarkerSize == 4 and style.PlotDefaultSize.x == 400 and style.Colors[Col.PlotBg].w == -1)
ImPlot3D.PushStyleColor(Col.PlotBg, ImVec4(1, 0, 0, 1))
ImPlot3D.PushStyleVar(Var.MarkerSize, 9)
ImPlot3D.PushStyleVar(Var.PlotPadding, ImVec2(3, 4))
assert(ImPlot3D.GetStyleColorVec4(Col.PlotBg).x == 1 and style.MarkerSize == 9 and style.PlotPadding.y == 4)
ImPlot3D.PopStyleVar(2)
ImPlot3D.PopStyleColor()
assert(style.MarkerSize == 4 and style.PlotPadding.x == 10 and style.Colors[Col.PlotBg].w == -1)
ImPlot3D.StyleColorsDark()
assert(style.Colors[Col.PlotBg].w == 0.5)

-- Colormaps
local Cm = ImPlot3D.ImPlot3DColormap
assert(ImPlot3D.GetColormapCount() == 16 and ImPlot3D.GetColormapName(Cm.Jet) == "Jet" and ImPlot3D.GetColormapIndex("Greys") == Cm.Greys)
assert(ImPlot3D.GetColormapSize() == 10)
local c = ImPlot3D.GetColormapColor(10) -- wraps to Deep[0] = 0xFFB0724C
assert(math.abs(c.x - 76 / 255) < 1e-6 and math.abs(c.z - 176 / 255) < 1e-6)
ImPlot3D.PushColormap("Greys")
local s0, s1 = ImPlot3D.SampleColormap(0), ImPlot3D.SampleColormap(1)
assert(s0.x == 1 and s1.x == 0 and ImPlot3D.GetColormapSize() == 2)
ImPlot3D.PopColormap()
assert(style.Colormap == Cm.Deep)
local mine = ImPlot3D.AddColormap("Mine", { ImVec4(1, 0, 0, 1), ImVec4(0, 0, 1, 1) }, nil, false)
assert(mine == 16 and ImPlot3D.SampleColormap(1, mine).z == 1)

ImPlot3D.DestroyContext()
assert(ImPlot3D.GetCurrentContext() == nil)
print("OK")
