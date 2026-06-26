-- Just Draw It, an immediate-mode UI library for Roblox. See the README for the
-- whole story; the short version:
--
--     local jdi = require(path.to.JustDrawIt)
--     local e, dom, mount = jdi.create, jdi.dom, jdi.mount
--
--     local function draw()
--         return e "ScreenGui" {
--             e "TextLabel" { Text = "Hi!" },
--         }
--     end
--
--     mount( dom(draw), playerGui )

local Create = require("@self/Create")
local Dom = require("@self/Dom")
local Mount = require("@self/Mount")

export type VNode = Create.VNode
export type Dom = Dom.Dom

return {
	create = Create.create,
	key = Create.key,
	dom = Dom.dom,
	mount = Mount.mount,
}
