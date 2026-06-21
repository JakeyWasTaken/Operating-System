-- ../ should escape back up out of nested/ to the files/ directory.
local Marker = require("../nested_marker.luau")
return { from = "nested/escape_up", marker = Marker }
