const UserRegistry = require("@kernel/User/UserRegistry")
const BootInterface = require("@kernel/Interface/Interfaces/BootInterface")

const Players = game:GetService("Players")

local User = UserRegistry.MakeUser(Players.LocalPlayer.DisplayName, true)

if User then
    BootInterface.PushString(`Made elevated user "{User.Name}" [{User.Id}]`)
else
    BootInterface.PushString(`Failed to create elevated user, cannot boot`)
end

return User ~= nil
