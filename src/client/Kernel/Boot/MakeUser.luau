const UserRegistry = require("@kernel/User/UserRegistry")
const BootInterface = require("@kernel/Interface/Interfaces/BootInterface")

const Players = game:GetService("Players")

local Name = Players.LocalPlayer.DisplayName
local UserId = UserRegistry.MakeUser(Name, true)

BootInterface.PushString(`Made elevated user "{Name}" [{UserId}]`)

return true
