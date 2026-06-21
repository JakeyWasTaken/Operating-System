-- Module-level state that only gets reinitialized if this file's body
-- actually runs again. Used to detect whether require() is genuinely
-- caching the module or recompiling/rerunning it on every call.
-- Only used by requires_counter_twice.luau - keep it that way, since any
-- OTHER top-level test that also required this file would collide with it
-- in ScriptFactory's per-process cache (see runRequireFiles.luau).
local State = { Runs = 0 }
State.Runs += 1

return State
