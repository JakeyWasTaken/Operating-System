local fs = require("@lune/fs")
local process = require("@lune/process")
local task = require("@lune/task")

print("Installing packages")

process.exec("rokit", { "install" }, { stdio = "forward" })

print("Clearing old build")

if fs.isDir("./build") then
	fs.removeDir("./build")
end

print("Building darklua config")

process.exec("lune", { "run", "scripts/darkluaconfig" }, { stdio = "forward" })

print("Building vscode aliases")

process.exec("lune", { "run", "scripts/alias-builder" }, { stdio = "forward" })

print("Starting darklua watch")

task.spawn(process.exec, "./dev.bat", {}, { stdio = "forward" })

print("Starting server")

repeat
	task.wait()
until fs.isDir("./build") and fs.isDir("./build/client") and fs.isDir("./build/server")

task.wait()

print("Starting rojo")

process.exec("rojo", {
	"serve",
	"build.project.json",
}, { stdio = "forward" })
