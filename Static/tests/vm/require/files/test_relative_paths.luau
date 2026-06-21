-- Relative path resolution: subdirectories, escaping back up with ../, and
-- absolute vs. relative requires of the same file hitting the same cache.
local Child = require("./nested/child.luau")
assert(Child.from == "nested/child", "should be able to require a file in a subdirectory")

local Sibling = require("./nested/sibling.luau")
assert(Sibling.from == "nested/sibling", "nested/sibling.luau should resolve correctly")
assert(Sibling.child.from == "nested/child", "a relative require INSIDE a subdirectory should resolve relative to ITS OWN directory, not the root")

local EscapeUp = require("./nested/escape_up.luau")
assert(EscapeUp.from == "nested/escape_up", "nested/escape_up.luau should resolve correctly")
assert(EscapeUp.marker.Runs ~= nil, "../ from within nested/ should correctly escape back up to the files/ directory")

-- the same file, reached via a relative path and an absolute path, should
-- resolve to the exact same cached module
local ViaRelative = require("./nested_marker.luau")
local ViaAbsolute = require("/tests/vm/require/files/nested_marker.luau")
assert(ViaRelative == ViaAbsolute, "relative and absolute requires of the same file should hit the same cache entry")
assert(ViaRelative == EscapeUp.marker, "the marker reached via ../ should also be the exact same cached module")

return "OK"
