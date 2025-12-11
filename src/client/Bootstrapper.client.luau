local FileSystem = require("@kernel/FileSystem"):GetInstance()

print(FileSystem:Resolve("/").Value:ListChildren())
