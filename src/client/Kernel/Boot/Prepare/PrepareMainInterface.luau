const InterfaceManager = require("@kernel/Interface/InterfaceManager")
const MainInterface = require("@kernel/Interface/Interfaces/MainInterface")
const BootInterface = require("@kernel/Interface/Interfaces/BootInterface")
const WindowFactory = require("@kernel/Window/WindowFactory")

InterfaceManager.SetInterface(MainInterface)
BootInterface.Clear()

WindowFactory.CreateWindow():SetFullscreen(true)

return true
