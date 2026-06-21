-- A relative require from WITHIN a subdirectory should resolve relative to
-- this file's own directory (nested/), not the root files/ directory.
local Child = require("./child.luau")
return { from = "nested/sibling", child = Child }
