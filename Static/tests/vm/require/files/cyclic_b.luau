local Module = { name = "b" }
Module.a = require("./cyclic_a.luau")

return Module
