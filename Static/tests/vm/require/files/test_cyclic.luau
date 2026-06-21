-- Expected to fail until CScript:Run() gains a re-entrancy guard (see
-- cyclic_a.luau and runRequireFiles.luau). This asserts the INTENDED
-- behavior, not the current one, so it'll start passing automatically
-- once that's fixed.
local a = require("./cyclic_a.luau")

assert(a.name == "a", "cyclic_a's module table should be returned")
assert(a.b.name == "b", "cyclic_a should see cyclic_b's module")
assert(a.b.a ~= nil, "cyclic_b's back-reference to cyclic_a should be populated, even if it's a partial/in-progress module")

return "OK"
