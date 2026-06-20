local Context = require("@core/General/Context")
if Context.IsServer then
	error("Cannot be required from the server")
end

local Player = game:GetService("Players").LocalPlayer
local PlayerGui = Player.PlayerGui
local DebugGui = PlayerGui:FindFirstChild("DebugGui")

if _G.DEV and not DebugGui then
	DebugGui = Instance.new("ScreenGui")
	DebugGui.Name = "DebugGui"
	DebugGui.DisplayOrder = 2 ^ 20
	DebugGui.ResetOnSpawn = false
	DebugGui.IgnoreGuiInset = true
	DebugGui.Parent = PlayerGui
end

return DebugGui
