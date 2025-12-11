local CNode = require("@kernel/FileSystem/Node")

--[[

methods

GetHandle: (Path: string) -> string?,

Open: (Handle: string) -> FileStream,
Read: (Handle: string) -> FileContents,
Write: (Handle: string, FileContents: ...) -> (),

CreatePath: (Path: string) -> (),
CreateFile: (Path: string) -> (),

]]

local FileSystem = {}
local RootNode = CNode.new("FOLDER", nil)

function FileSystem.GetHandle(Path: string)
	local Steps = Path:split("/")

	local CurrentStep = RootNode
	local CurrentStepIndex = 1

	while CurrentStep < #Steps do
		local NextNode = CurrentStep:FindChild(Steps[CurrentStepIndex])

		if not NextNode then
			return
		end

		CurrentStep = NextNode
		CurrentStepIndex += 1
	end

	return CurrentStep.Handle
end

return FileSystem
