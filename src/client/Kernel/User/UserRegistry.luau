type User = {
	Id: number,
	Name: string,
	Elevated: boolean,
}

local GetNextUserId: () -> number
do
	local Counter = 0

	GetNextUserId = function()
		Counter += 1
		return Counter
	end
end

local UserRegistry = {}

function UserRegistry.MakeUser(Name: string, Elevated: boolean): number
	local User = {
		Id = GetNextUserId(),
		Name = Name,
		Elevated = Elevated,
	}

	return User.Id
end

return UserRegistry
