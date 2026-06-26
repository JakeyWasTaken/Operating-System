-- Counts how deep we currently are inside a dom draw. create() uses it to reject
-- elements built outside a draw. It's a count, not a flag, because a draw can call
-- into component functions that draw too.
local Runtime = {
    active = 0,
}

return Runtime
