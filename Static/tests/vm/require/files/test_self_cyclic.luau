-- Also expected to fail until CScript:Run() gains a re-entrancy guard (see
-- self_cyclic.luau and runRequireFiles.luau).
local Result = require("./self_cyclic.luau")

assert(Result.selfRequired == true, "a module requiring itself should see itself as already in-progress/cached, not error or infinite-loop")

return "OK"
