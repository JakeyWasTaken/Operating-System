export type Result<T> = {
	Success: boolean,
	Reason: string,
	Value: T?,
}

local Result = {}

function Result.new<T>(Success: boolean, Reason: string, Value: T?): Result<T>
	return { Success = Success, Reason = Reason, Value = Value }
end

return Result
