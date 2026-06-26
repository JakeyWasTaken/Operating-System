const JDI = require("@vendor/JustDrawIt")
const e = JDI.create

local Text = ""
local BootInterface = {}

function BootInterface.PushString(String: string)
    Text ..= `\n{String}`
end

function BootInterface.Clear()
    Text = ""
end

function BootInterface.Draw()
    --stylua: ignore
    return e "TextLabel" {
        Text = Text,
        Size = UDim2.fromScale(1, 1),
        AnchorPoint = Vector2.new(0, 1),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.fromScale(0, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        TextColor3 = Color3.new(1, 1, 1),
        TextWrapped = false,
        TextScaled = false,
        TextSize = 14,
        FontFace = Font.fromName("RobotoMono", Enum.FontWeight.Medium),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,

        e "UIPadding" {
           PaddingLeft = UDim.new(0, 5),
           PaddingRight = UDim.new(0, 5),
           PaddingTop = UDim.new(0, 5)
        }
    }
end

return BootInterface
