--[[
	Flappy bird
]]

local fs = require("@osiris/fs")
local window = require("@osiris/window")

local create = window.Graphics.Create

local Flappy = {}

--////////////////////////////////////////////////////////////
-- CONFIG
--////////////////////////////////////////////////////////////

local TOP_INSET = 58

local GRAVITY = 1400
local JUMP_VELOCITY = -420
local PIPE_SPEED = 220

local PIPE_GAP = 160
local PIPE_WIDTH = 90
local PIPE_SPAWN_INTERVAL = 1.6

local DUCK_SIZE = Vector2.new(40, 30)

local TEXT_COLOR = Color3.fromRGB(230, 230, 230)
local BG = Color3.fromRGB(18, 18, 22)

local DUCK_IMAGE = "rbxassetid://81771554423726"
local PIPE_IMAGE = "rbxassetid://16704603198"

local HIGH_SCORE_PATH = "/tmp/flappy_highscore.dat"

--////////////////////////////////////////////////////////////
-- STATE
--////////////////////////////////////////////////////////////

local function readHighScore()
	local h = fs.Open(HIGH_SCORE_PATH)
	if not h then
		return 0
	end

	local data = fs.Read(h) or "0"
	fs.Close(h)

	return tonumber(data) or 0
end

local function writeHighScore(v: number)
	local old = fs.Open(HIGH_SCORE_PATH)
	if old then
		fs.Close(old)
		fs.Delete(HIGH_SCORE_PATH)
	end

	fs.CreateFile(HIGH_SCORE_PATH)
	local h = fs.Open(HIGH_SCORE_PATH)
	if not h then
		return
	end

	fs.Write(h, tostring(v), 0)
	fs.Close(h)
end

--////////////////////////////////////////////////////////////
-- GAME
--////////////////////////////////////////////////////////////

function Flappy.Open()
	local handle = assert(window.Create())
	local input = assert(window.GetInputContext(handle))

	window.SetFullscreen(handle, true)
	window.SetFocused(handle, true)
	window.BringToTop(handle)

	-- state
	local mode = "menu" -- menu | game
	local closed = false

	local duckPos = Vector2.new(140, 300)
	local duckVel = 0

	local pipes = {}
	local spawnTimer = 0

	local score = 0
	local highScore = readHighScore()

	--////////////////////////////////////////////////////////////
	-- INPUT
	--////////////////////////////////////////////////////////////

	input.InputBegan:Connect(function(i)
		if i.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		if i.KeyCode == Enum.KeyCode.Space then
			if mode == "menu" then
				mode = "game"
				score = 0
				duckPos = Vector2.new(140, 300)
				duckVel = 0
				pipes = {}
				spawnTimer = 0
				return
			end

			if mode == "game" then
				duckVel = JUMP_VELOCITY
			end
		end

		if i.KeyCode == Enum.KeyCode.Escape then
			exit(0)
		end
	end)

	--////////////////////////////////////////////////////////////
	-- LOGIC
	--////////////////////////////////////////////////////////////

	local function spawnPipe()
		local height = math.random(120, 420)
		table.insert(pipes, {
			x = 900,
			height = height,
			scored = false,
		})
	end

	local function resetToMenu()
		mode = "menu"

		if score > highScore then
			highScore = score
			writeHighScore(highScore)
		end
	end

	local function update(dt)
		if mode ~= "game" then
			return
		end

		-- physics
		duckVel += GRAVITY * dt
		duckPos += Vector2.new(0, duckVel * dt)

		-- spawn
		spawnTimer += dt
		if spawnTimer >= PIPE_SPAWN_INTERVAL then
			spawnTimer = 0
			spawnPipe()
		end

		-- move pipes
		for _, p in ipairs(pipes) do
			p.x -= PIPE_SPEED * dt

			-- score pass
			if not p.scored and p.x < duckPos.X then
				p.scored = true
				score += 1
			end
		end

		-- cleanup
		while pipes[1] and pipes[1].x < -120 do
			table.remove(pipes, 1)
		end

		-- collision
		local dw, dh = DUCK_SIZE.X, DUCK_SIZE.Y

		for _, p in ipairs(pipes) do
			local px = p.x
			local gapTop = p.height
			local gapBottom = p.height + PIPE_GAP

			local dx = duckPos.X
			local dy = duckPos.Y

			local hitX = dx + dw > px and dx < px + PIPE_WIDTH
			local hitY = dy < gapTop or dy + dh > gapBottom

			if hitX and hitY then
				resetToMenu()
				return
			end
		end

		if duckPos.Y < 0 or duckPos.Y > 700 then
			resetToMenu()
		end
	end

	--////////////////////////////////////////////////////////////
	-- DRAW
	--////////////////////////////////////////////////////////////

	window.SetDrawCallback(handle, function()
		return create("Frame")({
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = BG,
			BorderSizePixel = 0,

			create("Frame")({
				Size = UDim2.new(1, 0, 1, -TOP_INSET),
				Position = UDim2.fromOffset(0, TOP_INSET),
				BackgroundTransparency = 1,

				-- HUD
				create("TextLabel")({
					Text = "Score: " .. score .. "   Best: " .. highScore,
					Size = UDim2.new(1, 0, 0, 40),
					BackgroundTransparency = 1,
					TextColor3 = TEXT_COLOR,
					TextSize = 18,
					ZIndex = 50000,
				}),

				function()
					-- menu overlay
					if mode == "menu" then
						return create("TextLabel")({
							Text = "Press SPACE to start\nPress ESC to exit\n\n\nSource located at /bin/flappy.luau",
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							TextColor3 = TEXT_COLOR,
							TextSize = 26,
						})
					else
						return create("Frame")({
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,

							-- duck
							create("ImageLabel")({
								Position = UDim2.fromOffset(duckPos.X, duckPos.Y),
								Size = UDim2.fromOffset(DUCK_SIZE.X, DUCK_SIZE.Y),
								BackgroundTransparency = 1,
								Image = DUCK_IMAGE,
							}),

							-- pipes
							function()
								local t = {}

								for _, p in ipairs(pipes) do
									-- top pipe
									table.insert(
										t,
										create("ImageLabel")({
											Position = UDim2.fromOffset(p.x, 0),
											Size = UDim2.fromOffset(PIPE_WIDTH, p.height),
											BackgroundTransparency = 1,
											Image = PIPE_IMAGE,
										})
									)

									-- bottom pipe
									table.insert(
										t,
										create("ImageLabel")({
											Position = UDim2.fromOffset(p.x, p.height + PIPE_GAP),
											Size = UDim2.fromOffset(PIPE_WIDTH, 700),
											BackgroundTransparency = 1,
											Image = PIPE_IMAGE,
										})
									)
								end

								return t
							end,
						})
					end
				end,
			}),
		})
	end)

	--////////////////////////////////////////////////////////////
	-- LOOP
	--////////////////////////////////////////////////////////////

	local last = os.clock()

	task.spawn(function()
		while not closed do
			local now = os.clock()
			local dt = now - last
			last = now

			update(dt)
			task.wait()
		end
	end)

	while not closed do
		task.wait()
	end

	window.Destroy(handle)
end

Flappy.Open()
