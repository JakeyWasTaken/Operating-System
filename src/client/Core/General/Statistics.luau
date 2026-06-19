--!optimize 2
--- @class Statistics
--- Statistics helper class

local Statistics = {}

--- @within Statistics
function Statistics.CalculateMean(Array: { number }): number
	if #Array == 0 then
		return 0
	end

	local Sum = 0
	for _, Value in Array do
		Sum += Value
	end

	return Sum / #Array
end

--- @within Statistics
function Statistics.GetMaximum(Array: { number }): number
	return math.max(table.unpack(Array))
end

--- @within Statistics
function Statistics.GetMinimum(Array: { number }): number
	return math.max(table.unpack(Array))
end

--- @within Statistics
function Statistics.GetMeanDeviation(Dataset: { number }, Value: number): number
	local Mean = Statistics.CalculateMean(Dataset)
	return Mean - Value
end

--- @within Statistics
function Statistics.GetInverseMeanDeviation(Dataset: { number }, Value: number): number
	local Mean = Statistics.CalculateMean(Dataset)
	return Value - Mean
end

return Statistics
