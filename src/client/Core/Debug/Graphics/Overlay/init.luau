-- --- @class grOverlay
-- --- [Find the docs here](https://jakeywastaken.github.io/CeiveImOverlay/api/ImOverlay)

local DebugGui = require("@kernel/Core/Debug/DebugGui")
local ImOverlay = require("@kernel/Core/Debug/Graphics/Overlay/ImOverlay")

local MainOverlay
if _G.DEV then
	MainOverlay = ImOverlay.new(true)
	MainOverlay.BackFrame.Name = "grOverlay"
	MainOverlay.BackFrame.Position = UDim2.fromOffset(10, 70)
	MainOverlay.BackFrame.Parent = DebugGui
end

local Wrapper = {}

function Wrapper.GetLayer(Id: string, CreateAt: UDim2)
	return MainOverlay:GetLayer(Id, CreateAt)
end

function Wrapper.SetActiveLayer(Layer: ImOverlay.Layer)
	return MainOverlay:SetActiveLayer(Layer)
end

function Wrapper.PopActiveLayer()
	return MainOverlay:PopActiveLayer()
end

function Wrapper.PushStyle(StyleDiff: ImOverlay.StyleDiff)
	return MainOverlay:PushStyle(StyleDiff)
end

function Wrapper.PopStyle()
	return MainOverlay:PopStyle()
end

function Wrapper.Begin(Text: string, BackgroundColor: Color3?, TextColor: Color3?)
	return MainOverlay:Begin(Text, BackgroundColor, TextColor)
end

function Wrapper.Text(Text: string, BackgroundColor: Color3?, TextColor: Color3?)
	return MainOverlay:Text(Text, BackgroundColor, TextColor)
end

function Wrapper.End()
	return MainOverlay:End()
end

function Wrapper.Render()
	MainOverlay:Render()
end

if _G.DEV then
	return Wrapper
else
	local NOP = function() end

	return {
		GetLayer = NOP,
		SetActiveLayer = NOP,
		PopActiveLayer = NOP,
		PushStyle = NOP,
		PopStyle = NOP,
		Begin = NOP,
		Text = NOP,
		End = NOP,
		Render = NOP,
	}
end
