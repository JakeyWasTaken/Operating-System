const JDI = require("@vendor/JustDrawIt")
const JDICreate = require("@vendor/JustDrawIt/Create")
const CWindow = require("@kernel/Window/Window")
const WindowFactory = require("@kernel/Window/WindowFactory")
const ProcessScheduler = require("@kernel/Process/ProcessScheduler")

const e = JDI.create
const key = JDI.key
const is_vnode = JDICreate.is_vnode

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
        ClipsDescendants = true,

        BackgroundColor3 = Color3.new(0, 0, 0),

        function()
            local Error = ""

            local DrawCallback = Window:GetDrawCallback()
            if DrawCallback then
                local Ok, Result = ProcessScheduler.RunNonBlocking(DrawCallback)
                if is_vnode(Result) then
                    return Result
                elseif Ok then
                    Error = "Return value was not a VNode"
                else
                    Error = tostring(Result) or "Unable to cast error to string"
                end
            else
                Error = "Defines no draw callback"
            end

            return e "TextLabel" {
                Text = `Failed to draw window "{Handle}"\n\n{Error}`,
                Size = UDim2.fromScale(1, 1),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                BackgroundTransparency = 1,
                TextColor3 = Color3.new(1, 0.3, 0.3),
                TextWrapped = false,
                TextScaled = false,
                TextSize = 16,
                FontFace = Font.fromName("RobotoMono", Enum.FontWeight.Bold),
                TextXAlignment = Enum.TextXAlignment.Center,
                TextYAlignment = Enum.TextYAlignment.Center,
            }
        end,

        -- When we interact with a window, we need to focus it
        e "TextButton" {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            ClipsDescendants = false,
            Selectable = false,
            Text = "",

            InputBegan = function(Input: InputObject)
                if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Keyboard then
                    return
                end

                WindowFactory.SetFocused(Handle, true)
            end
        }
    }
end
