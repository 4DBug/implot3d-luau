-- ImPlot3D demo window.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local G = require(RS:WaitForChild("ImGui"))
local ImPlot3D = require(RS:WaitForChild("ImPlot3D"))(G)
require(RS:WaitForChild("ImPlot3DDemo"))(G, ImPlot3D)
local ImGui = G.ImGui

ImGui.CreateContext()
ImPlot3D.CreateContext()
G.ImGui_ImplRoblox.Init() -- defaults to LocalPlayer.PlayerGui
RunService.RenderStepped:Connect(function()
	G.ImGui_ImplRoblox.NewFrame()
	ImGui.NewFrame()
	ImPlot3D.ShowDemoWindow()
	ImGui.Render()
	G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
end)
