@echo off

del /s /q build
start /b npx nodemon --watch src -d 1 -e lua,luau --exec "rojo sourcemap default.project.json --output sourcemap.json"
start /b npx nodemon --watch src -e lua,luau --exec "lune run scripts/darkluaconfig"
start /b npx nodemon --watch src -e lua,luau --exec "darklua process src/ build/"
