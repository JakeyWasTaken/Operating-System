--- Should require all the overlays so they are rendered
local Overlays = {
    require("@self/Process")
}

for _, Overlay in Overlays do
	assert(type(Overlay.Render) == "function", "Overlay must have a Render function")
end

return Overlays
