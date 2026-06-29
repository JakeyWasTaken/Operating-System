local CFilePath = require("@kernel/File/FilePath")

return function()
	-- -------------------------------------------------------------------------
	-- CFilePath.new / parsing
	-- -------------------------------------------------------------------------
	describe("CFilePath.new", function()
		describe("Root paths", function()
			it("parses a leading forward-slash as Root", function()
				local p = CFilePath.new("/foo/bar")
				expect(p:IsValid()).to.equal(true)
				expect(p:GetParts()[1].Type).to.equal("Root")
			end)

			it("parses a leading backslash as Root", function()
				local p = CFilePath.new("\\foo\\bar")
				expect(p:IsValid()).to.equal(true)
				expect(p:GetParts()[1].Type).to.equal("Root")
			end)

			it("parses the root alone with no further parts", function()
				local p = CFilePath.new("/")
				expect(p:IsValid()).to.equal(true)
				expect(#p:GetParts()).to.equal(1)
				expect(p:GetParts()[1].Type).to.equal("Root")
			end)

			it("normalises backslashes to forward slashes in parts", function()
				local Parts = CFilePath.new("\\foo\\bar"):GetParts()
				expect(Parts[2].Name).to.equal("foo")
				expect(Parts[3].Name).to.equal("bar")
			end)
		end)

		describe("Home paths", function()
			it("parses a ~ prefix as Home", function()
				local p = CFilePath.new("~/documents/file.txt")
				expect(p:IsValid()).to.equal(true)
				expect(p:GetParts()[1].Type).to.equal("Home")
			end)

			it("parses a bare ~ as Home with no further parts", function()
				local p = CFilePath.new("~")
				expect(#p:GetParts()).to.equal(1)
				expect(p:GetParts()[1].Type).to.equal("Home")
			end)
		end)

		describe("Relative paths", function()
			it("parses a bare name (no prefix) as Relative", function()
				local p = CFilePath.new("foo/bar")
				expect(p:IsValid()).to.equal(true)
				-- Relative paths carry no leading marker part.
				expect(p:GetParts()[1].Type).to.equal("Enter")
				expect(p:GetParts()[1].Name).to.equal("foo")
			end)

			it("parses a leading dot with no leading marker part", function()
				local p = CFilePath.new("./folder/file")
				expect(p:IsValid()).to.equal(true)
				local Parts = p:GetParts()
				expect(Parts[1].Type).to.equal("Enter")
				expect(Parts[1].Name).to.equal("folder")
			end)

			it("parses a leading double-dot as a leading Escape part", function()
				local p = CFilePath.new("../folder")
				local Parts = p:GetParts()
				expect(Parts[1].Type).to.equal("Escape")
				expect(Parts[2].Name).to.equal("folder")
			end)

			it("does NOT treat a dot-prefixed folder name as the relative marker", function()
				-- ".folder" is a literal folder name, not the "." relative marker,
				-- so it is kept as the first step rather than being stripped.
				local p = CFilePath.new(".folder/child")
				local Parts = p:GetParts()
				expect(Parts[1].Type).to.equal("Enter")
				expect(Parts[1].Name).to.equal(".folder")
				expect(Parts[2].Name).to.equal("child")
			end)

			it("strips the leading dot but keeps subsequent parts", function()
				local Parts = CFilePath.new("./a/b"):GetParts()
				expect(#Parts).to.equal(2)
				expect(Parts[1].Name).to.equal("a")
				expect(Parts[2].Name).to.equal("b")
			end)
		end)

		describe("Malformed paths", function()
			it("marks a path with a dot-suffixed step as invalid", function()
				expect(CFilePath.new("/foo/bar."):IsValid()).to.equal(false)
			end)

			it("marks an empty string as invalid", function()
				expect(CFilePath.new(""):IsValid()).to.equal(false)
			end)

			it("returns an empty part list for an invalid path", function()
				expect(#CFilePath.new(""):GetParts()).to.equal(0)
			end)
		end)

		describe("Escape parts", function()
			it("produces one Escape part per double-dot segment", function()
				local Parts = CFilePath.new("./../../file"):GetParts()
				expect(Parts[1].Type).to.equal("Escape")
				expect(Parts[2].Type).to.equal("Escape")
				expect(Parts[3].Name).to.equal("file")
			end)

			it("ignores a lone dot segment inside a path", function()
				local Parts = CFilePath.new("/foo/./bar"):GetParts()
				expect(#Parts).to.equal(3) -- Root, foo, bar
				expect(Parts[2].Name).to.equal("foo")
				expect(Parts[3].Name).to.equal("bar")
			end)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- GetString
	-- -------------------------------------------------------------------------
	describe("GetString", function()
		it("returns an empty string for an invalid path", function()
			expect(CFilePath.new(""):GetString()).to.equal("")
		end)

		it("round-trips a Root path", function()
			expect(CFilePath.new("/foo/bar"):GetString()).to.equal("/foo/bar")
		end)

		it("emits / for the root alone", function()
			expect(CFilePath.new("/"):GetString()).to.equal("/")
		end)

		it("round-trips a Home path", function()
			expect(CFilePath.new("~/docs/readme.md"):GetString()).to.equal("~/docs/readme.md")
		end)

		it("round-trips a Relative path", function()
			expect(CFilePath.new("./a/b"):GetString()).to.equal("./a/b")
		end)

		it("emits .. for Escape parts", function()
			expect(CFilePath.new("./../file"):GetString()).to.equal("./../file")
		end)

		it("normalises backslash input to forward-slash output", function()
			expect(CFilePath.new("\\foo\\bar"):GetString()).to.equal("/foo/bar")
		end)

		it("uses forward-slash separators regardless of input slash style", function()
			expect(CFilePath.new("\\foo\\bar"):GetString():find("\\")).to.equal(nil)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- GetName
	-- -------------------------------------------------------------------------
	describe("GetName", function()
		it("returns an empty string for an invalid path", function()
			expect(CFilePath.new(""):GetName()).to.equal("")
		end)

		it("returns an empty string for the root alone", function()
			expect(CFilePath.new("/"):GetName()).to.equal("")
		end)

		it("returns ~ for a bare Home path", function()
			expect(CFilePath.new("~"):GetName()).to.equal("~")
		end)

		it("returns . for a bare Relative path", function()
			expect(CFilePath.new("."):GetName()).to.equal(".")
		end)

		it("returns the name of the last Enter part", function()
			expect(CFilePath.new("/foo/bar.txt"):GetName()).to.equal("bar.txt")
		end)

		it("returns .. when the last part is an Escape", function()
			expect(CFilePath.new("./.."):GetName()).to.equal("..")
		end)
	end)

	-- -------------------------------------------------------------------------
	-- GetParent
	-- -------------------------------------------------------------------------
	describe("GetParent", function()
		it("returns an invalid path when called on an invalid path", function()
			expect(CFilePath.new(""):GetParent():IsValid()).to.equal(false)
		end)

		it("returns itself when called on the root alone", function()
			local root = CFilePath.new("/")
			expect(root:GetParent():GetString()).to.equal("/")
		end)

		it("returns the root when one step away from it", function()
			expect(CFilePath.new("/foo"):GetParent():GetString()).to.equal("/")
		end)

		it("drops the last step of a Root path", function()
			expect(CFilePath.new("/foo/bar/baz"):GetParent():GetString()).to.equal("/foo/bar")
		end)

		it("drops the last step of a Home path", function()
			expect(CFilePath.new("~/a/b"):GetParent():GetString()).to.equal("~/a")
		end)

		it("drops the last step of a Relative path", function()
			expect(CFilePath.new("./a/b"):GetParent():GetString()).to.equal("./a")
		end)

		it("adds an Escape part when a Relative path has no steps left", function()
			local p = CFilePath.new("./a"):GetParent():GetParent()
			expect(p:GetParts()[1].Type).to.equal("Escape")
		end)

		it("clamps a Root path that already ends in an Escape", function()
			local p = CFilePath.new("/foo"):GetParent():GetParent()
			expect(p:GetString()).to.equal("/")
		end)

		it("returns a new path, not the original", function()
			local original = CFilePath.new("/foo/bar")
			local parent = original:GetParent()
			expect(original:GetString()).to.equal("/foo/bar")
			expect(parent:GetString()).to.equal("/foo")
		end)
	end)

	-- -------------------------------------------------------------------------
	-- Append
	-- -------------------------------------------------------------------------
	describe("Append", function()
		it("appends a simple name to a Root path", function()
			expect(CFilePath.new("/foo"):Append("bar"):GetString()).to.equal("/foo/bar")
		end)

		it("appends a multi-segment string", function()
			local Parts = CFilePath.new("/foo"):Append("bar/baz"):GetParts()
			expect(Parts[3].Name).to.equal("bar")
			expect(Parts[4].Name).to.equal("baz")
		end)

		it("accepts a backslash-separated string", function()
			expect(CFilePath.new("/foo"):Append("bar\\baz"):GetString()).to.equal("/foo/bar/baz")
		end)

		it("returns a new path, not the original", function()
			local original = CFilePath.new("/foo")
			local appended = original:Append("bar")
			expect(original:GetString()).to.equal("/foo")
			expect(appended:GetString()).to.equal("/foo/bar")
		end)

		it("preserves the path type of the base", function()
			expect(CFilePath.new("~/docs"):Append("file.txt"):GetParts()[1].Type).to.equal("Home")
		end)
	end)

	-- -------------------------------------------------------------------------
	-- Combine
	-- -------------------------------------------------------------------------
	describe("Combine", function()
		it("appends another path's parts onto self", function()
			local Combined = CFilePath.new("/foo"):Combine(CFilePath.new("bar/baz"))
			expect(Combined:GetString()).to.equal("/foo/bar/baz")
		end)

		it("drops the other path's leading Root/Home marker", function()
			local Combined = CFilePath.new("/foo"):Combine(CFilePath.new("~/bar"))
			expect(Combined:GetString()).to.equal("/foo/bar")
		end)

		it("preserves Escape parts from the other path", function()
			local Combined = CFilePath.new("/foo"):Combine(CFilePath.new("./../bar"))
			local Parts = Combined:GetParts()
			expect(Parts[2].Name).to.equal("foo")
			expect(Parts[3].Type).to.equal("Escape")
			expect(Parts[4].Name).to.equal("bar")
		end)

		it("returns a new path, not the original", function()
			local original = CFilePath.new("/foo")
			original:Combine(CFilePath.new("bar"))
			expect(original:GetString()).to.equal("/foo")
		end)
	end)

	-- -------------------------------------------------------------------------
	-- Resolve
	-- -------------------------------------------------------------------------
	describe("Resolve", function()
		local Context = {
			HomeDirectory = "/home/user",
			WorkingDirectory = "/var/work",
		}

		it("returns an invalid path for an invalid path", function()
			expect(CFilePath.new(""):Resolve(Context):IsValid()).to.equal(false)
		end)

		it("leaves a Root path unchanged", function()
			expect(CFilePath.new("/foo/bar"):Resolve(Context):GetString()).to.equal("/foo/bar")
		end)

		it("expands ~ using HomeDirectory", function()
			expect(CFilePath.new("~/file.txt"):Resolve(Context):GetString()).to.equal("/home/user/file.txt")
		end)

		it("expands a Relative path using WorkingDirectory", function()
			expect(CFilePath.new("./file.txt"):Resolve(Context):GetString()).to.equal("/var/work/file.txt")
		end)

		it("preserves Escape parts verbatim (collapsing them is the VFS's job)", function()
			expect(CFilePath.new("./../file"):Resolve(Context):GetString()).to.equal("/var/work/../file")
		end)

		it("returns a path whose first part is Root", function()
			expect(CFilePath.new("~/file.txt"):Resolve(Context):GetParts()[1].Type).to.equal("Root")
		end)
	end)

	-- -------------------------------------------------------------------------
	-- ValidateStrings
	-- -------------------------------------------------------------------------
	describe("ValidateStrings", function()
		it("returns true when all strings are valid paths", function()
			expect(CFilePath.ValidateStrings({ "/home/user", "/var/work" })).to.equal(true)
		end)

		it("returns false when any string is an invalid path", function()
			expect(CFilePath.ValidateStrings({ "/home/user", "" })).to.equal(false)
		end)

		it("returns true for an empty list", function()
			expect(CFilePath.ValidateStrings({})).to.equal(true)
		end)
	end)
end
