const JDI = require("@vendor/JustDrawIt")
const WindowFactory = require("@kernel/Window/WindowFactory")
const WindowComponent = require("./Components/Window")

const e = JDI.create

local MainInterface = {}

function MainInterface.Draw()
    return e "Frame" {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),

        function()
            local Windows = {}

            for Handle, Window in WindowFactory.GetAllWindows() do
                table.insert(Windows, WindowComponent(Handle, Window))
            end

            return Windows
        end
    }
end

return MainInterface
