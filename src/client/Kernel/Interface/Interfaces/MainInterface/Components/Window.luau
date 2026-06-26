const JDI = require("@vendor/JustDrawIt")
const CWindow = require("@kernel/Window/Window")

const e = JDI.create
const key = JDI.key

type CWindow = CWindow.CWindow

return function(Handle: string, Window: CWindow)
    local function GetSize()
        local WindowSize = Window:GetSize()
        return UDim2.fromOffset(WindowSize.X, WindowSize.Y)
    end

    local function GetPosition()
        local WindowPosition = Window:GetPosition()
        return UDim2.fromOffset(WindowPosition.X, WindowPosition.Y)
    end

    return e "Frame" {
        key(Handle),
        Name = `Window-{Handle}`,

        Size = GetSize,
        Position = GetPosition,
        AnchorPoint = Vector2.zero,
        ZIndex = Window:GetZIndex(),

        BackgroundColor3 = Color3.new(1, 1, 1)
    }
end
