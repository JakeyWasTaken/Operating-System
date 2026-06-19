--!optimize 2
--- @class General
--- General helper class to contain small pure functions

local General = {}

--- @within General
--- Callback assert.
--- Returns true if the assertion failed
function General.CBASSERT(condition: boolean, callback: (...any) -> ()?, ...: any?): boolean
	if not condition then
		if callback then
			callback(...)
		end
		return true
	end
	return false
end

--- @within General
--- Warn assert.
--- Returns true if the assertion failed
function General.WASSERT(condition: boolean, ...: string): boolean
	if not condition then
		warn("(ASSERTION FAILED): ", ..., `\n{debug.traceback(nil, 2)}`)
		return true
	end
	return false
end

--- @within General
function General.AssertTableParameter(Table: { [any]: any }, TableName: string, Key: any, ValueType: string, Optional: boolean)
	local Exists = Table[Key] ~= nil

	if not Optional then
		assert(Exists, `Expected key of type '{typeof(Key)}' with value '{Key}' in {TableName}`)
	elseif not Exists then
		return
	end

	assert(
		typeof(Table[Key]) == ValueType,
		`Expected {Optional and "optional " or ""}value to be of type '{ValueType}' under key '{Key}' :: '{typeof(Key)}' in {TableName}`
	)
end

--- @within General
function General.SafeUnitV3(Vector: Vector3, Override: Vector3?): Vector3
	if Vector.Magnitude > 0 then
		return Vector.Unit
	end

	return Override or Vector3.zero
end

--- @within General
function General.SafeUnitV2(Vector: Vector2): Vector2
	if Vector.Magnitude > 0 then
		return Vector.Unit
	end

	return Vector2.zero
end

--- @within General
function General.LimitRadianAngle(Angle: number): number
	local TwoPi = math.pi * 2

	while Angle < -math.pi do
		Angle += TwoPi
	end
	while Angle > math.pi do
		Angle -= TwoPi
	end

	return Angle
end

--- @within General
function General.GetAtanOfXY(x: number, y: number): number
	if x == 0 or y == 0 then
		return 0
	end

	local xabs = math.abs(x)
	local yabs = math.abs(y)

	if xabs < yabs then
		if y > 0 then
			if x > 0 then
				return 0.5 * math.pi - math.atan2(x / y, 1)
			else
				return 0.5 * math.pi + math.atan2(-x / y, 1)
			end
		else
			if x > 0 then
				return 1.5 * math.pi + math.atan2(x / -y, 1)
			else
				return 1.5 * math.pi - math.atan2(-x / -y, 1)
			end
		end
	else
		if y > 0 then
			if x > 0 then
				return math.atan2(y / x, 1)
			else
				return math.pi - math.atan2(y / -x, 1)
			end
		else
			if x > 0 then
				return 2 * math.pi - math.atan2(-y / x, 1)
			else
				return math.pi + math.atan2(-y / -x, 1)
			end
		end
	end
end

--- @within General
function General.SignedAngleBetween(a: Vector3, b: Vector3, up: Vector3): number
	local cos = a:Dot(b)
	local sin = a:Cross(b).Magnitude
	local cross = a:Cross(b)

	local angle = math.atan2(sin, cos)

	if up:Dot(cross) < 0 then
		angle = -angle
	end

	return angle
end

--- @within General
function General.AngleBetween(a: Vector3, b: Vector3): number
	local cos = a:Dot(b)
	local sin = a:Cross(b).Magnitude
	return math.atan2(sin, cos)
end

--- @within General
function General.FormatNumbers(decimal: number, ...: number): string
	decimal = math.floor(decimal)

	local sout = ""
	for i, v in ipairs(table.pack(...)) do
		sout ..= `{i == 1 and "" or ", "}{string.format(`%.{decimal}f`, v)}`
	end
	return sout
end

--- @within General
function General.DeepCopy<K, V>(original: { [K]: V }): { [K]: V }?
	if not original then
		return nil
	end

	-- Define the new table for the copy
	local copy = {}

	-- Loop through the original table to clone
	for key, value in original do
		-- If the type of the value is a table, deep copy it to the key (index)
		-- Else (or) the type isn't a table, assign the default value to the index instead
		copy[key] = type(value) == "table" and General.DeepCopy(value) or value
	end

	-- Return the finalized copy of the deep cloned table
	return copy
end

--- @within General
--- Shallow copy
function General.CopyArrayExcludingValue<T>(Array: { T }, Value: T): { T }
	local NewArray = {}

	for _, V in Array do
		if V == Value then
			continue
		end

		table.insert(NewArray, V)
	end

	return NewArray
end

--- @within General
function General.RayPlaneIntersection(PlaneO: Vector3, PlaneN: Vector3, RayO: Vector3, RayN: Vector3): Vector3
	local d = PlaneO:Dot(-PlaneN)
	local t = -(d + RayO:Dot(PlaneN)) / RayN:Dot(PlaneN)
	return RayO + t * RayN
end

--- @within General
function General.MapValue(n: number, start: number, stop: number, newStart: number, newStop: number, Clamp: boolean)
	return Clamp
			and math.clamp(
				math.map(n, start, stop, newStart, newStop),
				(newStart < newStop and newStart or newStop),
				(newStart > newStop and newStop or newStart)
			)
		or math.map(n, start, stop, newStart, newStop)
end

--- @within General
function General.Map<K, V, Q>(Array: { [K]: V }, Func: (V) -> Q): { [K]: Q }
	local NewArray = {}

	for K, V in Array do
		NewArray[K] = Func(V)
	end

	return NewArray
end

--- @within General
function General.ArrayIfy<V, Q>(Dictionary: { [any]: V }, Func: (V) -> Q): { Q }
	local Array = {}

	for _, V in Dictionary do
		table.insert(Array, Func(V))
	end

	return Array
end

--- @within General
function General.ReflectVector(Vector: Vector3, Normal: Vector3): Vector3
	return Vector - 2 * (Vector:Dot(Normal)) * Normal
end

--- @within General
--- @return (boolean, Vector3, Vector3) -- IsInside, ClosestPoint, Normal
function General.ClosestPointOnBox(CFrame: CFrame, Size: Vector3, Point: Vector3): (boolean, Vector3, Vector3)
	local rel = CFrame:PointToObjectSpace(Point)
	local sx, sy, sz = Size.X, Size.Y, Size.Z
	local rx, ry, rz = rel.X, rel.Y, rel.Z

	-- constrain to within the box
	local cx = math.clamp(rx, -sx * 0.5, sx * 0.5)
	local cy = math.clamp(ry, -sy * 0.5, sy * 0.5)
	local cz = math.clamp(rz, -sz * 0.5, sz * 0.5)

	if not (cx == rx and cy == ry and cz == rz) then
		local closestPoint = CFrame * Vector3.new(cx, cy, cz)
		local normal = General.SafeUnitV3(Point - closestPoint)
		return false, closestPoint, normal
	end

	-- else, they are intersecting, find the surface the Point is closest to

	local posX = rx - sx * 0.5
	local posY = ry - sy * 0.5
	local posZ = rz - sz * 0.5
	local negX = -rx - sx * 0.5
	local negY = -ry - sy * 0.5
	local negZ = -rz - sz * 0.5

	local max = math.max(posX, posY, posZ, negX, negY, negZ)
	if max == posX then
		local closestPoint = CFrame * Vector3.new(sx * 0.5, ry, rz)
		return true, closestPoint, CFrame.XVector
	elseif max == posY then
		local closestPoint = CFrame * Vector3.new(rx, sy * 0.5, rz)
		return true, closestPoint, CFrame.YVector
	elseif max == posZ then
		local closestPoint = CFrame * Vector3.new(rx, ry, sz * 0.5)
		return true, closestPoint, CFrame.ZVector
	elseif max == negX then
		local closestPoint = CFrame * Vector3.new(-sx * 0.5, ry, rz)
		return true, closestPoint, -CFrame.XVector
	elseif max == negY then
		local closestPoint = CFrame * Vector3.new(rx, -sy * 0.5, rz)
		return true, closestPoint, -CFrame.YVector
	elseif max == negZ then
		local closestPoint = CFrame * Vector3.new(rx, ry, -sz * 0.5)
		return true, closestPoint, -CFrame.ZVector
	end

	return false, Vector3.zero, Vector3.zero
end

--- @within General
--- @param a0 Vector3
--- @param a1 Vector3
--- @param point Vector3
--- @param lead number -- Percentage of how far extra we should push the closest point along the line segment
function General.ClosestPointOnLineSegment(a0: Vector3, a1: Vector3, point: Vector3, lead: number)
	local Distance = (a0 - a1).Magnitude

	if Distance == 0 then
		return a0
	end

	local Direction = (a1 - a0).Unit
	local LeadDistance = (lead or 0) * Distance

	local SqrdDistance = Direction.X ^ 2 + Direction.Y ^ 2 + Direction.Z ^ 2
	local ProjectedDistance = ((point - a0):Dot(Direction) / SqrdDistance) + LeadDistance
	ProjectedDistance = math.clamp(ProjectedDistance, 0, Distance)

	return a0 + Direction * ProjectedDistance
end

--- @within General
function General.Lerp(a: number, b: number, t: number)
	return (1 - t) * a + t * b
end

--- @within General
function General.CallForIndex<T>(Array: { T }, Callback: (T, number) -> ())
	for i, Item in ipairs(Array) do
		Callback(Item, i)
	end
end

--- @within General
function General.ForEach<K, V>(Table: { [K]: V }, Callback: (V, K) -> ())
	for K, V in Table do
		Callback(V, K)
	end
end

--- @within General
function General.AppendTables<K, V>(...: { [K]: V }): { [K]: V }
	local Length = select("#", ...)
	local NewArray = {}

	for i = 1, Length do
		local Array = select(i, ...)

		for k, v in Array do
			if type(k) == "number" then
				table.insert(NewArray, v)
			else
				NewArray[k] = v
			end
		end
	end

	return NewArray :: any
end

--- @within General
function General.IterateTables<K, V>(callback: (Key: K, Value: V) -> (), ...: { [K]: V })
	local Length = select("#", ...)

	for i = 1, Length do
		local Array = select(i, ...)

		for K, V in Array do
			callback(K, V)
		end
	end
end

--- @within General
function General.SearchTable<V>(Haystack: { [any]: V }, Comparator: (V) -> boolean): number?
	for i, Value in Haystack do
		if Comparator(Value) then
			return i
		end
	end

	return nil
end

--- @within General
function General.LengthOfDictionary(Table: { [any]: any }): number
	local Length = 0

	for _ in Table do
		Length += 1
	end

	return Length
end

--- @within General
function General.PickRandomEntryInDictionary<T>(Table: { [any]: T }): T
	local Keys = {}

	for Key in Table do
		table.insert(Keys, Key)
	end

	local RandomKey = Keys[math.random(1, #Keys)]
	return Table[RandomKey]
end

--- @within General
function General.InstanceHasAttributes(Instance: Instance, ...: string): boolean
	local Length = select("#", ...)

	for i = 1, Length do
		local Attribute = select(i, ...)

		if not Instance:GetAttribute(Attribute) then
			return false
		end
	end

	return true
end

--- @within General
function General.PickRandomPositionInBasePart(BasePart: BasePart): Vector3
	local HalfSize = BasePart.Size * 0.5
	local Transform = BasePart.CFrame

	local Rand = Random.new()
	local X = Rand:NextNumber(-HalfSize.X, HalfSize.X)
	local Y = Rand:NextNumber(-HalfSize.Y, HalfSize.Y)
	local Z = Rand:NextNumber(-HalfSize.Z, HalfSize.Z)

	return Transform * Vector3.new(X, Y, Z)
end

--- @within General
function General.SetModelCanCollide(Model: Model, Value: boolean)
	for _, Descendant in Model:GetDescendants() do
		if not Descendant:IsA("BasePart") then
			continue
		end

		Descendant.CanCollide = Value
	end
end

--- @within General
function General.SetModelAnchored(Model: Model, Value: boolean)
	for _, Descendant in Model:GetDescendants() do
		if not Descendant:IsA("BasePart") then
			continue
		end

		Descendant.Anchored = Value
	end
end

--- @within General
function General.ZeroOutVelocity(Model: Model)
	for _, Descendant in Model:GetDescendants() do
		if not Descendant:IsA("BasePart") then
			continue
		end

		Descendant.AssemblyLinearVelocity = Vector3.zero
		Descendant.AssemblyAngularVelocity = Vector3.zero
	end
end

--- @within General
--- Converts the provided table to a string
function General.TableToString(Table: { [any]: any }, UseNewLines: boolean, Level: number?): string
	local level = Level or 1
	local buffer = UseNewLines and string.rep(" ", level * 4) or " "
	local bufferMinus1 = UseNewLines and string.rep(" ", (level - 1) * 4) or " "
	local currentString = "{"
	local nl = UseNewLines and "\n" or ""
	local didInsert = false
	for i, v in Table do
		didInsert = true
		currentString = currentString
			.. nl
			.. buffer
			.. "["
			.. (type(i) == "string" and ('"' .. i .. '"') or tostring(i))
			.. "] = "
			.. (
				type(v) == "string" and ('"' .. v .. '"')
				or type(v) == "table" and (General.TableToString(v, UseNewLines, level + 1))
				or (tostring(v)) .. ";"
			)
	end
	currentString = currentString .. (didInsert and (nl .. bufferMinus1) or "") .. "};"

	return currentString
end

--- @within General
function General.ReverseArray<T>(Array: { T }): { T }
	local NewArray = {}

	for i = #Array, 1, -1 do
		table.insert(NewArray, Array[i])
	end

	return NewArray
end

return General
