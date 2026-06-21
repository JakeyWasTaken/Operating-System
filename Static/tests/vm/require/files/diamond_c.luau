-- The shared leaf of a diamond dependency: diamond_a and diamond_b both
-- require this. Only used by test_diamond.luau.
local State = { Runs = 0 }
State.Runs += 1

return State
