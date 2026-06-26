-- mount(dom, target) draws once and then again every Heartbeat. Returns a
-- function that stops the loop and tears down everything the dom built.

local Dom = require("./Dom")

type Dom = Dom.Dom

local RunService = game and game:GetService("RunService")

local function mount(dom: Dom, target: Instance): () -> ()
    dom.step(target) -- draw once now so we're not blank until the next frame

    local connection: RBXScriptConnection? = if RunService
        then RunService.Heartbeat:Connect(function()
            dom.step(target)
        end)
        else nil

    return function()
        if connection then
            connection:Disconnect()
            connection = nil
        end
        dom.destroy()
    end
end

return {
    mount = mount,
}
