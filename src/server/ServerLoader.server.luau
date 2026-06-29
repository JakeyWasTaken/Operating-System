const HttpService = game:GetService("HttpService")

const RequestFunction = Instance.new("RemoteFunction")
RequestFunction.Name = "RequestAsync"
RequestFunction.Parent = workspace

RequestFunction.OnServerInvoke = function(Player, Options)
    return HttpService:RequestAsync(Options)
end
