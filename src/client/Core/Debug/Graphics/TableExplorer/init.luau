local DebugGui = require("@core/Debug/DebugGui")
local Log = require("@core/Log")
local TableExplorerClass = require("@core/Debug/Graphics/TableExplorer/TableExplorer")
local TableExplorer

if _G.DEV then
	TableExplorer = TableExplorerClass.new()
	TableExplorer.backFrame.Size = UDim2.fromScale(1, 1)
	TableExplorer.backFrame.Name = "TableExplorer"
	TableExplorer.backFrame.Parent = DebugGui

	local UserInputService = game:GetService("UserInputService")

	Log.info(`To Show/Hide press F2; To Freeze/UnFreeze press F3; To Re-Center press F4`)

	UserInputService.InputEnded:Connect(function(InputObject)
		if InputObject.KeyCode == Enum.KeyCode.F2 then
			local NextState = not TableExplorer.backFrame.Visible
			Log.info(`Table explorer {NextState and "shown" or "hidden"}`)
			TableExplorer.backFrame.Visible = NextState
		elseif InputObject.KeyCode == Enum.KeyCode.F3 then
			local NextState = not TableExplorer.interactionEnabled
			Log.info(`Table explorer {NextState and "unfrozen" or "frozen"}`)
			TableExplorer.interactionEnabled = NextState
		elseif InputObject.KeyCode == Enum.KeyCode.F4 then
			Log.info(`Table explorer recentered`)
			for Root, _ in TableExplorer._tableRoots do
				Root.backFrame.Position = UDim2.fromScale(0, 0)
			end
			TableExplorer.basisFrame.Position = UDim2.fromScale(0.5, 0.5)
		end
	end)
end

local Wrapper = {}

function Wrapper.AddTable(Name: string, Table: { [any]: any })
	if not _G.DEV then
		return
	end

	TableExplorer:addTable(Name, Table)
end

function Wrapper.RemoveTable(Table: { [any]: any })
	if not _G.DEV then
		return
	end

	TableExplorer:removeTable(Table)
end

function Wrapper.AddPath(Name: string, Path: { any })
	if not _G.DEV then
		return
	end

	TableExplorer:addPath(Name, Path)
end

function Wrapper.SetVisible(Visible: boolean)
	if not _G.DEV then
		return
	end

	TableExplorer.backFrame.Visible = Visible
end

return Wrapper
