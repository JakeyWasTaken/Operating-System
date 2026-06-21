-- A "diamond" dependency: two unrelated modules (a and b) both require the
-- same third module (c). Unlike requires_counter_twice.luau, the repeated
-- require of c happens from two DIFFERENT requirers, not the same script -
-- this exercises ScriptFactory's cache across the require graph, not just
-- a single file re-requiring itself.
local A = require("./diamond_a.luau")
local B = require("./diamond_b.luau")

assert(A.c == B.c, "two different requirers of the same dependency should get the same cached module")
assert(A.c.Runs == 1, "the shared dependency's body should only run once across both requirers")

return "OK"
