local Handle = require("@core/Handle")

type Handle = Handle.Handle
type PID = number

local HandleLocks: { [PID]: { Handle } } = {}

local NodeLocks = {}

function NodeLocks.LockFile(NodeHandle: Handle, PID: PID)
	if not HandleLocks[PID] then
		HandleLocks[PID] = {}
	end

	if table.find(HandleLocks[PID], NodeHandle) then
		return
	end

	table.insert(HandleLocks[PID], NodeHandle)
end

function NodeLocks.UnlockFile(NodeHandle: Handle, PID: PID)
	if not HandleLocks[PID] then
		return
	end

	local Index = table.find(HandleLocks[PID], NodeHandle)
	if not Index then
		return
	end

	table.remove(HandleLocks[PID], Index)
end

function NodeLocks.ReleaseProgramLocks(PID: PID)
	HandleLocks[PID] = nil
end

function NodeLocks.ReleaseNodeLocks(NodeHandle: Handle)
	for _, NodeHandles in NodeLocks do
		local Index = table.find(NodeHandles, NodeHandle)
		if not Index then
			continue
		end

		table.remove(NodeHandles, Index)
	end
end

function NodeLocks.IsLocked(NodeHandle: Handle)
	for _, NodeHandles in NodeLocks do
		local Index = table.find(NodeHandles, NodeHandle)
		if not Index then
			continue
		end

		return true
	end

	return false
end

return NodeLocks
