-- Requires the exact same file twice from the same script. A correct
-- require() should hit ScriptFactory's cache on the second call and hand
-- back the SAME module table without rerunning its body.
local a = require("./counter.luau")
local b = require("./counter.luau")

assert(a == b, "requiring the same file twice should return the same cached module table")
assert(a.Runs == 1, "the module body should only execute once even when required twice")

return "OK"
