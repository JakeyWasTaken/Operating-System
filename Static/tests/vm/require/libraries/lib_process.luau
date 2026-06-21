local Ok, process = pcall(require, "@process")
assert(Ok, `Missing process library`)

assert(process.GetPID(), `lib process should return PID`)

return "OK"
