-- Mutually-requiring modules, only used by test_cyclic.luau. See that file
-- (and runRequireFiles.luau) for why this currently can't resolve: when
-- cyclic_b re-requires cyclic_a, cyclic_a's Script is still mid-Run() (its
-- m_Returns isn't set yet), so CScript:Run() reruns cyclic_a's body from
-- scratch instead of recognizing the re-entrant call - which calls
-- require(cyclic_b) again, which is itself still mid-Run() too, recursing
-- until the stack overflows.
local Module = { name = "a" }
Module.b = require("./cyclic_b.luau")

return Module
