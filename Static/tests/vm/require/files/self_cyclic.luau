-- A module that requires itself. Same re-entrancy issue as
-- cyclic_a/cyclic_b applies here too - see test_self_cyclic.luau.
local Self = require("./self_cyclic.luau")

return { selfRequired = Self ~= nil }
