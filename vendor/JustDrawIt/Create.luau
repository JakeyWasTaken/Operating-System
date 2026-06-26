-- e "Class" { ... } builds a VNode. It doesn't make any Instances; that's the
-- dom's job. The type stuff at the bottom (Properties/Instances/Create) is lifted
-- from Vide so the property table is typed against the class name.

local Runtime = require("./Runtime")

-- tags so we can tell our elements and key() markers apart from plain child
-- tables when walking the array part
local VNODE_MT = { __tostring = function() return "JustDrawIt.VNode" end }
local KEY_MT = { __tostring = function() return "JustDrawIt.Key" end }

export type VNode = {
    class: string,
    -- every string key goes here as-is. Whether a value is a plain property, a
    -- derived value or an event listener is decided by the dom, which is the
    -- first place we actually have an Instance to check against.
    properties: { [string]: unknown },
    children: { VNode },
    key: unknown?,
}

-- key(value) tags an element with a stable identity so the dom can follow it
-- across frames when it moves around. goes in the array part.
local function key(value: unknown): unknown
    return setmetatable({ value = value }, KEY_MT)
end

-- turn one array-part entry into children on node
local function collect(value: unknown, node: VNode)
    local kind = type(value)

    if kind == "function" then
        -- functions in the array part return children
        collect((value :: () -> unknown)(), node)
    elseif kind == "table" then
        local mt = getmetatable(value :: any)
        if mt == VNODE_MT then
            table.insert(node.children, value :: any)
        elseif mt == KEY_MT then
            node.key = (value :: any).value
        else
            -- plain array of children
            for _, item in value :: { unknown } do
                collect(item, node)
            end
        end
    end
    -- numbers, nil, etc. in the array part don't mean anything
end

local function create_node(class: string, properties: { [unknown]: unknown }): VNode
    if Runtime.active <= 0 then
        error("attempt to create an element outside of a dom; all elements must be created within a dom's draw function", 0)
    end

    local node: VNode = (setmetatable({
        class = class,
        properties = {},
        children = {},
        key = nil,
    }, VNODE_MT) :: any)

    for k, v in properties do
        if type(k) == "string" then
            node.properties[k] = v
        elseif type(k) == "number" then
            collect(v, node)
        end
    end

    return node
end

local function create(class: string)
    return function(properties: { [unknown]: unknown }): VNode
        return create_node(class, properties)
    end
end

local function is_vnode(value: unknown): boolean
    return type(value) == "table" and getmetatable(value :: any) == VNODE_MT
end

type Instances = {
    Folder: Folder,
    BillboardGui: BillboardGui,
    CanvasGroup: CanvasGroup,
    Frame: Frame,
    ImageButton: ImageButton,
    ImageLabel: ImageLabel,
    ScreenGui: ScreenGui,
    ScrollingFrame: ScrollingFrame,
    SurfaceGui: SurfaceGui,
    TextBox: TextBox,
    TextButton: TextButton,
    TextLabel: TextLabel,
    UIAspectRatioConstraint: UIAspectRatioConstraint,
    UICorner: UICorner,
    UIGradient: UIGradient,
    UIGridLayout: UIGridLayout,
    UIListLayout: UIListLayout,
    UIPadding: UIPadding,
    UIScale: UIScale,
    UISizeConstraint: UISizeConstraint,
    UIStroke: UIStroke,
    UITextSizeConstraint: UITextSizeConstraint,
    Camera: Camera,
    WorldModel: WorldModel,
}

type function Properties(instance: type?)
    local properties = types.newtable()

    while instance do
        for i, v in instance:properties() do
            local connector = v.read and v.read.tag == "table" and v.read:readproperty(types.singleton("Connect"))
            if connector then
                local params = connector:parameters().head
                if not params then continue end
                local listener = params[2]
                if not listener then continue end
                properties:setproperty(i, types.optional(listener))
            elseif v.write then
                properties:setproperty(i, types.optional(types.unionof(
                    v.write,
                    types.newfunction({}, { head = { v.write } })
                )))
            end
        end

        instance = instance:readparent()
    end

    properties:setindexer(types.number, types.any)

    return properties
end

-- e "Frame" { ... } types as a Frame even though it's a VNode underneath. The lie
-- is worth it: you get property autocomplete and draws compose like real Instances.
type Create = <Name>(Name | keyof<Instances> | "") -> (Properties<index<Instances, Name>>) -> index<Instances, Name>

return {
    create = (create :: any) :: Create,
    key = key,
    is_vnode = is_vnode,
}
