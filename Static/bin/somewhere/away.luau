print(require("@osiris/process").GetPID())

print("AWAY")

task.delay(3, function()
	print("deferred")
end)

wait(10)

return true
