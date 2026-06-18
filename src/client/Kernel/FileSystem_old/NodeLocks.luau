type NodeHandle = string
type PID = number

local NodeLocks: { [NodeHandle]: { PID } } = {}

-- Number of array spaces we populate arrays with when we first lock them
local PRE_POPULATE_LOCKS = 5

local LockHandler = {}

function LockHandler.LockNode(Handle: NodeHandle, PID: PID)
	if not NodeLocks[Handle] then
		NodeLocks[Handle] = table.create(PRE_POPULATE_LOCKS)
	end

	table.insert(NodeLocks[Handle], PID)
end

function LockHandler.UnlockNode(Handle: NodeHandle, PID: PID)
	if not NodeLocks[Handle] then
		return
	end

	local Index = table.find(NodeLocks[Handle], PID)
	if not Index then
		return
	end

	table.remove(NodeLocks[Handle], Index)
end

function LockHandler.GetLocks(Handle: NodeHandle): { PID }
	return NodeLocks[Handle] or {}
end

function LockHandler.IsLocked(Handle: NodeHandle): boolean
	local Locks = LockHandler.GetLocks(Handle)
	return #Locks > 0
end

return LockHandler
