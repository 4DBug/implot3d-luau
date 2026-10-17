local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local G = require(RS:WaitForChild("ImGui"))
local ImPlot3D = require(RS:WaitForChild("ImPlot3D"))(G)
local ImGui = G.ImGui

ImGui.CreateContext()
G.ImGui_ImplRoblox.Init()
RunService.RenderStepped:Connect(function()
	G.ImGui_ImplRoblox.NewFrame()
	ImGui.NewFrame()
	-- ImPlot3D example goes here
	ImGui.Render()
	G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
end)
