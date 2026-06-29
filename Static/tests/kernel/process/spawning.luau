local process = require("@osiris/process")

-- StdOut carries exactly what the spawned script printed (print appends a
-- trailing newline), and Status() blocks until termination and returns the
-- code passed to exit()
do
	local Spawned = process.Spawn("./to_spawn.luau", {}, {}, {})
	assert(Spawned.StdOut:Read() == "Hello!\n", "StdOut should carry exactly what the spawned script printed")
	assert(Spawned.Status() == 0, "Status() should return the exact exit code passed to exit()")
end

-- Each spawned process gets its own distinct PID, and each one runs and exits independently
do
	local A = process.Spawn("./to_spawn_fast.luau", {}, {}, {})
	local B = process.Spawn("./to_spawn_fast.luau", {}, {}, {})

	assert(A.PID ~= B.PID, "two spawned processes should receive distinct PIDs")
	assert(A.Status() == 0, "process A should exit with the code it passed to exit()")
	assert(B.Status() == 0, "process B should exit with the code it passed to exit()")
end

-- Status() forwards whatever exit code the script actually requested, not just truthy/falsy
do
	local Spawned = process.Spawn("./to_spawn_exit_code.luau", {}, {}, {})
	assert(Spawned.Status() == 42, "Status() should forward the exact exit code passed to exit(), not just any truthy value")
end

-- An uncaught error() in the spawned script's main thread writes to StdErr
-- (with a trailing newline appended) and the process exits with code -1
do
	local Spawned = process.Spawn("./to_spawn_stderr.luau", {}, {}, {})
	assert(Spawned.StdErr:Read() == "boom\n", "error() should write its message to the process's StdErr stream")
	assert(Spawned.Status() == -1, "an uncaught error in the main thread should result in a -1 exit code")
end

-- The spawning process tracks the spawned PID as a child while it's alive,
-- and stops tracking it once it terminates
do
	local Spawned = process.Spawn("./to_spawn_alive.luau", {}, {}, {})
	assert(
		table.find(process.GetChildPIDs(), Spawned.PID) ~= nil,
		"a freshly spawned process should immediately show up in the parent's child PID list"
	)

	Spawned.Status() -- block until it terminates

	assert(table.find(process.GetChildPIDs(), Spawned.PID) == nil, "a terminated process should be detached from its parent's child PID list")
end

-- Spawning a script at a path that doesn't exist fails instead of
-- silently returning a broken handle
do
	local Spawned, Err = process.Spawn("./does_not_exist.luau", {}, {}, {})
	assert(Spawned == nil, "spawning a nonexistent program path should fail")
	assert(Err ~= "", "a failed Spawn should report a non-empty error message")
end

-- A spawned process can itself spawn a child process and forward its exit code
do
	local Spawned = process.Spawn("./to_spawn_child.luau", {}, {}, {})
	assert(Spawned.Status() == 0, "a spawned process should be able to spawn its own children and exit normally")
end

-- Terminate forcibly kills a child, regardless of where it currently is in
-- its own execution, and detaches it from the parent's child list
do
	local Spawned = process.Spawn("./to_spawn_alive.luau", {}, {}, {})
	assert(table.find(process.GetChildPIDs(), Spawned.PID) ~= nil, "the child should be tracked right after spawning")

	process.Terminate(Spawned.PID, 9)
	assert(Spawned.Status() == 9, "Terminate should force the process to exit with the exit code it was given")
	assert(table.find(process.GetChildPIDs(), Spawned.PID) == nil, "Terminate should detach the child from the parent's child list")
end

-- Terminate refuses to act on a PID that is neither the caller nor one of its children
do
	local Ok, Err = process.Terminate(2 ^ 20, 0)
	assert(not Ok, "Terminate should fail when targeting a PID that isn't the caller or one of its children")
	assert(Err ~= "", "a failed Terminate should report a non-empty error message")
end

-- A process can target itself with Terminate
do
	local Spawned = process.Spawn("./to_terminate_self.luau", {}, {}, {})
	assert(Spawned.Status() == 55, "a process should be able to terminate itself via Terminate() with a custom exit code")
end

-- Detach unlinks a child from the parent's child list without killing it
do
	local Spawned = process.Spawn("./to_spawn_alive.luau", {}, {}, {})
	assert(table.find(process.GetChildPIDs(), Spawned.PID) ~= nil, "the child should be tracked right after spawning")

	process.Detach(Spawned.PID)
	assert(table.find(process.GetChildPIDs(), Spawned.PID) == nil, "Detach should remove the child from the parent's child list")

	-- detaching doesn't kill it, it keeps running and exits normally on its own
	assert(Spawned.Status() == 0, "a detached process should keep running independently and still report its own exit code")
end

-- Detach refuses to act on a PID that is neither the caller nor one of its children
do
	local Ok, Err = process.Detach(2 ^ 20)
	assert(not Ok, "Detach should fail when targeting a PID that isn't the caller or one of its children")
	assert(Err ~= "", "a failed Detach should report a non-empty error message")
end

-- A process can target itself with Detach harmlessly
do
	local Ok = process.Detach(process.GetPID())
	assert(Ok, "Detach should succeed when targeting the caller itself")
end

-- A process can take arguments and use them
do
	local ExitCode = 101
	local Spawned = process.Spawn("./to_spawn_arguments.luau", {}, { tostring(ExitCode) }, {})
	assert(Spawned.Status() == ExitCode, "a spawned process should be able to take arguments and use them")
end

-- A process can take environment and use them
do
	local ExitCode = 101
	local Spawned = process.Spawn("./to_spawn_environment.luau", { ExitCode = tostring(ExitCode) }, {}, {})
	assert(Spawned.Status() == ExitCode, "a spawned process should be able to take arguments and use them")
end

-- The stdio library's StdOut/StdError write exactly what's passed, unlike
-- print/warn which now append a trailing newline
do
	local Spawned = process.Spawn("./to_spawn_stdio_library.luau", {}, {}, {})
	assert(Spawned.StdOut:Read() == "raw-out", "stdio.StdOut should not append a trailing newline")
	assert(Spawned.StdErr:Read() == "raw-err", "stdio.StdError should not append a trailing newline")
	assert(Spawned.Status() == 0, "the stdio library should not affect the process's exit code")
end

return "OK"
