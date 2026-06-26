-- The reconciler. dom(draw) holds onto a tree of RNodes (one per live Instance)
-- and on each step() reruns draw and walks the new VNode tree against it, keeping
-- Instances where it can and only writing properties that actually changed.

local Runtime = require("./Runtime")
local Create = require("./Create")

type VNode = Create.VNode

-- the live counterpart of a VNode: the real Instance plus enough bookkeeping to
-- diff it next frame
type RNode = {
    instance: Instance,
    class: string,
    key: unknown?,
    -- last value written for each property, so we can skip unchanged ones
    applied: { [string]: unknown },
    connections: { [string]: RBXScriptConnection },
    handlers: { [string]: (...any) -> () },
    children: { RNode },
    -- the keyed children again, looked up by key
    keyed: { [unknown]: RNode },
}

export type Dom = {
    step: (target: Instance) -> (),
    destroy: () -> (),
}

local reconcile -- forward declaration (RNode? , VNode, parent) -> RNode

local function destroy_rnode(rnode: RNode)
    for _, child in rnode.children do
        destroy_rnode(child)
    end
    for _, connection in rnode.connections do
        connection:Disconnect()
    end
    rnode.instance:Destroy()
end

-- push vnode's properties onto rnode's Instance, skipping anything unchanged
local function apply(rnode: RNode, vnode: VNode)
    local instance = rnode.instance :: any
    local applied = rnode.applied
    local handlers = rnode.handlers

    local seen: { [string]: true } = {}

    for property, value in vnode.properties do
        seen[property] = true

        if type(value) == "function" then
            if typeof(instance[property]) == "RBXScriptSignal" then
                -- event listener: connect once, always call the latest closure
                handlers[property] = value :: any
                if not rnode.connections[property] then
                    rnode.connections[property] = instance[property]:Connect(function(...)
                        local handler = rnode.handlers[property]
                        if handler then
                            return handler(...)
                        end
                        return nil
                    end)
                end
            else
                -- derived value: recompute each frame, write only on change
                local derived = (value :: () -> unknown)()
                if applied[property] ~= derived then
                    instance[property] = derived
                    applied[property] = derived
                end
            end
        else
            if applied[property] ~= value then
                instance[property] = value
                applied[property] = value
            end
        end
    end

    -- drop event listeners that are no longer present
    for property in handlers do
        if not seen[property] then
            rnode.connections[property]:Disconnect()
            rnode.connections[property] = nil :: any
            handlers[property] = nil :: any
        end
    end
end

local function reconcile_children(rnode: RNode, vnode: VNode)
    local old = rnode.children
    local old_keyed = rnode.keyed

    local new_children: { RNode } = {}
    local new_keyed: { [unknown]: RNode } = {}
    local reused: { [RNode]: true } = {}

    for index, child_vnode in vnode.children do
        local match: RNode?

        if child_vnode.key ~= nil then
            match = old_keyed[child_vnode.key]
        else
            local candidate = old[index]
            -- only positional-match a child that wasn't given a key and is free
            if candidate and candidate.key == nil and not reused[candidate] then
                match = candidate
            end
        end

        if match and reused[match] then
            match = nil -- already claimed by an earlier sibling
        end

        local child = reconcile(match, child_vnode, rnode.instance)
        reused[child] = true
        new_children[index] = child

        if child_vnode.key ~= nil then
            new_keyed[child_vnode.key] = child
        end
    end

    -- destroy anything left over from last frame
    for _, child in old do
        if not reused[child] then
            destroy_rnode(child)
        end
    end

    rnode.children = new_children
    rnode.keyed = new_keyed
end

function reconcile(rnode: RNode?, vnode: VNode, parent: Instance): RNode
    -- mismatched (or missing) node: build a fresh one
    if rnode == nil or rnode.class ~= vnode.class then
        if rnode then
            destroy_rnode(rnode)
        end

        local fresh: RNode = {
            instance = Instance.new(vnode.class :: any),
            class = vnode.class,
            key = vnode.key,
            applied = {},
            connections = {},
            handlers = {},
            children = {},
            keyed = {},
        }

        apply(fresh, vnode)
        reconcile_children(fresh, vnode)
        fresh.instance.Parent = parent
        return fresh
    end

    -- same class: reuse and diff in place
    rnode.key = vnode.key
    apply(rnode, vnode)
    reconcile_children(rnode, vnode)
    return rnode
end

local function dom(draw: () -> Instance): Dom
    local root: RNode? = nil

    local self = {} :: Dom

    function self.step(target: Instance)
        Runtime.active += 1
        local ok, result = pcall(draw)
        Runtime.active -= 1

        if not ok then
            error(`error while drawing dom:\n{result}`, 0)
        end

        -- draw's return is typed as an Instance, but it's really the VNode from e
        root = reconcile(root, result :: any, target)
    end

    function self.destroy()
        if root then
            destroy_rnode(root)
            root = nil
        end
    end

    return self
end

return {
    dom = dom,
}
