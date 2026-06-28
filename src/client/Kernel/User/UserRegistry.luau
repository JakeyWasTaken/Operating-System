const FileSystemManager = require("@kernel/File/FileSystemManager")
const FileContext = require("@kernel/File/FileContext")
const CFilePath = require("@kernel/File/FilePath")

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

local AllUsers: {[number]: User?} = {}

local UserRegistry = {}

function UserRegistry.MakeUser(Name: string, Elevated: boolean): User?
    const FileSystem = FileSystemManager.GetActiveFileSystem()
    if not FileSystem then
        warn(`File system wasn't ready to make user`)
        return
    end

    local Failed = false
    local Errors = {}

    local function TryMake(Path: string)
        local Result = FileSystem:CreateDirectory(CFilePath.new(`/users/{Name}{Path}`), FileContext())
        if not Result.Success then
            table.insert(Errors, Result.Reason)
            Failed = true
        end
    end

    -- Create all the directories needed for a user

    TryMake("")
    TryMake("/home")
    TryMake("/bin")

    if Failed then
        warn(table.concat(Errors, "\n"))
        return
    end

    local User = {
        Id = GetNextUserId(),
        Name = Name,
        Elevated = Elevated
    }

    AllUsers[User.Id] = User
    return User
end

function UserRegistry.GetUser(UserId: number): User?
    return AllUsers[UserId]
end

function UserRegistry.GetUserDirectory(UserId: number): string?
    local User = AllUsers[UserId]
    if not User then
        return
    end

    return `/users/{User.Name}`
end

return UserRegistry
