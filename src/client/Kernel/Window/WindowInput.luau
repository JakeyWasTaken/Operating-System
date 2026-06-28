const WindowFactory = require("./WindowFactory")

const UserInputService = game:GetService("UserInputService")

-- Retain reference to all windows table
const AllWindows = WindowFactory.GetAllWindows()

do -- Input** Signals
    UserInputService.InputBegan:Connect(function(Object: InputObject, GameProcessed: boolean)
        for _, Window in AllWindows do
            Window:DigestInput(Enum.UserInputState.Begin, Object, GameProcessed)
        end
    end)

    UserInputService.InputChanged:Connect(function(Object: InputObject, GameProcessed: boolean)
        for _, Window in AllWindows do
            Window:DigestInput(Enum.UserInputState.Change, Object, GameProcessed)
        end
    end)

    UserInputService.InputEnded:Connect(function(Object: InputObject, GameProcessed: boolean)
        for _, Window in AllWindows do
            Window:DigestInput(Enum.UserInputState.End, Object, GameProcessed)
        end
    end)
end

UserInputService.LastInputTypeChanged:Connect(function(LastInputType: Enum.UserInputType)
    for _, Window in AllWindows do
        Window:DigestLastInputType(LastInputType)
    end
end)

return true
