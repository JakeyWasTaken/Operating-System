local HttpService = game:GetService("HttpService")

export type Handle = string

return function(Size: number?)
	return HttpService:GenerateGUID(false):gsub("-", ""):sub(1, Size or 16)
end
