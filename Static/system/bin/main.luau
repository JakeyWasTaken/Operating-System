local encoding = require("@osiris/encoding")
local fs = require("@osiris/fs")
local process = require("@osiris/process")

local SERVICES_DIRECTORY = "/system/services"
local RESTART_WINDOW = 10
local RESTART_LIMIT = 5

local function ResolveExec(Exec: string): string
	if Exec:sub(1, 1) == "/" then
		return Exec
	end

	return `{SERVICES_DIRECTORY}/{(Exec:gsub("^%./", ""))}`
end

local function LoadService(FileName: string)
	local Handle, OpenError = fs.Open(`{SERVICES_DIRECTORY}/{FileName}`)
	if not Handle then
		return nil, OpenError
	end

	local Contents = fs.Read(Handle)
	fs.Close(Handle)

	local Data, ParseError = encoding.ParseTOML(Contents)
	if not Data then
		return nil, ParseError
	end

	if typeof(Data.Process) ~= "table" or typeof(Data.Process.Exec) ~= "string" then
		return nil, "missing [Process] Exec"
	end

	return {
		Name = (typeof(Data.Service) == "table" and Data.Service.Name) or FileName,
		Exec = ResolveExec(Data.Process.Exec),
		Arguments = Data.Process.Arguments or {},
		Environment = Data.Process.Environment or {},
		Delay = Data.Process.Delay or 0,
		AutoRestart = Data.Process.AutoRestart == true,
	}
end

local function Supervise(Service)
	task.spawn(function()
		local Restarts = {}

		while true do
			local Handle, SpawnError = process.Spawn(Service.Exec, Service.Environment, Service.Arguments, {
				Elevated = true,
				FileContext = { WorkingDirectory = SERVICES_DIRECTORY, HomeDirectory = "/" },
			})

			if not Handle then
				warn(`failed to start {Service.Name}: {SpawnError}`)
				return
			end

			print(`started {Service.Name} (PID {Handle.PID})`)
			Handle.Status()

			if not Service.AutoRestart then
				return
			end

			-- Give up on a service that keeps dying inside the restart window
			local Now = os.clock()
			table.insert(Restarts, Now)
			while Restarts[1] and Now - Restarts[1] > RESTART_WINDOW do
				table.remove(Restarts, 1)
			end

			if #Restarts > RESTART_LIMIT then
				warn(`{Service.Name} keeps crashing, giving up`)
				return
			end

			if Service.Delay > 0 then
				task.wait(Service.Delay)
			end
		end
	end)
end

local Entries, ListError = fs.List(SERVICES_DIRECTORY)
if not Entries then
	warn(`{ListError}`)
	return
end

for _, Entry in Entries do
	if Entry.IsDirectory or not Entry.Name:match("%.service$") then
		continue
	end

	local Service, LoadError = LoadService(Entry.Name)
	if Service then
		Supervise(Service)
	else
		warn(`skipping {Entry.Name}: {LoadError}`)
	end
end

while true do
	task.wait(60)
end
