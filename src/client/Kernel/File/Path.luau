--[[

Path rule-set:

All paths are converted to backslash notation, however either can be used in parsing

Prefixes:

~ : Marks as relative to home
. : Cleaned during parsing, marks path as relative
.. : Cleaned during parsing, adds escape node at start and marks as relative
\  : Cleaned during parsing, marks as absolute
[None] : Marks as absolute


]]

const Class = require("@core/Class")
const Log = require("@core/Log")
const Context = require("@kernel/File/Context")

type PathType = "Home" | "Absolute" | "Relative" | "None"
type PathNode = { Type: "Escape" } | { Type: "Step", Name: string }

export type CPath = {
	new: (String: string) -> CPath,
    ValidateStrings: (Strings: {string}) -> boolean,
    ValidateContext: (Context: Context.Context) -> boolean,

	-- --------------------------------- Methods -------------------------------- --

	ToString: (self: CPath) -> string,
    --- Given context will return a path that is always absolute
    ToStringAbsolute: (self: CPath, Context: Context.Context) -> string,

    --- Returns a new path with the provided string appended
    Append: (self: CPath, String: string) -> CPath,
    --- Returns a new path pointing to the parent
    GetParent: (self: CPath) -> CPath,

    --- This does not check if the path points to anything, simply if the path itself
    --- resolved to something
	IsValid: (self: CPath) -> boolean,

	--- Returns nil if invalid or no extension is present
    ---
    --- Having an extension does not mean this path is a file within the file system
	GetExtension: (self: CPath) -> string?,

	GetPathType: (self: CPath) -> PathType,

    GetNodes: (self: CPath) -> { PathNode },

	m_ParseString: (self: CPath, String: string) -> (),

	-- --------------------------------- Members -------------------------------- --

	m_PathType: PathType,
	m_Nodes: { PathNode },
} & Class.Base

local CPath: CPath = Class("CPath")

function CPath.new(String: string)
	local self: CPath = setmetatable({}, CPath) :: any
	(CPath :: any)(self)

	self.m_PathType = "None"
	self.m_Nodes = {}

	self:m_ParseString(String)

	return self
end

function CPath.ValidateStrings(Strings: {string})
    for _, String in Strings do
        local Path = CPath.new(String)
        if not Path:IsValid() then
            return false
        end
    end

    return true
end

function CPath.ValidateContext(Context: Context.Context)
    return CPath.ValidateStrings({ Context.HomeDirectory, Context.WorkingDirectory })
end

function CPath:ToString()
    if not self:IsValid() then
        return ""
    end

    local Steps = {}

    -- We want to be explicit
    if self.m_PathType == "Absolute" then
        table.insert(Steps, #self.m_Nodes > 0 and "" or "\\")
    elseif self.m_PathType == "Home" then
        table.insert(Steps, "~")
    elseif self.m_PathType == "Relative" then
        table.insert(Steps, ".")
    end

    for _, Node in self.m_Nodes do
        if Node.Type == "Escape" then
            table.insert(Steps, "..")
            continue
        end

        table.insert(Steps, Node.Name)
    end

    return table.concat(Steps, "\\")
end

function CPath:ToStringAbsolute(Context: Context.Context)
    if not self:IsValid() then
        return ""
    end

    local Steps = {}

    -- We want to be explicit
    if self.m_PathType == "Absolute" then
        table.insert(Steps, #self.m_Nodes > 0 and "" or "\\")
    elseif self.m_PathType == "Home" then
        table.insert(Steps, Context.HomeDirectory)
    elseif self.m_PathType == "Relative" then
        table.insert(Steps, Context.WorkingDirectory)
    end

    for _, Node in self.m_Nodes do
        if Node.Type == "Escape" then
            table.insert(Steps, "..")
            continue
        end

        table.insert(Steps, Node.Name)
    end

    return table.concat(Steps, "\\")
end

function CPath:Append(String: string)
    return CPath.new(`{self:ToString()}\\{String}`)
end

function CPath:GetParent()
    if not self:IsValid() then
        return CPath.new("")
    end

    -- Absolute root has no parent — clamp
    if self.m_PathType == "Absolute" and #self.m_Nodes == 0 then
        return self
    end

    local LastNode = self.m_Nodes[#self.m_Nodes]

    -- No nodes left on a Home/Relative path — must escape upward
    if LastNode == nil then
        return CPath.new(`{self:ToString()}\\..`)
    end

    -- Last node is already an Escape — stack another (Relative/Home only;
    -- Absolute can't go above root so clamp)
    if LastNode.Type == "Escape" then
        if self.m_PathType == "Absolute" then
            return self
        end
        return CPath.new(`{self:ToString()}\\..`)
    end

    -- General case: drop the last Step node
    local Steps = {}

    if self.m_PathType == "Absolute" then
        table.insert(Steps, "")
    elseif self.m_PathType == "Home" then
        table.insert(Steps, "~")
    elseif self.m_PathType == "Relative" then
        table.insert(Steps, ".")
    end

    for i = 1, #self.m_Nodes - 1 do
        local Node = self.m_Nodes[i]
        if Node.Type == "Escape" then
            table.insert(Steps, "..")
        else
            table.insert(Steps, Node.Name)
        end
    end

    if self.m_PathType == "Absolute" and #self.m_Nodes == 1 then
        return CPath.new("\\")
    end

    return CPath.new(table.concat(Steps, "\\"))
end

function CPath:IsValid()
    return self.m_PathType ~= "None"
end

function CPath:GetExtension()
    if not self:IsValid() or #self.m_Nodes == 0 then
        return nil
    end

    local LastNode = self.m_Nodes[#self.m_Nodes]
    if LastNode.Type ~= "Step" then
        return nil
    end

    local Start = LastNode.Name:reverse():find("%.")
    if not Start then
        return nil
    end

    return LastNode.Name:reverse():sub(1, Start - 1):reverse()
end

function CPath:GetPathType()
    return self.m_PathType
end

function CPath:GetNodes()
    return self.m_Nodes
end

function CPath:m_ParseString(String: string)
    if #String == 0 then
        return
    end

    const Corrected = String:gsub("/", "\\")
    local Split = Corrected:split("\\")

    if #Split == 0 then
        return
    end

    local RemovePrefix = true

    -- Our path is "/..."
    if Split[1] == "" then
        self.m_PathType = "Absolute"
    elseif Split[1] == "~" then
        self.m_PathType = "Home"
    else
        -- Extra check here so that folders / files can have a . prefix without breaking paths
        -- stops marking ".folder/..." as a relative path
        local Start, End = Split[1]:find("%.+")
        if Start == 1 and End == #Split[1] then
            self.m_PathType = "Relative"
            RemovePrefix = #Split[1] == 1 -- Only remove it it's pointing to current level, and not an escape
        end
    end

    -- We had no prefix, makes us absolute
    if self.m_PathType == "None" then
        self.m_PathType = "Absolute"
        RemovePrefix = false
    end

    if RemovePrefix then
        table.remove(Split, 1)
    end

    if #Split == 0 then
        return
    end

    for _, NodeString in Split do
        if #NodeString == 0 then -- Skip empty
            continue
        end

        -- Check escape first
        local Start, End = NodeString:find("%.+")
        if Start == 1 and End == #NodeString then
            if #NodeString > 1 then
                table.insert(self.m_Nodes, { Type = "Escape" })
            end

            continue
        end

        if NodeString:sub(#NodeString, #NodeString) == "." then
            Log.warn(`Failed to parse path "{Corrected}" contains malformed step "{NodeString}" cannot suffix with a "."`)
            self.m_PathType = "None"
            table.clear(self.m_Nodes)
            return
        end

        table.insert(self.m_Nodes, { Type = "Step", Name = NodeString })
    end

    return
end

return CPath
