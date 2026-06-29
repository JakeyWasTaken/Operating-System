-- Used by spawning.luau to verify the stdio library's StdOut/StdError write
-- exactly what's passed, with no trailing newline appended (unlike print/warn).
local stdio = require("@osiris/stdio")

stdio.StdOut("raw-out")
stdio.StdError("raw-err")

exit(0)
