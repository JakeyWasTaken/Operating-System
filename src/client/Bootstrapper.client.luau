const FileSystem = require("@kernel/File/FileSystem")
const CPath = require("@kernel/File/Path")
const Context = require("@kernel/File/Context")

print(FileSystem:GetInstance():Create(CPath.new("/hello/world/test.exe", Context.new())))

-- local FileSystem = require("@kernel/FileSystem"):GetInstance()

-- print(FileSystem:Resolve("/").Value:ListChildren())

-- local CPath = require("@kernel/File/Path")

-- local function Test(str: string)
-- 	local path = CPath.new(str)

-- 	print("----------")

-- 	print(path:IsValid())
-- 	print(path:GetExtension())
-- 	print(path:GetType())
-- 	print(path:GetPathType())
-- 	print(path:ToString())
-- 	print(path:ToStringAbsolute(require("@kernel/File/Context").new()))
-- end

-- Test("~/Test")
-- Test("~/")
-- Test("~")
-- Test("~/Test/Cool.exe")
-- Test("./Test")
-- Test("./")
-- Test(".")
-- Test("./Test/Cool.exe")
-- Test(".../Test")
-- Test(".../")
-- Test("...")
-- Test(".../Test/Cool.exe")
-- Test("/Test")
-- Test("/")
-- Test("")
-- Test("/Test/Cool.exe")
-- Test("Test")
-- Test("Test/Cool.exe")
-- Test(".minecraft/minecraft.exe")
