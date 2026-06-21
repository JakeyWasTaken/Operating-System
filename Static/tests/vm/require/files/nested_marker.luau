-- Used only by test_relative_paths.luau (directly, via nested/escape_up.luau,
-- and via an absolute-path require) - all three are intentional repeat
-- requires of this one file, exercising the cache from different angles.
local State = { Runs = 0 }
State.Runs += 1

return State
