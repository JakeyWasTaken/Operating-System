const InterfaceManager = require("@kernel/Interface/InterfaceManager")
const BootInterface = require("@kernel/Interface/Interfaces/BootInterface")

const Version = require("@kernel/Version")

InterfaceManager.SetInterface(BootInterface)

BootInterface.PushString(`Osiris [{Version.Major}.{Version.Minor}.{Version.Patch}+{Version.Hash}]`)
BootInterface.PushString("")

return true
