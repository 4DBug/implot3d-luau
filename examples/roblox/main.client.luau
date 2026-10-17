-- Rotating surface + ImPlot3D / ImGui demo windows.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local G = require(RS:WaitForChild("ImGui"))
local ImPlot3D = require(RS:WaitForChild("ImPlot3D"))(G)
require(RS:WaitForChild("ImPlot3DDemo"))(G, ImPlot3D)
local ImGui = G.ImGui

local N = 30
local Xs, Ys, Zs = table.create(N * N, 0), table.create(N * N, 0), table.create(N * N, 0)
for j = 0, N - 1 do
	for i = 0, N - 1 do
		Xs[j * N + i + 1], Ys[j * N + i + 1] = i / (N - 1) * 2 - 1, j / (N - 1) * 2 - 1
	end
end
local Speed, ShowImPlot3DDemo, ShowImGuiDemo = 30, true, false
local StartClock = os.clock()

local function RenderDemo()
	local Time = os.clock() - StartClock
	for k = 1, N * N do
		local x, y = Xs[k], Ys[k]
		Zs[k] = math.sin(3 * math.sqrt(x * x + y * y) - 2 * Time) * 0.5
	end

	ImGui.SetNextWindowSize(G.ImVec2(500, 500), G.ImGuiCond.FirstUseEver)
	ImGui.Begin("Rotating Surface")
	_, ShowImPlot3DDemo = ImGui.Checkbox("ImPlot3D Demo", ShowImPlot3DDemo)
	ImGui.SameLine()
	_, ShowImGuiDemo = ImGui.Checkbox("ImGui Demo", ShowImGuiDemo)
	Speed = ImGui.SliderFloat("Speed (deg/s)", Speed, -180, 180)
	if ImPlot3D.BeginPlot("##Surface", G.ImVec2(-1, -1)) then
		ImPlot3D.SetupAxesLimits(-1, 1, -1, 1, -1, 1)
		ImPlot3D.SetupBoxRotation(25, (Time * Speed) % 360 - 180, false, ImPlot3D.ImPlot3DCond.Always)
		ImPlot3D.PushColormap(ImPlot3D.ImPlot3DColormap.Viridis)
		ImPlot3D.PlotSurface("wave", Xs, Ys, Zs, N, N, { Flags = ImPlot3D.ImPlot3DSurfaceFlags.NoMarkers })
		ImPlot3D.PopColormap()
		ImPlot3D.EndPlot()
	end
	ImGui.End()

	if ShowImPlot3DDemo then
		ShowImPlot3DDemo = ImPlot3D.ShowDemoWindow(ShowImPlot3DDemo)
	end
	if ShowImGuiDemo then
		ShowImGuiDemo = ImGui.ShowDemoWindow(ShowImGuiDemo)
	end
end

ImGui.CreateContext()
ImPlot3D.CreateContext()
G.ImGui_ImplRoblox.Init() -- defaults to LocalPlayer.PlayerGui
RunService.RenderStepped:Connect(function()
	G.ImGui_ImplRoblox.NewFrame()
	ImGui.NewFrame()
	RenderDemo()
	ImGui.Render()
	G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
end)
