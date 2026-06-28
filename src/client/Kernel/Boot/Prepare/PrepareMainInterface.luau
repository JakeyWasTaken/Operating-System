const InterfaceManager = require("@kernel/Interface/InterfaceManager")
const MainInterface = require("@kernel/Interface/Interfaces/MainInterface")
const BootInterface = require("@kernel/Interface/Interfaces/BootInterface")

InterfaceManager.SetInterface(MainInterface)
BootInterface.Clear()

return true
