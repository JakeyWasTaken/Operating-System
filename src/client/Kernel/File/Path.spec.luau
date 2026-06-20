local CPath = require("@kernel/File/Path")
local FileContext = require("@kernel/File/Context")

return function()
	-- -------------------------------------------------------------------------
	-- CPath.new / m_ParseString
	-- -------------------------------------------------------------------------
	describe("CPath.new", function()
		describe("Absolute paths", function()
			it("parses a leading backslash as absolute", function()
				local p = CPath.new("\\foo\\bar")
				expect(p:GetPathType()).to.equal("Absolute")
				expect(p:IsValid()).to.equal(true)
			end)

			it("parses a leading forward-slash as absolute", function()
				local p = CPath.new("/foo/bar")
				expect(p:GetPathType()).to.equal("Absolute")
				expect(p:IsValid()).to.equal(true)
			end)

			it("parses a bare name (no prefix) as absolute", function()
				local p = CPath.new("foo\\bar")
				expect(p:GetPathType()).to.equal("Absolute")
				expect(p:IsValid()).to.equal(true)
			end)

			it("parses the root backslash alone as absolute with no nodes", function()
				local p = CPath.new("\\")
				expect(p:GetPathType()).to.equal("Absolute")
				expect(p:IsValid()).to.equal(true)
				expect(#p:GetNodes()).to.equal(0)
			end)

			it("normalises forward slashes to backslashes in nodes", function()
				local p = CPath.new("/foo/bar")
				local nodes = p:GetNodes()
				expect(nodes[1].Name).to.equal("foo")
				expect(nodes[2].Name).to.equal("bar")
			end)
		end)

		describe("Home paths", function()
			it("parses ~ prefix as Home", function()
				local p = CPath.new("~\\documents\\file.txt")
				expect(p:GetPathType()).to.equal("Home")
				expect(p:IsValid()).to.equal(true)
			end)

			it("parses bare ~ as Home with no nodes", function()
				local p = CPath.new("~")
				expect(p:GetPathType()).to.equal("Home")
				expect(#p:GetNodes()).to.equal(0)
			end)
		end)

		describe("Relative paths", function()
			it("parses a leading dot as Relative", function()
				local p = CPath.new(".\\folder\\file")
				expect(p:GetPathType()).to.equal("Relative")
				expect(p:IsValid()).to.equal(true)
			end)

			it("parses a leading double-dot as Relative with an Escape node", function()
				local p = CPath.new("..\\folder")
				expect(p:GetPathType()).to.equal("Relative")
				local nodes = p:GetNodes()
				expect(nodes[1].Type).to.equal("Escape")
				expect(nodes[2].Name).to.equal("folder")
			end)

			it("does NOT treat a dot-prefixed folder name as Relative", function()
				-- '.folder' has chars after the dot so it must NOT become a Relative prefix
				local p = CPath.new(".folder\\child")
				expect(p:GetPathType()).to.equal("Absolute")
				local nodes = p:GetNodes()
				expect(nodes[1].Name).to.equal(".folder")
			end)

			it("strips the leading dot but keeps subsequent nodes", function()
				local p = CPath.new(".\\a\\b")
				local nodes = p:GetNodes()
				expect(#nodes).to.equal(2)
				expect(nodes[1].Name).to.equal("a")
				expect(nodes[2].Name).to.equal("b")
			end)
		end)

		describe("Malformed paths", function()
			it("marks a path with a dot-suffixed step as invalid", function()
				local p = CPath.new("\\foo\\bar.")
				expect(p:IsValid()).to.equal(false)
			end)

			it("marks an empty string as invalid", function()
				local p = CPath.new("")
				expect(p:IsValid()).to.equal(false)
			end)

			it("returns GetPathType 'None' for invalid paths", function()
				local p = CPath.new("")
				expect(p:GetPathType()).to.equal("None")
			end)
		end)

		describe("Escape nodes", function()
			it("produces one Escape node per double-dot segment", function()
				local p = CPath.new(".\\..\\..\\file")
				local nodes = p:GetNodes()
				expect(nodes[1].Type).to.equal("Escape")
				expect(nodes[2].Type).to.equal("Escape")
				expect(nodes[3].Name).to.equal("file")
			end)

			it("ignores a lone dot segment inside a path (not just prefix)", function()
				-- a mid-path '.' segment is all-dots of length 1 → skipped, not an Escape
				local p = CPath.new("\\foo\\.\\bar")
				local nodes = p:GetNodes()
				expect(#nodes).to.equal(2)
				expect(nodes[1].Name).to.equal("foo")
				expect(nodes[2].Name).to.equal("bar")
			end)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- ToString
	-- -------------------------------------------------------------------------
	describe("ToString", function()
		it("returns empty string for an invalid path", function()
			expect(CPath.new(""):ToString()).to.equal("")
		end)

		it("round-trips an absolute path", function()
			expect(CPath.new("\\foo\\bar"):ToString()).to.equal("\\foo\\bar")
		end)

		it("emits \\ for the absolute root", function()
			expect(CPath.new("\\"):ToString()).to.equal("\\")
		end)

		it("round-trips a Home path", function()
			expect(CPath.new("~\\docs\\readme.md"):ToString()).to.equal("~\\docs\\readme.md")
		end)

		it("round-trips a Relative path", function()
			expect(CPath.new(".\\a\\b"):ToString()).to.equal(".\\a\\b")
		end)

		it("emits .. for Escape nodes", function()
			expect(CPath.new(".\\..\\file"):ToString()).to.equal(".\\..\\file")
		end)

		it("uses backslash separators regardless of input slash style", function()
			local result = CPath.new("/foo/bar"):ToString()
			expect(result:find("/")).to.never.be.ok()
		end)
	end)

	-- -------------------------------------------------------------------------
	-- ToStringAbsolute
	-- -------------------------------------------------------------------------
	describe("ToStringAbsolute", function()
		local Context = {
			HomeDirectory = "\\home\\user",
			WorkingDirectory = "\\var\\work",
		}

		it("returns empty string for an invalid path", function()
			expect(CPath.new(""):ToStringAbsolute(Context)).to.equal("")
		end)

		it("leaves an Absolute path unchanged", function()
			expect(CPath.new("\\foo\\bar"):ToStringAbsolute(Context)).to.equal("\\foo\\bar")
		end)

		it("expands ~ using HomeDirectory", function()
			expect(CPath.new("~\\file.txt"):ToStringAbsolute(Context)).to.equal("\\home\\user\\file.txt")
		end)

		it("expands . using WorkingDirectory", function()
			expect(CPath.new(".\\file.txt"):ToStringAbsolute(Context)).to.equal("\\var\\work\\file.txt")
		end)

		it("emits .. escape nodes verbatim (resolution is the VFS's job)", function()
			local result = CPath.new(".\\..\\file"):ToStringAbsolute(Context)
			expect(result).to.equal("\\var\\work\\..\\file")
		end)
	end)

	-- -------------------------------------------------------------------------
	-- Append
	-- -------------------------------------------------------------------------
	describe("Append", function()
		it("appends a simple name to an absolute path", function()
			local p = CPath.new("\\foo"):Append("bar")
			expect(p:ToString()).to.equal("\\foo\\bar")
		end)

		it("appends a multi-segment string", function()
			local p = CPath.new("\\foo"):Append("bar\\baz")
			local nodes = p:GetNodes()
			expect(nodes[2].Name).to.equal("bar")
			expect(nodes[3].Name).to.equal("baz")
		end)

		it("returns a new CPath, not the original", function()
			local original = CPath.new("\\foo")
			local appended = original:Append("bar")
			expect(original:ToString()).to.equal("\\foo")
			expect(appended:ToString()).to.equal("\\foo\\bar")
		end)

		it("preserves the path type of the base", function()
			local p = CPath.new("~\\docs"):Append("file.txt")
			expect(p:GetPathType()).to.equal("Home")
		end)
	end)

	-- -------------------------------------------------------------------------
	-- GetParent
	-- -------------------------------------------------------------------------
	describe("GetParent", function()
		it("returns an invalid path when called on an invalid path", function()
			expect(CPath.new(""):GetParent():IsValid()).to.equal(false)
		end)

		it("returns itself when called on the absolute root", function()
			local root = CPath.new("\\")
			expect(root:GetParent():ToString()).to.equal("\\")
		end)

		it("returns the absolute root when one step from it", function()
			expect(CPath.new("\\foo"):GetParent():ToString()).to.equal("\\")
		end)

		it("drops the last step of an absolute path", function()
			expect(CPath.new("\\foo\\bar\\baz"):GetParent():ToString()).to.equal("\\foo\\bar")
		end)

		it("drops the last step of a Home path", function()
			expect(CPath.new("~\\a\\b"):GetParent():ToString()).to.equal("~\\a")
		end)

		it("drops the last step of a Relative path", function()
			expect(CPath.new(".\\a\\b"):GetParent():ToString()).to.equal(".\\a")
		end)

		it("adds an Escape node when a Relative path has no steps left", function()
			-- '.\a' -> parent is '.' itself; calling again should escape upward
			local p = CPath.new(".\\a"):GetParent():GetParent()
			local nodes = p:GetNodes()
			expect(nodes[1].Type).to.equal("Escape")
		end)

		it("adds another Escape node when already ending in Escape (Relative)", function()
			local p = CPath.new(".\\.."):GetParent()
			local nodes = p:GetNodes()
			expect(nodes[1].Type).to.equal("Escape")
			expect(nodes[2].Type).to.equal("Escape")
		end)

		it("clamps Absolute paths that already end in Escape", function()
			-- Absolute paths cannot escape past root
			local p = CPath.new("\\foo"):GetParent():GetParent() -- reaches root, should clamp
			expect(p:ToString()).to.equal("\\")
		end)

		it("preserves path type through GetParent", function()
			expect(CPath.new("~\\a\\b"):GetParent():GetPathType()).to.equal("Home")
			expect(CPath.new(".\\a\\b"):GetParent():GetPathType()).to.equal("Relative")
			expect(CPath.new("\\a\\b"):GetParent():GetPathType()).to.equal("Absolute")
		end)

		it("returns a new CPath, not the original", function()
			local original = CPath.new("\\foo\\bar")
			local parent = original:GetParent()
			expect(original:ToString()).to.equal("\\foo\\bar")
			expect(parent:ToString()).to.equal("\\foo")
		end)
	end)

	-- -------------------------------------------------------------------------
	-- IsValid
	-- -------------------------------------------------------------------------
	describe("IsValid", function()
		it("returns true for a well-formed absolute path", function()
			expect(CPath.new("\\foo"):IsValid()).to.equal(true)
		end)

		it("returns true for the absolute root", function()
			expect(CPath.new("\\"):IsValid()).to.equal(true)
		end)

		it("returns false for an empty string", function()
			expect(CPath.new(""):IsValid()).to.equal(false)
		end)

		it("returns false for a dot-suffixed step", function()
			expect(CPath.new("\\foo."):IsValid()).to.equal(false)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- GetExtension
	-- -------------------------------------------------------------------------
	describe("GetExtension", function()
		it("returns nil for an invalid path", function()
			expect(CPath.new(""):GetExtension()).to.equal(nil)
		end)

		it("returns nil when the last node has no extension", function()
			expect(CPath.new("\\foo\\bar"):GetExtension()).to.equal(nil)
		end)

		it("returns the extension for a simple filename", function()
			expect(CPath.new("\\foo\\bar.txt"):GetExtension()).to.equal("txt")
		end)

		it("returns the last extension for a multi-dot filename", function()
			expect(CPath.new("\\foo\\bar.spec.luau"):GetExtension()).to.equal("luau")
		end)

		it("returns nil when the last node is an Escape", function()
			expect(CPath.new(".\\.."):GetExtension()).to.equal(nil)
		end)

		it("returns nil for a path with no nodes (root)", function()
			expect(CPath.new("\\"):GetExtension()).to.equal(nil)
		end)

		it("handles a dot-prefixed filename with an extension", function()
			-- '.gitignore' has no extension (the dot is part of the name, not a separator)
			-- but '.git.ignore' should return 'ignore'
			expect(CPath.new("\\foo\\.git.ignore"):GetExtension()).to.equal("ignore")
		end)
	end)

	-- -------------------------------------------------------------------------
	-- GetPathType
	-- -------------------------------------------------------------------------
	describe("GetPathType", function()
		it("returns 'Absolute' for absolute paths", function()
			expect(CPath.new("\\foo"):GetPathType()).to.equal("Absolute")
		end)

		it("returns 'Home' for ~ paths", function()
			expect(CPath.new("~"):GetPathType()).to.equal("Home")
		end)

		it("returns 'Relative' for . paths", function()
			expect(CPath.new("."):GetPathType()).to.equal("Relative")
		end)

		it("returns 'None' for invalid paths", function()
			expect(CPath.new(""):GetPathType()).to.equal("None")
		end)
	end)

	-- -------------------------------------------------------------------------
	-- GetNodes
	-- -------------------------------------------------------------------------
	describe("GetNodes", function()
		it("returns an empty table for root", function()
			expect(#CPath.new("\\"):GetNodes()).to.equal(0)
		end)

		it("returns Step nodes with correct Names", function()
			local nodes = CPath.new("\\a\\b\\c"):GetNodes()
			expect(#nodes).to.equal(3)
			expect(nodes[1].Name).to.equal("a")
			expect(nodes[2].Name).to.equal("b")
			expect(nodes[3].Name).to.equal("c")
		end)

		it("mixes Escape and Step nodes in the correct order", function()
			local nodes = CPath.new(".\\..\\a"):GetNodes()
			expect(nodes[1].Type).to.equal("Escape")
			expect(nodes[2].Type).to.equal("Step")
			expect(nodes[2].Name).to.equal("a")
		end)
	end)

	-- -------------------------------------------------------------------------
	-- ValidateStrings
	-- -------------------------------------------------------------------------
	describe("ValidateStrings", function()
		it("returns true when all strings are valid paths", function()
			expect(CPath.ValidateStrings({ "\\home\\user", "\\var\\work" })).to.equal(true)
		end)

		it("returns false when any string is an invalid path", function()
			expect(CPath.ValidateStrings({ "\\home\\user", "" })).to.equal(false)
		end)

		it("returns true for an empty list", function()
			expect(CPath.ValidateStrings({})).to.equal(true)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- ValidateContext
	-- -------------------------------------------------------------------------
	describe("ValidateContext", function()
		it("returns true for a well-formed context", function()
			local ctx = FileContext.new()
			ctx.HomeDirectory = "\\home\\user"
			ctx.WorkingDirectory = "\\var\\work"

			expect(CPath.ValidateContext(ctx)).to.equal(true)
		end)

		it("returns false when HomeDirectory is invalid", function()
			local ctx = FileContext.new()
			ctx.HomeDirectory = ""
			ctx.WorkingDirectory = "\\var\\work"

			expect(CPath.ValidateContext(ctx)).to.equal(false)
		end)

		it("returns false when WorkingDirectory is invalid", function()
			local ctx = FileContext.new()
			ctx.HomeDirectory = "\\home\\user"
			ctx.WorkingDirectory = ""

			expect(CPath.ValidateContext(ctx)).to.equal(false)
		end)
	end)
end
