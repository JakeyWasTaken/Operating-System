--[[

    LibStdio / stdio

    Raw stdout/stderr writers

]]

return {
	Name = "stdio",
	Enabled = true,
	MakeLibrary = function(LibraryPID: number)
		local function Concat(Values: { any }): string?
			local Data = nil
			for _, Value in Values do
				local StrValue = tostring(Value)
				if not StrValue then
					continue
				end

				Data = Data or ""
				Data ..= StrValue
			end

			return Data
		end

		return {
			StdOut = function(...: any): (boolean?, string)
				if not shared.ProcessFactory then
					return nil, "ProcessFactory was not ready"
				end

				local Process = shared.ProcessFactory.GetProcess(LibraryPID)
				if not Process then
					return nil, `PID {LibraryPID} did not have a process attributed`
				end

				local Data = Concat({ ... })
				if Data then
					Process.StdOut:Write(Data)
				end

				print(...)

				return true, ""
			end,

			StdError = function(...: any): (boolean?, string)
				if not shared.ProcessFactory then
					return nil, "ProcessFactory was not ready"
				end

				local Process = shared.ProcessFactory.GetProcess(LibraryPID)
				if not Process then
					return nil, `PID {LibraryPID} did not have a process attributed`
				end

				local Data = Concat({ ... })
				if Data then
					Process.StdErr:Write(Data)
				end

				warn(...)

				return true, ""
			end,
		}
	end,
}
