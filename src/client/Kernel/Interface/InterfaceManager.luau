const JDI = require("@vendor/JustDrawIt")
const e = JDI.create
const dom = JDI.dom
const mount = JDI.mount

const Players = game:GetService("Players")
const PlayerGui = Players.LocalPlayer.PlayerGui

local ActiveInterface: (() -> unknown)? = nil
local InterfaceManager = {}

function InterfaceManager.SetInterface(Interface: { Draw: () -> unknown })
    assert(typeof(Interface) == "table" and typeof(Interface.Draw) == "function")

    ActiveInterface = Interface.Draw
end

function InterfaceManager.Draw()
    --stylua: ignore
    return e "ScreenGui" {
        Name = "Main",
        DisplayOrder = -1,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,

        if ActiveInterface then ActiveInterface() else nil,
    }
end

mount(dom(InterfaceManager.Draw), PlayerGui)

return InterfaceManager
