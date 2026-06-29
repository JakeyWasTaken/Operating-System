const Class = require("@core/Class")
const FileContext = require("@kernel/File/FileContext")
const TypeFunctions = require("@core/General/TypeFunctions")
const Log = require("@core/Log")

type Exclude<T, U> = TypeFunctions.Exclude<T, U>

type FileContext = FileContext.FileContext

type RootType = "Root" | "Home" | "Relative" | "None"

export type PathPartType = "Root" | "Home" | "Escape" | "Enter"
export type PathPart =
	| { Type: Exclude<PathPartType, "Enter"> }
	| { Type: "Enter", Name: string }

export type CFilePath = {
	new: (String: string) -> CFilePath,

	ValidateStrings: (Strings: { string }) -> boolean,

	GetString: (self: CFilePath) -> string,
	GetName: (self: CFilePath) -> string,
	GetParent: (self: CFilePath) -> CFilePath,

	--- Validates that this path **COULD** resolve to something
	IsValid: (self: CFilePath) -> boolean,

	--- Returns navigation instructions making up this path.
	GetParts: (self: CFilePath) -> { PathPart },

	Append: (self: CFilePath, String: string) -> CFilePath,
	Combine: (self: CFilePath, Other: CFilePath) -> CFilePath,

	--- Resolves this path using a file context (cwd + home).
	---
	--- Returns an absolute path.
	Resolve: (self: CFilePath, Context: FileContext) -> CFilePath,

	-- --------------------------------- Members -------------------------------- --
	m_RootType: RootType,
	m_Parts: { PathPart },
} & Class.Base

local CFilePath: CFilePath = Class("CFilePath")

local function ParseSegments(Segments: { string }): { PathPart }?
	local Parts: { PathPart } = {}

	for _, Segment in Segments do
		if #Segment == 0 then
			continue
		end

		local Start, End = Segment:find("%.+")
		if Start == 1 and End == #Segment then
			if #Segment > 1 then
				table.insert(Parts, { Type = "Escape" })
			end

			continue
		end

		if Segment:sub(#Segment, #Segment) == "." then
			Log.warn(`Failed to parse path segment "{Segment}", cannot suffix a step with "."`)
			return nil
		end

		table.insert(Parts, { Type = "Enter", Name = Segment } :: PathPart)
	end

	return Parts
end

local function FromParts(RootType: RootType, Parts: { PathPart }): CFilePath
	local self: CFilePath = setmetatable({}, CFilePath) :: any
	(CFilePath :: any)(self)

	self.m_RootType = RootType
	self.m_Parts = Parts

	return self
end

function CFilePath.new(String: string)
	local self: CFilePath = setmetatable({}, CFilePath) :: any
	(CFilePath :: any)(self)

	self.m_RootType = "None"
	self.m_Parts = {}

	if #String == 0 then
		return self
	end

	local Corrected = String:gsub("\\", "/")
	local Split = Corrected:split("/")

	if #Split == 0 then
		return self
	end

	local RemovePrefix = true

	if Split[1] == "" then
		self.m_RootType = "Root"
	elseif Split[1] == "~" then
		self.m_RootType = "Home"
	else
		local Start, End = Split[1]:find("%.+")
		if Start == 1 and End == #Split[1] then
			self.m_RootType = "Relative"
			RemovePrefix = #Split[1] == 1
		end
	end

	if self.m_RootType == "None" then
		-- No explicit prefix (e.g. "foo/bar") means relative to the working
		-- directory, exactly like "./foo/bar".
		self.m_RootType = "Relative"
		RemovePrefix = false
	end

	if RemovePrefix then
		table.remove(Split, 1)
	end

	local Parts = ParseSegments(Split)
	if not Parts then
		self.m_RootType = "None"
		return self
	end

	self.m_Parts = Parts

	return self
end

function CFilePath.ValidateStrings(Strings: { string })
	for _, String in Strings do
		if not CFilePath.new(String):IsValid() then
			return false
		end
	end

	return true
end

function CFilePath:IsValid()
	return self.m_RootType ~= "None"
end

function CFilePath:GetParts()
	if self.m_RootType == "Root" then
		return { { Type = "Root" } :: PathPart, table.unpack(self.m_Parts) }
	elseif self.m_RootType == "Home" then
		return { { Type = "Home" } :: PathPart, table.unpack(self.m_Parts) }
	end

	return self.m_Parts
end

function CFilePath:GetString()
	if not self:IsValid() then
		return ""
	end

	local Steps = {}

	if self.m_RootType == "Root" then
		table.insert(Steps, #self.m_Parts > 0 and "" or "/")
	elseif self.m_RootType == "Home" then
		table.insert(Steps, "~")
	elseif self.m_RootType == "Relative" then
		table.insert(Steps, ".")
	end

	for _, Part in self.m_Parts do
		if Part.Type == "Escape" then
			table.insert(Steps, "..")
		else
			table.insert(Steps, (Part :: any).Name)
		end
	end

	return table.concat(Steps, "/")
end

function CFilePath:GetName()
	if not self:IsValid() then
		return ""
	end

	local Last = self.m_Parts[#self.m_Parts]
	if Last == nil then
		if self.m_RootType == "Home" then
			return "~"
		elseif self.m_RootType == "Relative" then
			return "."
		end

		return ""
	end

	if Last.Type == "Escape" then
		return ".."
	end

	return (Last :: any).Name
end

function CFilePath:GetParent(): CFilePath
	if not self:IsValid() then
		return CFilePath.new("")
	end

	if self.m_RootType == "Root" and #self.m_Parts == 0 then
		return self
	end

	local Last = self.m_Parts[#self.m_Parts]

	if Last == nil then
		return CFilePath.new(`{self:GetString()}/..`)
	end

	if Last.Type == "Escape" then
		if self.m_RootType == "Root" then
			return self
		end

		return CFilePath.new(`{self:GetString()}/..`)
	end

	if self.m_RootType == "Root" and #self.m_Parts == 1 then
		return CFilePath.new("/")
	end

	local Steps = {}

	if self.m_RootType == "Root" then
		table.insert(Steps, "")
	elseif self.m_RootType == "Home" then
		table.insert(Steps, "~")
	elseif self.m_RootType == "Relative" then
		table.insert(Steps, ".")
	end

	for i = 1, #self.m_Parts - 1 do
		local Part = self.m_Parts[i]
		if Part.Type == "Escape" then
			table.insert(Steps, "..")
		else
			table.insert(Steps, (Part :: any).Name)
		end
	end

	return CFilePath.new(table.concat(Steps, "/"))
end

function CFilePath:Append(String: string): CFilePath
	local Corrected = String:gsub("\\", "/")
	local Segments = ParseSegments(Corrected:split("/"))
	if not Segments then
		return CFilePath.new("")
	end

	local Parts = table.clone(self.m_Parts)
	table.move(Segments, 1, #Segments, #Parts + 1, Parts)

	return FromParts(self.m_RootType, Parts)
end

function CFilePath:Combine(Other: CFilePath): CFilePath
	local OtherParts = Other:GetParts()
	local StartIndex = 1

	if OtherParts[1] and (OtherParts[1].Type == "Root" or OtherParts[1].Type == "Home") then
		StartIndex = 2
	end

	local Parts = table.clone(self.m_Parts)
	for i = StartIndex, #OtherParts do
		table.insert(Parts, OtherParts[i])
	end

	return FromParts(self.m_RootType, Parts)
end

function CFilePath:Resolve(Context: FileContext): CFilePath
	if not self:IsValid() then
		return CFilePath.new("")
	end

	if self.m_RootType == "Root" then
		return FromParts("Root", table.clone(self.m_Parts))
	end

	if self.m_RootType == "Home" then
		return CFilePath.new(Context.HomeDirectory):Combine(self)
	end

	return CFilePath.new(Context.WorkingDirectory):Combine(self)
end

return CFilePath
