local Parser = require("@kernel/FileSystem/Parser")

return function()
	describe("Path Relation", function()
		it("Should handle dot prefixes", function()
			local Paths = {
				"./Path",
				"../Path",
				"Path",
			}

			for _, Path in Paths do
				expect(Parser.Parse(Path).Type).to.equal("Relative")
			end
		end)

		it("Should handle slash prefixes", function()
			local Paths = {
				"/Path",
				"//Path",
			}

			for _, Path in Paths do
				expect(Parser.Parse(Path).Type).to.equal("Absolute")
			end
		end)
	end)

	describe("Path Resolution", function()
		it("Should properly recognize empty traversals", function()
			-- Second element should be the number of correct traversals
			local Paths = {
				{ "a/b/c/d/e/f//g", 7 },
				{ "a/////b", 2 },
				{ "///a///b/c//d/e", 5 },
			}

			for _, Path in Paths do
				expect(#Parser.Parse(Path[1]).Traversal).to.equal(Path[2])
			end
		end)

		it("Should properly recognize escapes", function()
			-- Second element should be an array of positions where escapes should be
			local Paths = {
				{ "a/../b/c", { 2 } },
				{ "a/../b/../c", { 2, 4 } },
				{ "a/....../b/../c", { 4 } },
				{ "../a/b/../c", { 1, 4 } },
			}

			for _, Path in Paths do
				local Result = Parser.Parse(Path[1])

				for i, Traversal in Result.Traversal do
					local ShouldBeEscape = table.find(Path[2], i)

					expect(Traversal.Type).to.equal(ShouldBeEscape and "Escape" or "Enter")
				end
			end
		end)
	end)
end
