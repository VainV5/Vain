-- Vain — Universal Module
-- Runs on every game. Features ported from CatV6 by MaxlaserTech.

local vain = shared.vain
local cloneref = cloneref or function(obj) return obj end

local playersService  = cloneref(game:GetService('Players'))
local runService      = cloneref(game:GetService('RunService'))
local inputService    = cloneref(game:GetService('UserInputService'))
local teleportService = cloneref(game:GetService('TeleportService'))
local lightingService = cloneref(game:GetService('Lighting'))
local httpService     = cloneref(game:GetService('HttpService'))
local proxService     = cloneref(game:GetService('ProximityPromptService'))
local statsService    = cloneref(game:GetService('Stats'))
local lplr            = playersService.LocalPlayer

-- ── Categories ─────────────────────────────────────────────────────────────────
local Combat  = vain.Categories.Combat
local Blatant = vain.Categories.Blatant
local Render  = vain.Categories.Render
local Utility = vain.Categories.Utility
local World   = vain.Categories.World
local Legit   = vain.Categories.Legit or vain.Categories.Utility

-- ── Shared helpers ─────────────────────────────────────────────────────────────
local function getHRP()
	local char = lplr.Character
	return char and char:FindFirstChild('HumanoidRootPart')
end

local function getHum()
	local char = lplr.Character
	return char and char:FindFirstChildOfClass('Humanoid')
end

local function getLivingPlayers()
	local t = {}
	for _, p in playersService:GetPlayers() do
		if p ~= lplr and p.Character and p.Character:FindFirstChild('HumanoidRootPart') then
			table.insert(t, p)
		end
	end
	return t
end

-- Drawing availability guard
local DrawingAvailable = (typeof(Drawing) == 'table' or typeof(Drawing) == 'userdata')

-- ── BLATANT ────────────────────────────────────────────────────────────────────

do
-- Speed
local speedEnabled = false
local speedValue   = 25
local speedConn

local speedModule = Blatant:CreateModule({
	Name    = 'Speed',
	Tooltip = 'Increases your walk speed',
	Bind    = {},
	Function = function(enabled)
		speedEnabled = enabled
		local hum = getHum()
		if enabled then
			if hum then hum.WalkSpeed = speedValue end
			speedConn = lplr.CharacterAdded:Connect(function(char)
				local h = char:WaitForChild('Humanoid', 5)
				if h and speedEnabled then h.WalkSpeed = speedValue end
			end)
		else
			if hum then hum.WalkSpeed = 16 end
			if speedConn then speedConn:Disconnect(); speedConn = nil end
		end
	end,
})

speedModule:CreateSlider({
	Name    = 'Speed',
	Min     = 1,
	Max     = 150,
	Default = 25,
	Function = function(val)
		speedValue = val
		if speedEnabled then
			local hum = getHum()
			if hum then hum.WalkSpeed = val end
		end
	end,
})
end

do
-- Infinite Jump
local ijConn

local infiniteJump = Blatant:CreateModule({
	Name    = 'Infinite Jump',
	Tooltip = 'Jump unlimited times in the air',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			ijConn = inputService.JumpRequest:Connect(function()
				local hum = getHum()
				if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
			end)
		else
			if ijConn then ijConn:Disconnect(); ijConn = nil end
		end
	end,
})
local _ = infiniteJump
end

do
-- High Jump
local hjVelocity = 80
local hjConn

local highJump = Blatant:CreateModule({
	Name    = 'High Jump',
	Tooltip = 'Greatly boosts jump height when you press jump',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			hjConn = inputService.JumpRequest:Connect(function()
				local hrp = getHRP()
				local hum = getHum()
				if not hrp or not hum then return end
				if hum.FloorMaterial ~= Enum.Material.Air then
					hrp.AssemblyLinearVelocity = Vector3.new(
						hrp.AssemblyLinearVelocity.X,
						hjVelocity,
						hrp.AssemblyLinearVelocity.Z
					)
				end
			end)
		else
			if hjConn then hjConn:Disconnect(); hjConn = nil end
		end
	end,
})

highJump:CreateSlider({
	Name    = 'Velocity',
	Min     = 1,
	Max     = 150,
	Default = 80,
	Function = function(val) hjVelocity = val end,
})
end

do
-- Anti Fall — places an invisible platform below you when falling
local antiFallConn
local antiFallPart

local antiFall = Blatant:CreateModule({
	Name    = 'Anti Fall',
	Tooltip = 'Creates an invisible platform below you to prevent fall damage',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			antiFallPart = Instance.new('Part')
			antiFallPart.Size        = Vector3.new(1, 1, 1)
			antiFallPart.Anchored    = true
			antiFallPart.CanCollide  = false
			antiFallPart.Transparency = 1
			antiFallPart.Parent      = workspace

			antiFallConn = runService.Heartbeat:Connect(function()
				local hrp = getHRP()
				if not hrp then return end
				local vy = hrp.AssemblyLinearVelocity.Y
				if vy < -5 then
					antiFallPart.CanCollide = true
					antiFallPart.Size   = Vector3.new(8, 0.2, 8)
					antiFallPart.CFrame = CFrame.new(hrp.Position - Vector3.new(0, 3, 0))
				else
					antiFallPart.CanCollide = false
					antiFallPart.Size = Vector3.new(1, 1, 1)
				end
			end)
		else
			if antiFallConn then antiFallConn:Disconnect(); antiFallConn = nil end
			if antiFallPart  then antiFallPart:Destroy();  antiFallPart  = nil end
		end
	end,
})
local _ = antiFall
end

do
-- Long Jump — launches you forward on jump
local ljSpeed = 80
local ljConn

local longJump = Blatant:CreateModule({
	Name    = 'Long Jump',
	Tooltip = 'Launches you forward when you press jump',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			ljConn = inputService.JumpRequest:Connect(function()
				local hrp = getHRP()
				local hum = getHum()
				if not hrp or not hum then return end
				if hum.FloorMaterial ~= Enum.Material.Air then
					local cam     = workspace.CurrentCamera
					local forward = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
					if forward.Magnitude > 0 then
						hrp.AssemblyLinearVelocity = forward.Unit * ljSpeed + Vector3.new(0, 50, 0)
					end
				end
			end)
		else
			if ljConn then ljConn:Disconnect(); ljConn = nil end
		end
	end,
})

longJump:CreateSlider({
	Name    = 'Speed',
	Min     = 1,
	Max     = 150,
	Default = 80,
	Function = function(val) ljSpeed = val end,
})
end

do
-- Hit Boxes — inflates player hitboxes
local hitboxEnabled = false
local hitboxSize    = 5

local function applyHB(char)
	for _, part in char:GetDescendants() do
		if part:IsA('BasePart') and part.Name ~= 'HumanoidRootPart' then
			if not part:GetAttribute('_hbOrig') then
				part:SetAttribute('_hbOrig', part.Size)
			end
			part.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
		end
	end
end

local function restoreHB(char)
	for _, part in char:GetDescendants() do
		if part:IsA('BasePart') then
			local orig = part:GetAttribute('_hbOrig')
			if orig then
				part.Size = orig
				part:SetAttribute('_hbOrig', nil)
			end
		end
	end
end

local hbConns = {}

local hitBoxes = Blatant:CreateModule({
	Name    = 'Hit Boxes',
	Tooltip = 'Expands player hitboxes so they are easier to hit',
	Bind    = {},
	Function = function(enabled)
		hitboxEnabled = enabled
		if enabled then
			for _, p in getLivingPlayers() do
				if p.Character then applyHB(p.Character) end
			end
			local c = playersService.PlayerAdded:Connect(function(p)
				p.CharacterAdded:Connect(function(char)
					task.wait(0.1)
					if hitboxEnabled then applyHB(char) end
				end)
			end)
			table.insert(hbConns, c)
		else
			for _, p in playersService:GetPlayers() do
				if p.Character then restoreHB(p.Character) end
			end
			for _, c in hbConns do pcall(c.Disconnect, c) end
			table.clear(hbConns)
		end
	end,
})

hitBoxes:CreateSlider({
	Name    = 'Size',
	Min     = 1,
	Max     = 20,
	Default = 5,
	Function = function(val)
		hitboxSize = val
		if hitboxEnabled then
			for _, p in getLivingPlayers() do
				if p.Character then applyHB(p.Character) end
			end
		end
	end,
})
end

-- ── COMBAT ─────────────────────────────────────────────────────────────────────

do
-- Aim Assist — smooth mouse pull toward nearest player in FOV
local aaEnabled         = false
local aaFov             = 100
local aaSpeed           = 15
local aaReqRightClick   = false
local aaShowCircle      = true
local aaConn

local aaCircle
if DrawingAvailable then
	aaCircle = Drawing.new('Circle')
	aaCircle.Visible     = false
	aaCircle.Color       = Color3.fromRGB(255, 255, 255)
	aaCircle.Thickness   = 1
	aaCircle.Radius      = aaFov
	aaCircle.Filled      = false
	aaCircle.NumSides    = 64
	vain:Clean(function() pcall(aaCircle.Remove, aaCircle) end)
end

local function getAimTarget()
	local cam = workspace.CurrentCamera
	if not cam then return nil end
	local vp     = cam.ViewportSize
	local center = Vector2.new(vp.X / 2, vp.Y / 2)
	local best, bestDist = nil, aaFov

	for _, p in getLivingPlayers() do
		local tHRP = p.Character:FindFirstChild('HumanoidRootPart')
		if not tHRP then continue end
		local sp, onScreen = cam:WorldToViewportPoint(tHRP.Position)
		if not onScreen then continue end
		local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
		if d < bestDist then best = tHRP; bestDist = d end
	end

	return best
end

local aimAssist = Combat:CreateModule({
	Name    = 'Aim Assist',
	Tooltip = 'Smoothly pulls your cursor toward the nearest player in your FOV',
	Bind    = {},
	Function = function(enabled)
		aaEnabled = enabled
		if aaCircle then aaCircle.Visible = enabled and aaShowCircle end

		if enabled then
			aaConn = runService.RenderStepped:Connect(function()
				local cam = workspace.CurrentCamera
				if not cam then return end

				if aaCircle and aaShowCircle then
					aaCircle.Position = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
				end

				if aaReqRightClick
					and not inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
					return
				end

				local target = getAimTarget()
				if not target then return end

				local sp = cam:WorldToViewportPoint(target.Position)
				local cx = cam.ViewportSize.X / 2
				local cy = cam.ViewportSize.Y / 2

				local dx = (sp.X - cx) / aaSpeed
				local dy = (sp.Y - cy) / aaSpeed

				if mousemoverel then mousemoverel(dx, dy) end
			end)
		else
			if aaConn then aaConn:Disconnect(); aaConn = nil end
		end
	end,
})

aimAssist:CreateSlider({
	Name    = 'FOV',
	Min     = 10,
	Max     = 500,
	Default = 100,
	Function = function(val)
		aaFov = val
		if aaCircle then aaCircle.Radius = val end
	end,
})

aimAssist:CreateSlider({
	Name    = 'Speed',
	Min     = 1,
	Max     = 30,
	Default = 15,
	Function = function(val) aaSpeed = val end,
})

aimAssist:CreateToggle({
	Name    = 'Require Right Click',
	Default = false,
	Function = function(val) aaReqRightClick = val end,
})

aimAssist:CreateToggle({
	Name    = 'Show FOV Circle',
	Default = true,
	Function = function(val)
		aaShowCircle = val
		if aaCircle then aaCircle.Visible = val and aaEnabled end
	end,
})
end

do
-- Auto Clicker
local acEnabled = false
local acMinCps  = 8
local acMaxCps  = 12
local acMode    = 'Tool'

local function getEquippedTool()
	local char = lplr.Character
	if not char then return end
	for _, v in char:GetChildren() do
		if v:IsA('Tool') then return v end
	end
end

local autoClicker = Combat:CreateModule({
	Name    = 'Auto Clicker',
	Tooltip = 'Automatically clicks at a randomized CPS rate',
	Bind    = {},
	Function = function(enabled)
		acEnabled = enabled
		if not enabled then return end
		task.spawn(function()
			while acEnabled do
				if acMode == 'Tool' then
					local tool = getEquippedTool()
					if tool then pcall(tool.Activate, tool) end
				elseif acMode == 'Click' then
					if mouse1click then mouse1click() end
				elseif acMode == 'RightClick' then
					if mouse2click then mouse2click() end
				end
				local cps = math.random(acMinCps, math.max(acMinCps, acMaxCps))
				task.wait(1 / cps)
			end
		end)
	end,
})

autoClicker:CreateDropdown({
	Name     = 'Mode',
	List     = {'Tool', 'Click', 'RightClick'},
	Function = function(val) acMode = val or 'Tool' end,
})

autoClicker:CreateSlider({
	Name    = 'Min CPS',
	Min     = 1,
	Max     = 20,
	Default = 8,
	Function = function(val) acMinCps = val end,
})

autoClicker:CreateSlider({
	Name    = 'Max CPS',
	Min     = 1,
	Max     = 20,
	Default = 12,
	Function = function(val) acMaxCps = val end,
})
end

do
-- Trigger Bot — fires when a player is in your crosshair
local tbDelay   = 0.08
local tbRange   = 15
local tbConn

local triggerBot = Combat:CreateModule({
	Name    = 'Trigger Bot',
	Tooltip = 'Automatically clicks when a player enters your crosshair',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			tbConn = runService.Heartbeat:Connect(function()
				local cam = workspace.CurrentCamera
				if not cam then return end

				local ray = cam:ScreenPointToRay(
					cam.ViewportSize.X / 2,
					cam.ViewportSize.Y / 2
				)
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = lplr.Character and {lplr.Character} or {}

				local result = workspace:Raycast(ray.Origin, ray.Direction * tbRange, params)
				if not result then return end

				for _, p in getLivingPlayers() do
					if p.Character and result.Instance:IsDescendantOf(p.Character) then
						task.wait(tbDelay)
						if mouse1press   then mouse1press()   end
						task.wait(0.05)
						if mouse1release then mouse1release() end
						return
					end
				end
			end)
		else
			if tbConn then tbConn:Disconnect(); tbConn = nil end
		end
	end,
})

triggerBot:CreateSlider({
	Name    = 'Delay (ms)',
	Min     = 0,
	Max     = 500,
	Default = 80,
	Function = function(val) tbDelay = val / 1000 end,
})

triggerBot:CreateSlider({
	Name    = 'Range',
	Min     = 1,
	Max     = 100,
	Default = 15,
	Function = function(val) tbRange = val end,
})
end

do
-- Reach — extends melee range via firetouchinterest
local reachRange   = 2
local reachConn

local reach = Combat:CreateModule({
	Name    = 'Reach',
	Tooltip = 'Extends your melee tool attack range',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			reachConn = runService.Heartbeat:Connect(function()
				local char = lplr.Character
				local hrp  = char and char:FindFirstChild('HumanoidRootPart')
				if not hrp then return end

				local tool   = char:FindFirstChildOfClass('Tool')
				local handle = tool and tool:FindFirstChild('Handle')
				if not handle then return end

				for _, p in getLivingPlayers() do
					local tHRP = p.Character:FindFirstChild('HumanoidRootPart')
					if not tHRP then continue end
					if (hrp.Position - tHRP.Position).Magnitude > (3 + reachRange) then continue end
					for _, part in p.Character:GetDescendants() do
						if part:IsA('BasePart') then
							pcall(firetouchinterest, handle, part, 0)
							pcall(firetouchinterest, handle, part, 1)
						end
					end
				end
			end)
		else
			if reachConn then reachConn:Disconnect(); reachConn = nil end
		end
	end,
})

reach:CreateSlider({
	Name    = 'Range',
	Min     = 0,
	Max     = 10,
	Default = 2,
	Function = function(val) reachRange = val end,
})
end

do
-- Killaura — attacks all players within range
local kaRange     = 10
local kaCooldowns = {}
local kaConn

local killaura = Combat:CreateModule({
	Name    = 'Killaura',
	Tooltip = 'Automatically attacks players within range',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			kaConn = runService.Heartbeat:Connect(function()
				local hrp  = getHRP()
				if not hrp then return end
				local char = lplr.Character
				local tool = char:FindFirstChildOfClass('Tool')
				local handle = tool and tool:FindFirstChild('Handle')
				local now  = os.clock()

				for _, p in getLivingPlayers() do
					local tHRP = p.Character:FindFirstChild('HumanoidRootPart')
					if not tHRP then continue end
					if (hrp.Position - tHRP.Position).Magnitude > kaRange then continue end
					if (kaCooldowns[p] or 0) + 0.5 > now then continue end
					kaCooldowns[p] = now

					if handle and firetouchinterest then
						for _, part in p.Character:GetDescendants() do
							if part:IsA('BasePart') then
								pcall(firetouchinterest, handle, part, 0)
								pcall(firetouchinterest, handle, part, 1)
							end
						end
					elseif tool then
						pcall(tool.Activate, tool)
					end
				end
			end)
		else
			if kaConn then kaConn:Disconnect(); kaConn = nil end
			table.clear(kaCooldowns)
		end
	end,
})

killaura:CreateSlider({
	Name    = 'Range',
	Min     = 1,
	Max     = 30,
	Default = 10,
	Function = function(val) kaRange = val end,
})
end

-- ── RENDER ─────────────────────────────────────────────────────────────────────

do
-- Universal Player ESP (Highlight-based — works through walls)
local espEnabled     = false
local espShowNames   = true
local espTeamColors  = false
local espFillTransp  = 0.7
local espOutlineTransp = 0.0

local espContainer = Instance.new('Folder')
espContainer.Name   = 'VainUniversalESP'
espContainer.Parent = (gethui and gethui()) or lplr:WaitForChild('PlayerGui')

local espObjs = {}   -- [player] = {highlight, billboard, label}

local ENEMY_COLOR = Color3.fromRGB(255, 80, 80)
local TEAM_COLOR  = Color3.fromRGB(80, 220, 80)

local function espColor(player)
	if espTeamColors then
		return (player.Team == lplr.Team) and TEAM_COLOR or ENEMY_COLOR
	end
	return ENEMY_COLOR
end

local function removeESP(player)
	local objs = espObjs[player]
	if not objs then return end
	for _, obj in objs do
		if typeof(obj) ~= 'string' then pcall(obj.Destroy, obj) end
	end
	espObjs[player] = nil
end

local function buildESP(player)
	if not espEnabled or player == lplr then return end
	local char = player.Character
	if not char then return end
	local hrp  = char:FindFirstChild('HumanoidRootPart')
	if not hrp  then return end

	local objs = espObjs[player] or {}
	espObjs[player] = objs
	local col = espColor(player)

	local hl = objs.highlight
	if not hl or not hl.Parent then
		hl = Instance.new('Highlight')
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Parent    = espContainer
		objs.highlight = hl
	end
	hl.Adornee             = char
	hl.FillColor           = col
	hl.OutlineColor        = col
	hl.FillTransparency    = espFillTransp
	hl.OutlineTransparency = espOutlineTransp

	local bb = objs.billboard
	if not bb or not bb.Parent then
		bb = Instance.new('BillboardGui')
		bb.Size         = UDim2.fromOffset(100, 24)
		bb.StudsOffset  = Vector3.new(0, 3, 0)
		bb.AlwaysOnTop  = true
		bb.ResetOnSpawn = false
		bb.Parent       = espContainer

		local lbl = Instance.new('TextLabel')
		lbl.Size                   = UDim2.fromScale(1, 1)
		lbl.BackgroundTransparency = 1
		lbl.TextStrokeTransparency = 0.4
		lbl.TextStrokeColor3       = Color3.new(0, 0, 0)
		lbl.TextSize               = 13
		lbl.Font                   = Enum.Font.GothamBold
		lbl.Parent                 = bb

		objs.billboard = bb
		objs.label     = lbl
	end
	bb.Adornee = hrp
	bb.Enabled = espShowNames
	if objs.label then
		objs.label.Text       = player.Name
		objs.label.TextColor3 = col
	end
end

local function refreshESP()
	for _, p in playersService:GetPlayers() do buildESP(p) end
end

local universalESP = Render:CreateModule({
	Name    = 'ESP',
	Tooltip = 'Highlights all players through walls with color-coded boxes',
	Bind    = {},
	Function = function(enabled)
		espEnabled = enabled
		if enabled then
			refreshESP()
		else
			for p in espObjs do removeESP(p) end
		end
	end,
})

universalESP:CreateToggle({
	Name    = 'Show Names',
	Default = true,
	Function = function(val)
		espShowNames = val
		for _, objs in espObjs do
			if objs.billboard then objs.billboard.Enabled = val end
		end
	end,
})

universalESP:CreateToggle({
	Name    = 'Team Colors',
	Default = false,
	Function = function(val)
		espTeamColors = val
		if espEnabled then refreshESP() end
	end,
})

universalESP:CreateSlider({
	Name    = 'Fill Opacity',
	Min     = 0,
	Max     = 100,
	Default = 30,
	Function = function(val)
		espFillTransp = 1 - (val / 100)
		for _, objs in espObjs do
			if objs.highlight then objs.highlight.FillTransparency = espFillTransp end
		end
	end,
})

universalESP:CreateSlider({
	Name    = 'Outline Opacity',
	Min     = 0,
	Max     = 100,
	Default = 100,
	Function = function(val)
		espOutlineTransp = 1 - (val / 100)
		for _, objs in espObjs do
			if objs.highlight then objs.highlight.OutlineTransparency = espOutlineTransp end
		end
	end,
})

vain:Clean(playersService.PlayerAdded:Connect(function(p)
	p.CharacterAdded:Connect(function() task.wait(0.15); buildESP(p) end)
end))
vain:Clean(playersService.PlayerRemoving:Connect(removeESP))
for _, p in playersService:GetPlayers() do
	p.CharacterAdded:Connect(function() task.wait(0.15); buildESP(p) end)
end
end

do
-- Tracers (Drawing API) — lines from screen center to each player
if DrawingAvailable then

local tracerColor   = Color3.fromRGB(255, 80, 80)
local tracerThick   = 1
local tracerLines   = {}
local tracerConn

local function getOrMakeLine(player)
	if not tracerLines[player] then
		local l = Drawing.new('Line')
		l.Visible     = false
		l.Color       = tracerColor
		l.Thickness   = tracerThick
		tracerLines[player] = l
	end
	return tracerLines[player]
end

local function destroyLine(player)
	local l = tracerLines[player]
	if l then pcall(l.Remove, l); tracerLines[player] = nil end
end

local tracers = Render:CreateModule({
	Name    = 'Tracers',
	Tooltip = 'Draws lines from the bottom of your screen to all players',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			tracerConn = runService.RenderStepped:Connect(function()
				local cam = workspace.CurrentCamera
				if not cam then return end
				local vp   = cam.ViewportSize
				local from = Vector2.new(vp.X / 2, vp.Y)

				for _, p in playersService:GetPlayers() do
					if p == lplr then continue end
					local line = getOrMakeLine(p)

					if not p.Character then line.Visible = false; continue end
					local tHRP = p.Character:FindFirstChild('HumanoidRootPart')
					if not tHRP then line.Visible = false; continue end

					local sp, onScreen = cam:WorldToViewportPoint(tHRP.Position)
					if not onScreen then line.Visible = false; continue end

					line.From    = from
					line.To      = Vector2.new(sp.X, sp.Y)
					line.Color   = tracerColor
					line.Thickness = tracerThick
					line.Visible = true
				end
			end)
		else
			if tracerConn then tracerConn:Disconnect(); tracerConn = nil end
			for p, _ in tracerLines do destroyLine(p) end
		end
	end,
})

tracers:CreateSlider({
	Name    = 'Thickness',
	Min     = 1,
	Max     = 5,
	Default = 1,
	Function = function(val) tracerThick = val end,
})

vain:Clean(playersService.PlayerRemoving:Connect(destroyLine))
vain:Clean(function()
	for p, _ in tracerLines do destroyLine(p) end
end)

end -- DrawingAvailable
end

do
-- FPS Boost — disables expensive visual effects
local origShadows
local origFogEnd

local fpsBoost = Render:CreateModule({
	Name    = 'FPS Boost',
	Tooltip = 'Disables shadows, fog, and heavy effects to improve framerate',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			origShadows = lightingService.GlobalShadows
			origFogEnd  = lightingService.FogEnd
			pcall(function() lightingService.GlobalShadows = false end)
			pcall(function() lightingService.FogEnd = 100000 end)
			for _, v in lightingService:GetChildren() do
				if v:IsA('BlurEffect') or v:IsA('SunRaysEffect')
					or v:IsA('ColorCorrectionEffect') or v:IsA('DepthOfFieldEffect') then
					v.Enabled = false
				end
			end
		else
			pcall(function() lightingService.GlobalShadows = origShadows ~= nil and origShadows or true end)
			pcall(function() lightingService.FogEnd = origFogEnd or 100000 end)
			for _, v in lightingService:GetChildren() do
				if v:IsA('BlurEffect') or v:IsA('SunRaysEffect')
					or v:IsA('ColorCorrectionEffect') or v:IsA('DepthOfFieldEffect') then
					v.Enabled = true
				end
			end
		end
	end,
})
local _ = fpsBoost
end

do
-- Zoom Unlocker
local zoomEnabled = false
local zoomMax     = 500
local origZoom

local zoomUnlocker = Render:CreateModule({
	Name    = 'Zoom Unlocker',
	Tooltip = 'Allows the camera to zoom out much further than the game limit',
	Bind    = {},
	Function = function(enabled)
		zoomEnabled = enabled
		if enabled then
			origZoom = origZoom or lplr.CameraMaxZoomDistance
			lplr.CameraMaxZoomDistance = zoomMax
		else
			lplr.CameraMaxZoomDistance = origZoom or 128
			origZoom = nil
		end
	end,
})

zoomUnlocker:CreateSlider({
	Name    = 'Max Distance',
	Min     = 10,
	Max     = 1000,
	Default = 500,
	Function = function(val)
		zoomMax = val
		if zoomEnabled then lplr.CameraMaxZoomDistance = val end
	end,
})
end

do
-- Time Changer
local timeEnabled = false
local origTime

local timeChanger = Render:CreateModule({
	Name    = 'Time Changer',
	Tooltip = 'Overrides the in-game time of day',
	Bind    = {},
	Function = function(enabled)
		timeEnabled = enabled
		if enabled then
			origTime = origTime or lightingService.ClockTime
		else
			if origTime then
				pcall(function() lightingService.ClockTime = origTime end)
				origTime = nil
			end
		end
	end,
})

timeChanger:CreateSlider({
	Name    = 'Time (hour)',
	Min     = 0,
	Max     = 24,
	Default = 12,
	Function = function(val)
		if timeEnabled then
			pcall(function() lightingService.ClockTime = val end)
		end
	end,
})
end

-- ── UTILITY ────────────────────────────────────────────────────────────────────

do
-- Server Hop — teleports to a different server
local function fetchServers(sortOrder)
	local url = ('https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=%s&limit=100')
		:format(game.PlaceId, sortOrder)
	local ok, res = pcall(game.HttpGet, game, url)
	if not ok then return nil end
	local ok2, data = pcall(httpService.JSONDecode, httpService, res)
	if not ok2 then return nil end
	return data
end

local hopSort = 'Desc'

local serverHop = Utility:CreateModule({
	Name         = 'Server Hop',
	Tooltip      = 'Teleports you to a different server',
	Notification = false,
	Bind         = {},
	Function = function(enabled)
		if not enabled then return end
		vain:CreateNotification('Vain', 'Looking for a server…', 3)

		task.spawn(function()
			local data = fetchServers(hopSort)
			if not data or not data.data then
				vain:CreateNotification('Vain', 'No servers found', 3, 'alert')
				return
			end
			for _, server in data.data do
				if server.id ~= game.JobId and (server.playing or 0) < (server.maxPlayers or 999) then
					pcall(function()
						teleportService:TeleportToPlaceInstance(game.PlaceId, server.id, lplr)
					end)
					return
				end
			end
			vain:CreateNotification('Vain', 'No suitable server found', 3, 'alert')
		end)
	end,
})

serverHop:CreateDropdown({
	Name     = 'Sort',
	List     = {'Desc', 'Asc'},
	Tooltip  = 'Desc = fill emptier servers, Asc = fill fuller servers',
	Function = function(val) hopSort = val or 'Desc' end,
})
end

do
-- Rejoin — rejoin the current server
Utility:CreateModule({
	Name         = 'Rejoin',
	Tooltip      = 'Rejoins the current server',
	Notification = false,
	Bind         = {},
	Function = function(enabled)
		if not enabled then return end
		pcall(function()
			teleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, lplr)
		end)
	end,
})
end

do
-- Auto Rejoin — automatically rejoin when disconnected
local arEnabled = false
local arConn

local autoRejoin = Utility:CreateModule({
	Name    = 'Auto Rejoin',
	Tooltip = 'Automatically rejoins when you are disconnected',
	Bind    = {},
	Function = function(enabled)
		arEnabled = enabled
		if enabled then
			arConn = game:GetService('GuiService'):GetPropertyChangedSignal('ErrorCode'):Connect(function()
				task.wait(2)
				if arEnabled then
					pcall(function()
						teleportService:Teleport(game.PlaceId, lplr)
					end)
				end
			end)
		else
			if arConn then arConn:Disconnect(); arConn = nil end
		end
	end,
})
local _ = autoRejoin
end

do
-- Panic — disables all currently enabled modules instantly
local panicModule
panicModule = Utility:CreateModule({
	Name         = 'Panic',
	Tooltip      = 'Instantly disables every active module',
	Notification = false,
	Bind         = {},
	Function = function(enabled)
		if not enabled then return end
		for _, module in vain.Modules do
			if module.Enabled and module ~= panicModule then
				pcall(module.Toggle, module)
			end
		end
	end,
})
end

do
-- Anti Ragdoll — prevents the ragdoll state
local arConn

local antiRagdoll = Utility:CreateModule({
	Name    = 'Anti Ragdoll',
	Tooltip = 'Prevents your character from entering a ragdoll state',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			local function applyToChar(char)
				local hum = char:FindFirstChildOfClass('Humanoid')
				if hum then
					hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
					hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
				end
			end
			if lplr.Character then applyToChar(lplr.Character) end
			arConn = lplr.CharacterAdded:Connect(function(char)
				task.wait(0.1)
				applyToChar(char)
			end)
		else
			if arConn then arConn:Disconnect(); arConn = nil end
			local hum = getHum()
			if hum then
				hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
				hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
			end
		end
	end,
})
local _ = antiRagdoll
end

do
-- Chat Spammer
local csEnabled  = false
local csMessages = {'Hello!', 'lol', 'gg'}
local csDelay    = 3
local csMode     = 'Order'
local csIndex    = 1

local function sendChat(msg)
	local textChat = game:GetService('TextChatService')
	if textChat.ChatVersion == Enum.ChatVersion.TextChatService then
		local channel = textChat.TextChannels:FindFirstChild('RBXGeneral')
		if channel then pcall(channel.SendAsync, channel, msg) end
	else
		local legacyChat = game:GetService('ReplicatedStorage')
			:FindFirstChild('DefaultChatSystemChatEvents')
		if legacyChat then
			local remote = legacyChat:FindFirstChild('SayMessageRequest')
			if remote then pcall(remote.FireServer, remote, msg, 'All') end
		end
	end
end

local chatSpammer = Utility:CreateModule({
	Name    = 'Chat Spammer',
	Tooltip = 'Automatically sends chat messages at an interval',
	Bind    = {},
	Function = function(enabled)
		csEnabled = enabled
		if not enabled then return end
		task.spawn(function()
			while csEnabled do
				if #csMessages > 0 then
					local msg
					if csMode == 'Random' then
						msg = csMessages[math.random(1, #csMessages)]
					else
						msg = csMessages[csIndex]
						csIndex = (csIndex % #csMessages) + 1
					end
					sendChat(msg)
				end
				task.wait(csDelay)
			end
		end)
	end,
})

chatSpammer:CreateDropdown({
	Name     = 'Mode',
	List     = {'Order', 'Random'},
	Function = function(val) csMode = val or 'Order' end,
})

chatSpammer:CreateSlider({
	Name    = 'Delay (s)',
	Min     = 1,
	Max     = 30,
	Default = 3,
	Function = function(val) csDelay = val end,
})

chatSpammer:CreateTextBox({
	Name        = 'Message (one per line)',
	Placeholder = 'Hello!',
	Function = function(val)
		if not val or val == '' then return end
		local lines = {}
		for line in val:gmatch('[^\n]+') do
			table.insert(lines, line)
		end
		if #lines > 0 then csMessages = lines; csIndex = 1 end
	end,
})
end

do
-- Prompt Duration — auto-fires proximity prompts
local pdEnabled = false
local pdDuration = 0.05
local pdConn

local promptDuration = Utility:CreateModule({
	Name    = 'Prompt Duration',
	Tooltip = 'Automatically holds and fires nearby proximity prompts',
	Bind    = {},
	Function = function(enabled)
		pdEnabled = enabled
		if enabled then
			pdConn = proxService.PromptButtonHoldBegan:Connect(function(prompt, _player)
				if _player ~= lplr then return end
				task.delay(pdDuration, function()
					if pdEnabled then pcall(fireproximityprompt, prompt) end
				end)
			end)
		else
			if pdConn then pdConn:Disconnect(); pdConn = nil end
		end
	end,
})

promptDuration:CreateSlider({
	Name    = 'Delay (ms)',
	Min     = 0,
	Max     = 2000,
	Default = 50,
	Function = function(val) pdDuration = val / 1000 end,
})
end

do
-- Staff Detector — server-hops or notifies when staff joins
local sdEnabled     = false
local sdGroupId     = 0
local sdMinRank     = 200
local sdAction      = 'Notify'
local sdConn

local function checkPlayer(p)
	if not sdEnabled then return end
	local ok, rank = pcall(function()
		return p:GetRankInGroup(sdGroupId)
	end)
	if ok and rank >= sdMinRank then
		vain:CreateNotification('Staff Detector', p.Name .. ' (rank ' .. rank .. ') joined', 8, 'alert')
		if sdAction == 'ServerHop' then
			task.delay(1.5, function()
				pcall(teleportService.Teleport, teleportService, game.PlaceId, lplr)
			end)
		end
	end
end

local staffDetector = Utility:CreateModule({
	Name    = 'Staff Detector',
	Tooltip = 'Alerts you when a staff member joins (by group rank)',
	Bind    = {},
	Function = function(enabled)
		sdEnabled = enabled
		if enabled then
			sdConn = playersService.PlayerAdded:Connect(checkPlayer)
		else
			if sdConn then sdConn:Disconnect(); sdConn = nil end
		end
	end,
})

staffDetector:CreateSlider({
	Name    = 'Min Rank',
	Min     = 1,
	Max     = 255,
	Default = 200,
	Function = function(val) sdMinRank = val end,
})

staffDetector:CreateTextBox({
	Name        = 'Group ID',
	Placeholder = '0',
	Function = function(val) sdGroupId = tonumber(val) or 0 end,
})

staffDetector:CreateDropdown({
	Name     = 'Action',
	List     = {'Notify', 'ServerHop'},
	Function = function(val) sdAction = val or 'Notify' end,
})
end

-- ── WORLD ──────────────────────────────────────────────────────────────────────

do
-- Gravity
local gravEnabled  = false
local gravValue    = 30
local origGravity

local gravity = World:CreateModule({
	Name    = 'Gravity',
	Tooltip = 'Reduces workspace gravity so you fall slower',
	Bind    = {},
	Function = function(enabled)
		gravEnabled = enabled
		if enabled then
			origGravity = origGravity or workspace.Gravity
			workspace.Gravity = gravValue
		else
			workspace.Gravity = origGravity or 196.2
			origGravity = nil
		end
	end,
})

gravity:CreateSlider({
	Name    = 'Gravity',
	Min     = 0,
	Max     = 196,
	Default = 30,
	Function = function(val)
		gravValue = val
		if gravEnabled then workspace.Gravity = val end
	end,
})
end

do
-- Xray — sets LocalTransparencyModifier on non-player parts
local xrayConn
local xrayParts   = {}   -- [part] = original LTM

local function applyXray()
	xrayParts = {}
	for _, part in workspace:GetDescendants() do
		if not part:IsA('BasePart') then continue end
		-- Skip player character parts
		local isPlayerPart = false
		for _, p in playersService:GetPlayers() do
			if p.Character and part:IsDescendantOf(p.Character) then
				isPlayerPart = true; break
			end
		end
		if isPlayerPart then continue end
		xrayParts[part] = part.LocalTransparencyModifier
		part.LocalTransparencyModifier = 0.85
	end
end

local function restoreXray()
	for part, ltm in xrayParts do
		pcall(function() part.LocalTransparencyModifier = ltm end)
	end
	xrayParts = {}
end

local xray = World:CreateModule({
	Name    = 'Xray',
	Tooltip = 'Makes walls and terrain semi-transparent so you can see through them',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			applyXray()
			-- Re-apply on new descendants
			xrayConn = workspace.DescendantAdded:Connect(function(part)
				if not part:IsA('BasePart') then return end
				for _, p in playersService:GetPlayers() do
					if p.Character and part:IsDescendantOf(p.Character) then return end
				end
				xrayParts[part] = part.LocalTransparencyModifier
				part.LocalTransparencyModifier = 0.85
			end)
		else
			restoreXray()
			if xrayConn then xrayConn:Disconnect(); xrayConn = nil end
		end
	end,
})
local _ = xray
end

do
-- Parkour — auto-jumps when you reach an edge
local parkourConn
local lastFloor = Enum.Material.Air

local parkour = World:CreateModule({
	Name    = 'Parkour',
	Tooltip = 'Automatically jumps when you are about to walk off an edge',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			parkourConn = runService.Heartbeat:Connect(function()
				local hum = getHum()
				if not hum then return end
				local floor = hum.FloorMaterial
				-- Jump the frame we step off solid ground (floor → Air)
				if lastFloor ~= Enum.Material.Air and floor == Enum.Material.Air then
					hum:ChangeState(Enum.HumanoidStateType.Jumping)
				end
				lastFloor = floor
			end)
		else
			if parkourConn then parkourConn:Disconnect(); parkourConn = nil end
			lastFloor = Enum.Material.Air
		end
	end,
})
local _ = parkour
end

do
-- Freecam — detached flying camera
local freecamSpeed   = 50
local freecamConn
local freecamBV, freecamBG
local freecamPart

local function cleanFreecam()
	if freecamConn then freecamConn:Disconnect(); freecamConn = nil end
	if freecamBV and freecamBV.Parent then freecamBV:Destroy() end
	if freecamBG and freecamBG.Parent then freecamBG:Destroy() end
	if freecamPart and freecamPart.Parent then freecamPart:Destroy() end
	freecamBV, freecamBG, freecamPart = nil, nil, nil
end

local freecam = World:CreateModule({
	Name    = 'Freecam',
	Tooltip = 'Detaches the camera and lets you fly it freely',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			local cam = workspace.CurrentCamera
			local origCF = cam.CFrame

			-- Invisible anchor part the camera rides on
			freecamPart = Instance.new('Part')
			freecamPart.Anchored     = true
			freecamPart.CanCollide   = false
			freecamPart.Transparency = 1
			freecamPart.Size         = Vector3.new(1, 1, 1)
			freecamPart.CFrame       = origCF
			freecamPart.Parent       = workspace

			cam.CameraType    = Enum.CameraType.Scriptable
			cam.CameraSubject = nil

			freecamConn = runService.RenderStepped:Connect(function(dt)
				local dir = Vector3.new(0, 0, 0)
				local cf  = cam.CFrame

				if inputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cf.LookVector  end
				if inputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cf.LookVector  end
				if inputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cf.RightVector end
				if inputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cf.RightVector end
				if inputService:IsKeyDown(Enum.KeyCode.E) then dir = dir + Vector3.new(0, 1, 0) end
				if inputService:IsKeyDown(Enum.KeyCode.Q) then dir = dir - Vector3.new(0, 1, 0) end

				if dir.Magnitude > 0 then
					cam.CFrame = CFrame.new(cam.CFrame.Position + dir.Unit * freecamSpeed * dt)
						* CFrame.Angles(
							select(2, cam.CFrame:ToEulerAnglesYXZ()),
							0, 0
						):Inverse()
						* CFrame.Angles(
							select(2, cam.CFrame:ToEulerAnglesYXZ()),
							0, 0
						)
					-- Simple version: just translate
					cam.CFrame = cam.CFrame + dir.Unit * freecamSpeed * dt
				end
			end)
		else
			local cam = workspace.CurrentCamera
			cam.CameraType    = Enum.CameraType.Custom
			cam.CameraSubject = lplr.Character
				and lplr.Character:FindFirstChildOfClass('Humanoid')
				or lplr.Character
			cleanFreecam()
		end
	end,
})

freecam:CreateSlider({
	Name    = 'Speed',
	Min     = 5,
	Max     = 200,
	Default = 50,
	Function = function(val) freecamSpeed = val end,
})
end

-- ── LEGIT ──────────────────────────────────────────────────────────────────────

do
-- FOV changer
local fovEnabled = false
local origFov

local fovModule = Legit:CreateModule({
	Name    = 'FOV',
	Tooltip = 'Overrides the camera field of view',
	Bind    = {},
	Function = function(enabled)
		fovEnabled = enabled
		local cam = workspace.CurrentCamera
		if not cam then return end
		if enabled then
			origFov = origFov or cam.FieldOfView
		else
			if origFov then cam.FieldOfView = origFov; origFov = nil end
		end
	end,
})

fovModule:CreateSlider({
	Name    = 'FOV',
	Min     = 30,
	Max     = 120,
	Default = 70,
	Function = function(val)
		if fovEnabled then
			local cam = workspace.CurrentCamera
			if cam then cam.FieldOfView = val end
		end
	end,
})
end

do
-- HUD Overlays: FPS, Ping, Speedmeter (Drawing-based)
if DrawingAvailable then

local hudEnabled   = false
local hudConn
local hudColor     = Color3.fromRGB(255, 255, 255)
local hudSize      = 15
local hudX, hudY   = 10, 10

local fpsText  = Drawing.new('Text')
local pingText = Drawing.new('Text')
local spdText  = Drawing.new('Text')
local lastPos  = nil
local lastTime = os.clock()

local function setupText(t)
	t.Visible  = false
	t.Color    = hudColor
	t.Size     = hudSize
	t.Outline  = true
	t.Font     = 2 -- monospace
end

setupText(fpsText)
setupText(pingText)
setupText(spdText)

vain:Clean(function()
	pcall(fpsText.Remove,  fpsText)
	pcall(pingText.Remove, pingText)
	pcall(spdText.Remove,  spdText)
end)

local showFps   = true
local showPing  = true
local showSpeed = true

local hudModule = Legit:CreateModule({
	Name    = 'HUD',
	Tooltip = 'Shows FPS, ping, and speed overlays on screen',
	Bind    = {},
	Function = function(enabled)
		hudEnabled = enabled
		fpsText.Visible  = enabled and showFps
		pingText.Visible = enabled and showPing
		spdText.Visible  = enabled and showSpeed

		if enabled then
			hudConn = runService.RenderStepped:Connect(function()
				local now = os.clock()
				local dt  = now - lastTime
				lastTime  = now

				-- FPS
				if showFps then
					fpsText.Text     = string.format('FPS: %d', math.floor(1 / (dt > 0 and dt or 0.001)))
					fpsText.Position = Vector2.new(hudX, hudY)
					fpsText.Color    = hudColor
				end

				-- Ping
				if showPing then
					local ok, ping = pcall(function()
						return statsService.PerformanceStats.DataPing:GetValue()
					end)
					pingText.Text     = string.format('Ping: %d ms', ok and math.floor(ping) or 0)
					pingText.Position = Vector2.new(hudX, hudY + hudSize + 4)
					pingText.Color    = hudColor
				end

				-- Speed
				if showSpeed then
					local hrp = getHRP()
					local spd = 0
					if hrp and lastPos then
						spd = (hrp.Position - lastPos).Magnitude / (dt > 0 and dt or 0.001)
					end
					if hrp then lastPos = hrp.Position end
					spdText.Text     = string.format('Speed: %.1f', spd)
					spdText.Position = Vector2.new(hudX, hudY + (hudSize + 4) * 2)
					spdText.Color    = hudColor
				end
			end)
		else
			if hudConn then hudConn:Disconnect(); hudConn = nil end
		end
	end,
})

hudModule:CreateToggle({
	Name    = 'Show FPS',
	Default = true,
	Function = function(val)
		showFps = val
		fpsText.Visible = val and hudEnabled
	end,
})

hudModule:CreateToggle({
	Name    = 'Show Ping',
	Default = true,
	Function = function(val)
		showPing = val
		pingText.Visible = val and hudEnabled
	end,
})

hudModule:CreateToggle({
	Name    = 'Show Speed',
	Default = true,
	Function = function(val)
		showSpeed = val
		spdText.Visible = val and hudEnabled
	end,
})

hudModule:CreateSlider({
	Name    = 'Text Size',
	Min     = 10,
	Max     = 30,
	Default = 15,
	Function = function(val)
		hudSize = val
		fpsText.Size  = val
		pingText.Size = val
		spdText.Size  = val
	end,
})

end -- DrawingAvailable
end

do
-- Keystrokes — on-screen key display (Drawing)
if DrawingAvailable then

local ksConn
local ksSize      = 28
local ksColor     = Color3.fromRGB(240, 240, 240)
local ksActiveCol = Color3.fromRGB(100, 210, 255)

local KEYS = {
	{key = Enum.KeyCode.W,          label = 'W',  col = 0},
	{key = Enum.KeyCode.A,          label = 'A',  col = -1},
	{key = Enum.KeyCode.S,          label = 'S',  col = 0},
	{key = Enum.KeyCode.D,          label = 'D',  col = 1},
	{key = Enum.UserInputType.MouseButton1, label = 'M1', col = -1, row = 2},
	{key = Enum.UserInputType.MouseButton2, label = 'M2', col = 1,  row = 2},
}

local baseX  = 200
local baseY  = 200
local ksBoxes  = {}
local ksLabels = {}

local function buildKsUI()
	for i, _ in KEYS do
		local sq = Drawing.new('Square')
		sq.Visible       = false
		sq.Filled        = true
		sq.Color         = Color3.fromRGB(40, 40, 40)
		sq.Transparency  = 0.4
		sq.Size          = Vector2.new(ksSize, ksSize)
		ksBoxes[i] = sq

		local lbl = Drawing.new('Text')
		lbl.Visible = false
		lbl.Size    = 12
		lbl.Color   = ksColor
		lbl.Outline = true
		ksLabels[i] = lbl
	end
end

buildKsUI()

vain:Clean(function()
	for _, b in ksBoxes  do pcall(b.Remove,  b) end
	for _, l in ksLabels do pcall(l.Remove, l) end
end)

local keystrokes = Legit:CreateModule({
	Name    = 'Keystrokes',
	Tooltip = 'Shows your WASD and mouse button presses on screen',
	Bind    = {},
	Function = function(enabled)
		for _, sq  in ksBoxes  do sq.Visible  = enabled end
		for _, lbl in ksLabels do lbl.Visible = enabled end

		if enabled then
			ksConn = runService.RenderStepped:Connect(function()
				local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
					or Vector2.new(800, 600)

				local BX = baseX
				local BY = baseY

				local rowY = {
					[0] = BY,
					[1] = BY + ksSize + 4,
					[2] = BY + (ksSize + 4) * 2,
				}

				for i, kdef in KEYS do
					local row = kdef.row or (kdef.label == 'W' and 0 or 1)
					local px  = BX + kdef.col * (ksSize + 4)
					local py  = rowY[row] or BY

					local pressed
					if typeof(kdef.key) == 'EnumItem' and kdef.key.EnumType == Enum.KeyCode then
						pressed = inputService:IsKeyDown(kdef.key)
					else
						pressed = inputService:IsMouseButtonPressed(kdef.key)
					end

					ksBoxes[i].Position  = Vector2.new(px, py)
					ksBoxes[i].Color     = pressed and ksActiveCol or Color3.fromRGB(40, 40, 40)

					ksLabels[i].Text     = kdef.label
					ksLabels[i].Position = Vector2.new(px + 4, py + 6)
					ksLabels[i].Color    = pressed and Color3.new(0, 0, 0) or ksColor
				end
			end)
		else
			if ksConn then ksConn:Disconnect(); ksConn = nil end
		end
	end,
})

keystrokes:CreateSlider({
	Name    = 'X Position',
	Min     = 0,
	Max     = 800,
	Default = 200,
	Function = function(val) baseX = val end,
})

keystrokes:CreateSlider({
	Name    = 'Y Position',
	Min     = 0,
	Max     = 600,
	Default = 200,
	Function = function(val) baseY = val end,
})

end -- DrawingAvailable
end

do
-- Animation Player
local animEnabled = false
local loadedAnim

local animPlayer = Legit:CreateModule({
	Name    = 'Animation Player',
	Tooltip = 'Plays a custom animation on your character by ID',
	Bind    = {},
	Function = function(enabled)
		animEnabled = enabled
		if not enabled then
			if loadedAnim then pcall(loadedAnim.Stop, loadedAnim); loadedAnim = nil end
		end
	end,
})

animPlayer:CreateTextBox({
	Name        = 'Animation ID',
	Placeholder = 'rbxassetid://...',
	Function = function(val)
		if not animEnabled then return end
		if loadedAnim then pcall(loadedAnim.Stop, loadedAnim); loadedAnim = nil end
		local hum = getHum()
		if not hum then return end
		local anim = Instance.new('Animation')
		anim.AnimationId = val:find('rbxassetid') and val or ('rbxassetid://' .. (val or ''))
		local ok, track = pcall(function()
			return hum:LoadAnimation(anim)
		end)
		if ok and track then
			loadedAnim = track
			track:Play()
		else
			vain:CreateNotification('Vain', 'Animation failed to load', 3, 'alert')
		end
	end,
})

animPlayer:CreateSlider({
	Name    = 'Speed',
	Min     = 10,
	Max     = 200,
	Default = 100,
	Function = function(val)
		if loadedAnim then loadedAnim:AdjustSpeed(val / 100) end
	end,
})
end

-- ── BLATANT — Fly ──────────────────────────────────────────────────────────────
do
local flyEnabled = false
local flySpeed   = 50
local flyBV, flyBG

local function cleanFly()
	if flyBV then flyBV:Destroy(); flyBV = nil end
	if flyBG then flyBG:Destroy(); flyBG = nil end
end

local Fly
Fly = Blatant:CreateModule({
	Name    = 'Fly',
	Tooltip = 'Lets you fly freely using WASD and Space/Shift',
	Bind    = {},
	Function = function(enabled)
		flyEnabled = enabled
		local hrp = getHRP()
		local hum = getHum()
		if enabled then
			if not hrp then return end
			if hum then hum.PlatformStand = true end
			flyBV = Instance.new('BodyVelocity')
			flyBV.Velocity    = Vector3.zero
			flyBV.MaxForce    = Vector3.one * math.huge
			flyBV.Parent      = hrp
			flyBG = Instance.new('BodyGyro')
			flyBG.MaxTorque   = Vector3.one * math.huge
			flyBG.P           = 9e4
			flyBG.D           = 1000
			flyBG.CFrame      = hrp.CFrame
			flyBG.Parent      = hrp

			vain:Clean(runService.RenderStepped:Connect(function()
				if not flyEnabled then return end
				local hrp2 = getHRP()
				if not flyBV or not hrp2 then return end
				local cam    = workspace.CurrentCamera
				local fwd    = inputService:IsKeyDown(Enum.KeyCode.W)
				local bwd    = inputService:IsKeyDown(Enum.KeyCode.S)
				local left   = inputService:IsKeyDown(Enum.KeyCode.A)
				local right  = inputService:IsKeyDown(Enum.KeyCode.D)
				local up     = inputService:IsKeyDown(Enum.KeyCode.Space)
				local down   = inputService:IsKeyDown(Enum.KeyCode.LeftShift)
				local dir    = Vector3.zero
				local look   = cam.CFrame.LookVector
				local right2 = cam.CFrame.RightVector
				if fwd   then dir += look end
				if bwd   then dir -= look end
				if right then dir += right2 end
				if left  then dir -= right2 end
				if up    then dir += Vector3.new(0, 1, 0) end
				if down  then dir -= Vector3.new(0, 1, 0) end
				flyBV.Velocity = dir.Magnitude > 0 and dir.Unit * flySpeed or Vector3.zero
				flyBG.CFrame   = CFrame.new(hrp2.Position, hrp2.Position + look)
			end))

			vain:Clean(lplr.CharacterAdded:Connect(function()
				task.wait(0.5)
				if flyEnabled then Fly:Toggle(); Fly:Toggle() end
			end))
		else
			local hum2 = getHum()
			if hum2 then hum2.PlatformStand = false end
			cleanFly()
		end
	end,
})

Fly:CreateSlider({
	Name    = 'Speed',
	Min     = 10,
	Max     = 300,
	Default = 50,
	Function = function(val) flySpeed = val end,
})
end

-- ── BLATANT — Noclip ───────────────────────────────────────────────────────────
do
Blatant:CreateModule({
	Name    = 'Noclip',
	Tooltip = 'Lets you phase through walls',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			vain:Clean(runService.Stepped:Connect(function()
				local char = lplr.Character
				if not char then return end
				for _, p in char:GetDescendants() do
					if p:IsA('BasePart') and p.CanCollide then
						p.CanCollide = false
					end
				end
			end))
			vain:Clean(lplr.CharacterAdded:Connect(function(char)
				task.wait(0.5)
				for _, p in char:GetDescendants() do
					if p:IsA('BasePart') then p.CanCollide = false end
				end
			end))
		end
	end,
})
end

-- ── BLATANT — Spin Bot ─────────────────────────────────────────────────────────
do
local spinSpeed = 40

local spinModule = Blatant:CreateModule({
	Name    = 'Spin Bot',
	Tooltip = 'Makes your character spin continuously',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			vain:Clean(runService.PreSimulation:Connect(function()
				local hrp = getHRP()
				if not hrp then return end
				local val = math.rad((tick() * (20 * (spinSpeed / 40))) % 360)
				local x, _, z = hrp.CFrame:ToOrientation()
				hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(x, val, z)
			end))
		end
	end,
})

spinModule:CreateSlider({
	Name    = 'Speed',
	Min     = 1,
	Max     = 100,
	Default = 40,
	Function = function(val) spinSpeed = val end,
})
end

-- ── BLATANT — Mouse TP ─────────────────────────────────────────────────────────
do
local MouseTP
MouseTP = Blatant:CreateModule({
	Name    = 'Mouse TP',
	Tooltip = 'Teleport to wherever your mouse is pointing (one-shot)',
	Bind    = {},
	Function = function(enabled)
		if not enabled then return end
		local hrp = getHRP()
		if not hrp then MouseTP:Toggle(); return end
		local cam    = workspace.CurrentCamera
		local mouse  = lplr:GetMouse()
		local ray    = cam:ScreenPointToRay(mouse.X, mouse.Y)
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = {lplr.Character, cam}
		params.FilterType = Enum.RaycastFilterType.Exclude
		local result = workspace:Raycast(ray.Origin, ray.Direction * 5000, params)
		if result then
			hrp.CFrame = CFrame.new(result.Position + Vector3.new(0, 3, 0))
		else
			vain:CreateNotification('Mouse TP', 'No surface found', 3, 'alert')
		end
		task.defer(function() MouseTP:Toggle() end)
	end,
})
end

-- ── BLATANT — Invisible ────────────────────────────────────────────────────────
do
local Invisible
Invisible = Blatant:CreateModule({
	Name    = 'Invisible',
	Tooltip = 'Makes your character invisible to other players',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			local char = lplr.Character
			if not char then Invisible:Toggle(); return end
			local ok, anim = pcall(function()
				local a = Instance.new('Animation')
				a.AnimationId = 'rbxassetid://507766388'
				local hum = char:FindFirstChildOfClass('Humanoid')
				return hum and hum.Animator:LoadAnimation(a)
			end)
			if ok and anim then
				anim.Priority = Enum.AnimationPriority.Action4
				anim:Play(0, 1, 0)
				vain:Clean(function() pcall(anim.Stop, anim) end)
			end
			char.Parent = game:GetService('ReplicatedStorage')
			char.Parent = workspace
		end
	end,
})
end

-- ── BLATANT — Spider ───────────────────────────────────────────────────────────
do
Blatant:CreateModule({
	Name    = 'Spider',
	Tooltip = 'Lets you climb up walls by placing water terrain around you',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			local terrain = workspace:FindFirstChildWhichIsA('Terrain')
			if not terrain then
				vain:CreateNotification('Spider', 'No terrain found', 3, 'alert')
				return
			end
			local lastReg = Region3.new(Vector3.zero, Vector3.zero)
			vain:Clean(runService.PreSimulation:Connect(function()
				local hrp = getHRP()
				if not hrp then return end
				local pos    = hrp.Position - Vector3.new(0, 1, 0)
				local factor = Vector3.new(5, 5, 5)
				local newReg = Region3.new(pos - factor, pos + factor):ExpandToGrid(4)
				pcall(terrain.ReplaceMaterial, terrain, lastReg, 4, Enum.Material.Water, Enum.Material.Air)
				pcall(terrain.FillRegion, terrain, newReg, 4, Enum.Material.Water)
				lastReg = newReg
			end))
			vain:Clean(function()
				pcall(terrain.ReplaceMaterial, terrain, lastReg, 4, Enum.Material.Water, Enum.Material.Air)
			end)
		end
	end,
})
end

-- ── BLATANT — Swim ─────────────────────────────────────────────────────────────
do
Blatant:CreateModule({
	Name    = 'Swim',
	Tooltip = 'Fills terrain with water around you so you can swim anywhere',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			local terrain = workspace:FindFirstChildWhichIsA('Terrain')
			if not terrain then
				vain:CreateNotification('Swim', 'No terrain found', 3, 'alert')
				return
			end
			local lastReg = Region3.new(Vector3.zero, Vector3.zero)
			vain:Clean(runService.PreSimulation:Connect(function()
				local hrp = getHRP()
				if not hrp then return end
				local moving = (getHum() and getHum().MoveDirection ~= Vector3.zero)
				local space  = inputService:IsKeyDown(Enum.KeyCode.Space)
				local factor = (moving or space) and Vector3.new(6, 6, 6) or Vector3.new(2, 1, 2)
				local pos    = hrp.Position - Vector3.new(0, 1, 0)
				local newReg = Region3.new(pos - factor, pos + factor):ExpandToGrid(4)
				pcall(terrain.ReplaceMaterial, terrain, lastReg, 4, Enum.Material.Water, Enum.Material.Air)
				pcall(terrain.FillRegion, terrain, newReg, 4, Enum.Material.Water)
				lastReg = newReg
			end))
			vain:Clean(function()
				pcall(terrain.ReplaceMaterial, terrain, lastReg, 4, Enum.Material.Water, Enum.Material.Air)
			end)
		end
	end,
})
end

-- ── BLATANT — Target Strafe ────────────────────────────────────────────────────
do
local strafeRange  = 12
local strafeAngle  = 0

local TargetStrafe
TargetStrafe = Blatant:CreateModule({
	Name    = 'Target Strafe',
	Tooltip = 'Orbits around the closest player',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			vain:Clean(runService.Heartbeat:Connect(function()
				if not TargetStrafe.Enabled then return end
				local hrp = getHRP()
				if not hrp then return end
				local best, bestDist = nil, math.huge
				for _, p in getLivingPlayers() do
					local d = (p.Character.HumanoidRootPart.Position - hrp.Position).Magnitude
					if d < bestDist then best = p; bestDist = d end
				end
				if not best then return end
				strafeAngle = (strafeAngle + 2) % 360
				local tpos   = best.Character.HumanoidRootPart.Position
				local offset = CFrame.Angles(0, math.rad(strafeAngle), 0).LookVector * strafeRange
				local target = tpos + Vector3.new(offset.X, 0, offset.Z)
				hrp.CFrame   = CFrame.new(target, tpos)
			end))
		end
	end,
})

TargetStrafe:CreateSlider({
	Name    = 'Range',
	Min     = 3,
	Max     = 30,
	Default = 12,
	Function = function(val) strafeRange = val end,
})
end

-- ── BLATANT — Timer ────────────────────────────────────────────────────────────
do
local timerSpeed = 2

local timerModule = Blatant:CreateModule({
	Name    = 'Timer',
	Tooltip = 'Speeds up local physics by stepping extra frames',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			pcall(setfflag, 'SimEnableStepPhysics', 'True')
			pcall(setfflag, 'SimEnableStepPhysicsSelective', 'True')
			vain:Clean(runService.RenderStepped:Connect(function(dt)
				if timerSpeed > 1 then
					pcall(function()
						local hrp = getHRP()
						runService:Pause()
						workspace:StepPhysics(dt * (timerSpeed - 1), hrp and {hrp} or nil)
						runService:Run()
					end)
				end
			end))
		end
	end,
})

timerModule:CreateSlider({
	Name    = 'Speed',
	Min     = 1,
	Max     = 5,
	Default = 2,
	Function = function(val) timerSpeed = val end,
})
end

-- ── COMBAT — Silent Aim ────────────────────────────────────────────────────────
do
local silentRange = 50
local oldnamecall2

local SilentAim
SilentAim = Combat:CreateModule({
	Name    = 'Silent Aim',
	Tooltip = 'Redirects your shots towards the nearest player',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			if not hookmetamethod then
				vain:CreateNotification('Silent Aim', 'hookmetamethod not available', 4, 'alert')
				SilentAim:Toggle(); return
			end
			oldnamecall2 = hookmetamethod(game, '__namecall', function(self, ...)
				local method = getnamecallmethod()
				if method ~= 'FindPartOnRayWithIgnoreList' and method ~= 'FindPartOnRay' then
					return oldnamecall2(self, ...)
				end
				if checkcaller and checkcaller() then
					return oldnamecall2(self, ...)
				end
				local args = {...}
				local ray = args[1]
				if typeof(ray) == 'Ray' then
					local hrp = getHRP()
					if hrp then
						local best, bestDist = nil, math.huge
						for _, p in getLivingPlayers() do
							local phrp = p.Character.HumanoidRootPart
							local d = (phrp.Position - hrp.Position).Magnitude
							if d < silentRange and d < bestDist then
								best = p; bestDist = d
							end
						end
						if best then
							local target = best.Character:FindFirstChild('Head') or best.Character.HumanoidRootPart
							args[1] = Ray.new(ray.Origin, (target.Position - ray.Origin).Unit * ray.Direction.Magnitude)
						end
					end
				end
				return oldnamecall2(self, table.unpack(args))
			end)
		else
			if oldnamecall2 then
				hookmetamethod(game, '__namecall', oldnamecall2)
				oldnamecall2 = nil
			end
		end
	end,
})

SilentAim:CreateSlider({
	Name    = 'Range',
	Min     = 5,
	Max     = 200,
	Default = 50,
	Function = function(val) silentRange = val end,
})
end

-- ── RENDER — Arrows ────────────────────────────────────────────────────────────
if DrawingAvailable then
do
local arrowObjects = {}
local arrowSize    = 20
local arrowDist    = 200

local function removeArrow(p)
	if arrowObjects[p] then
		for _, d in arrowObjects[p] do pcall(d.Remove, d) end
		arrowObjects[p] = nil
	end
end

local function addArrow(p)
	if arrowObjects[p] then return end
	local tri = Drawing.new('Triangle')
	tri.Visible      = false
	tri.Filled       = true
	tri.Color        = Color3.fromRGB(255, 50, 50)
	tri.Transparency = 1
	arrowObjects[p]  = {tri}
end

local Arrows
Arrows = Render:CreateModule({
	Name    = 'Arrows',
	Tooltip = 'Shows directional arrows to off-screen players',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			for _, p in getLivingPlayers() do addArrow(p) end
			vain:Clean(playersService.PlayerAdded:Connect(addArrow))
			vain:Clean(playersService.PlayerRemoving:Connect(removeArrow))

			vain:Clean(runService.RenderStepped:Connect(function()
				if not Arrows.Enabled then return end
				local cam  = workspace.CurrentCamera
				local vp   = cam.ViewportSize
				local cx   = vp.X / 2
				local cy   = vp.Y / 2
				for _, p in playersService:GetPlayers() do
					if p == lplr then continue end
					if not arrowObjects[p] then addArrow(p) end
					local objs = arrowObjects[p]
					if not objs then continue end
					local tri  = objs[1]
					local char = p.Character
					if not char then tri.Visible = false; continue end
					local hrp = char:FindFirstChild('HumanoidRootPart')
					if not hrp then tri.Visible = false; continue end
					local _, onScreen = cam:WorldToViewportPoint(hrp.Position)
					if onScreen then tri.Visible = false; continue end
					local screenPos = cam:WorldToViewportPoint(hrp.Position)
					local dir   = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(cx, cy)).Unit
					local angle = math.atan2(dir.Y, dir.X)
					local edgeX = math.clamp(cx + dir.X * (cx - arrowSize - 10), arrowSize + 5, vp.X - arrowSize - 5)
					local edgeY = math.clamp(cy + dir.Y * (cy - arrowSize - 10), arrowSize + 5, vp.Y - arrowSize - 5)
					local tip   = Vector2.new(edgeX, edgeY)
					local b1    = tip + Vector2.new(math.cos(angle + math.pi * 0.75), math.sin(angle + math.pi * 0.75)) * arrowSize
					local b2    = tip + Vector2.new(math.cos(angle - math.pi * 0.75), math.sin(angle - math.pi * 0.75)) * arrowSize
					tri.PointA  = tip
					tri.PointB  = b1
					tri.PointC  = b2
					tri.Visible = true
				end
			end))

			vain:Clean(function()
				for _, p in playersService:GetPlayers() do removeArrow(p) end
			end)
		else
			for _, p in playersService:GetPlayers() do removeArrow(p) end
		end
	end,
})

Arrows:CreateSlider({
	Name    = 'Size',
	Min     = 8,
	Max     = 40,
	Default = 20,
	Function = function(val) arrowSize = val end,
})

Arrows:CreateSlider({
	Name    = 'Max Distance',
	Min     = 10,
	Max     = 1000,
	Default = 200,
	Function = function(val) arrowDist = val end,
})
end
end -- DrawingAvailable

-- ── RENDER — Name Tags ─────────────────────────────────────────────────────────
do
local tagObjects    = {}
local tagShowDist   = true
local tagUseDisplay = true

local function removeTag(p)
	if tagObjects[p] then tagObjects[p]:Destroy(); tagObjects[p] = nil end
end

local function addTag(p)
	if p == lplr then return end
	if tagObjects[p] then return end
	local char = p.Character
	if not char then return end
	local hrp = char:FindFirstChild('HumanoidRootPart')
	if not hrp then return end
	local bb = Instance.new('BillboardGui')
	bb.Name              = 'VainNameTag'
	bb.Size              = UDim2.fromOffset(120, 30)
	bb.StudsOffset       = Vector3.new(0, 3, 0)
	bb.AlwaysOnTop       = true
	bb.Adornee           = hrp
	bb.Parent            = gethui and gethui() or lplr.PlayerGui
	local lbl = Instance.new('TextLabel')
	lbl.Size                   = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 0.4
	lbl.BackgroundColor3       = Color3.new(0, 0, 0)
	lbl.TextColor3             = Color3.new(1, 1, 1)
	lbl.TextScaled             = true
	lbl.Font                   = Enum.Font.GothamBold
	lbl.Text                   = tagUseDisplay and p.DisplayName or p.Name
	lbl.Parent                 = bb
	tagObjects[p] = bb
end

local NameTags
NameTags = Render:CreateModule({
	Name    = 'Name Tags',
	Tooltip = 'Shows nametags above players through walls',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			for _, p in getLivingPlayers() do addTag(p) end
			vain:Clean(playersService.PlayerAdded:Connect(function(p)
				vain:Clean(p.CharacterAdded:Connect(function() task.wait(1); addTag(p) end))
			end))
			vain:Clean(playersService.PlayerRemoving:Connect(removeTag))

			vain:Clean(runService.RenderStepped:Connect(function()
				local myHRP = getHRP()
				for p, bb in tagObjects do
					local char = p.Character
					if not char then removeTag(p); continue end
					local hrp = char:FindFirstChild('HumanoidRootPart')
					if not hrp then removeTag(p); continue end
					bb.Adornee = hrp
					local lbl2 = bb:FindFirstChildOfClass('TextLabel')
					if lbl2 then
						local name = tagUseDisplay and p.DisplayName or p.Name
						if tagShowDist and myHRP then
							local d = math.floor((hrp.Position - myHRP.Position).Magnitude)
							name = name .. ' [' .. d .. ']'
						end
						lbl2.Text = name
					end
				end
			end))

			vain:Clean(function() for p in tagObjects do removeTag(p) end end)
		else
			for p in tagObjects do removeTag(p) end
		end
	end,
})

NameTags:CreateToggle({
	Name    = 'Show Distance',
	Default = true,
	Function = function(val) tagShowDist = val end,
})

NameTags:CreateToggle({
	Name    = 'Use Display Name',
	Default = true,
	Function = function(val) tagUseDisplay = val end,
})
end

-- ── RENDER — Chams ─────────────────────────────────────────────────────────────
do
local chamObjects   = {}
local chamFillTrans = 0.5
local chamOutTrans  = 0
local chamWalls     = true

local function removeCham(p)
	if chamObjects[p] then chamObjects[p]:Destroy(); chamObjects[p] = nil end
end

local function addCham(p)
	if p == lplr then return end
	if chamObjects[p] then return end
	local char = p.Character
	if not char then return end
	local h = Instance.new('Highlight')
	h.FillColor           = Color3.fromRGB(255, 50, 50)
	h.OutlineColor        = Color3.fromRGB(255, 255, 255)
	h.FillTransparency    = chamFillTrans
	h.OutlineTransparency = chamOutTrans
	h.DepthMode           = chamWalls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
	h.Adornee             = char
	h.Parent              = gethui and gethui() or lplr.PlayerGui
	chamObjects[p] = h
end

local Chams
Chams = Render:CreateModule({
	Name    = 'Chams',
	Tooltip = 'Coloured Highlights on players with optional wall penetration',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			for _, p in getLivingPlayers() do addCham(p) end
			vain:Clean(playersService.PlayerAdded:Connect(function(p)
				vain:Clean(p.CharacterAdded:Connect(function() task.wait(1); addCham(p) end))
			end))
			vain:Clean(playersService.PlayerRemoving:Connect(removeCham))
			vain:Clean(lplr.CharacterAdded:Connect(function()
				for _, p in getLivingPlayers() do addCham(p) end
			end))
			vain:Clean(function() for p in chamObjects do removeCham(p) end end)
		else
			for p in chamObjects do removeCham(p) end
		end
	end,
})

Chams:CreateToggle({
	Name    = 'Through Walls',
	Default = true,
	Function = function(val)
		chamWalls = val
		for _, h in chamObjects do
			h.DepthMode = val and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
		end
	end,
})

Chams:CreateSlider({
	Name    = 'Fill Transparency',
	Min     = 0,
	Max     = 100,
	Default = 50,
	Function = function(val)
		chamFillTrans = val / 100
		for _, h in chamObjects do h.FillTransparency = chamFillTrans end
	end,
})

Chams:CreateSlider({
	Name    = 'Outline Transparency',
	Min     = 0,
	Max     = 100,
	Default = 0,
	Function = function(val)
		chamOutTrans = val / 100
		for _, h in chamObjects do h.OutlineTransparency = chamOutTrans end
	end,
})
end

-- ── RENDER — Breadcrumbs ───────────────────────────────────────────────────────
do
local breadTrail, breadPt1, breadPt2
local breadLifetime = 3

local function createBreadTrail()
	if breadPt1  then breadPt1:Destroy()  end
	if breadPt2  then breadPt2:Destroy()  end
	if breadTrail then breadTrail:Destroy() end
	local hrp = getHRP()
	if not hrp then return end
	breadPt1 = Instance.new('Attachment')
	breadPt1.Position = Vector3.new(0, 0.1, 0)
	breadPt1.Parent   = hrp
	breadPt2 = Instance.new('Attachment')
	breadPt2.Position = Vector3.new(0, -0.1, 0)
	breadPt2.Parent   = hrp
	breadTrail = Instance.new('Trail')
	breadTrail.Attachment0 = breadPt1
	breadTrail.Attachment1 = breadPt2
	breadTrail.Lifetime    = breadLifetime
	breadTrail.MinLength   = 0
	breadTrail.Color       = ColorSequence.new(Color3.fromRGB(200, 100, 255), Color3.fromRGB(100, 50, 200))
	breadTrail.Parent      = workspace.CurrentCamera
end

local Breadcrumbs
Breadcrumbs = Render:CreateModule({
	Name    = 'Breadcrumbs',
	Tooltip = 'Leaves a coloured trail behind your character',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			createBreadTrail()
			vain:Clean(lplr.CharacterAdded:Connect(function()
				task.wait(0.5)
				if Breadcrumbs.Enabled then createBreadTrail() end
			end))
			vain:Clean(function()
				if breadPt1   then breadPt1:Destroy();   breadPt1 = nil   end
				if breadPt2   then breadPt2:Destroy();   breadPt2 = nil   end
				if breadTrail then breadTrail:Destroy(); breadTrail = nil end
			end)
		else
			if breadPt1   then breadPt1:Destroy();   breadPt1 = nil   end
			if breadPt2   then breadPt2:Destroy();   breadPt2 = nil   end
			if breadTrail then breadTrail:Destroy(); breadTrail = nil end
		end
	end,
})

Breadcrumbs:CreateSlider({
	Name    = 'Lifetime',
	Min     = 1,
	Max     = 10,
	Default = 3,
	Function = function(val)
		breadLifetime = val
		if breadTrail then breadTrail.Lifetime = val end
	end,
})
end

-- ── RENDER — Cape ──────────────────────────────────────────────────────────────
do
local capePart, capeMotor

local Cape
Cape = Render:CreateModule({
	Name    = 'Cape',
	Tooltip = 'Adds a flowing cape to your character',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			local cam = workspace.CurrentCamera
			capePart = Instance.new('Part')
			capePart.Size       = Vector3.new(2, 3, 0.05)
			capePart.CanCollide = false
			capePart.CanQuery   = false
			capePart.Massless   = true
			capePart.Color      = Color3.fromRGB(180, 0, 0)
			capePart.Material   = Enum.Material.SmoothPlastic
			capePart.CastShadow = false
			capePart.Parent     = cam

			local function attachCape()
				if capeMotor then capeMotor:Destroy() end
				local char = lplr.Character
				if not char then return end
				local torso = char:FindFirstChild('UpperTorso') or char:FindFirstChild('Torso')
				if not torso then return end
				capeMotor = Instance.new('Motor6D')
				capeMotor.MaxVelocity = 0.08
				capeMotor.Part0       = capePart
				capeMotor.Part1       = torso
				capeMotor.C0          = CFrame.new(0, 1.5, 0)
				capeMotor.C1          = CFrame.new(0, torso.Size.Y / 2, 0.4) * CFrame.Angles(0, math.rad(180), 0)
				capeMotor.Parent      = capePart
			end

			attachCape()
			vain:Clean(lplr.CharacterAdded:Connect(function()
				task.wait(0.5); if Cape.Enabled then attachCape() end
			end))
			vain:Clean(runService.Heartbeat:Connect(function()
				if not capeMotor then return end
				local hrp = getHRP()
				if not hrp then return end
				local velo = math.min(hrp.Velocity.Magnitude, 90)
				capeMotor.DesiredAngle = math.rad(6) + math.rad(velo) + (velo > 1 and math.abs(math.cos(tick() * 5)) / 3 or 0)
			end))
			vain:Clean(function()
				if capePart  then capePart:Destroy();  capePart = nil  end
				if capeMotor then capeMotor:Destroy(); capeMotor = nil end
			end)
		else
			if capePart  then capePart:Destroy();  capePart = nil  end
			if capeMotor then capeMotor:Destroy(); capeMotor = nil end
		end
	end,
})
end

-- ── RENDER — China Hat ─────────────────────────────────────────────────────────
do
local chinaHatPart

local ChinaHat
ChinaHat = Render:CreateModule({
	Name    = 'China Hat',
	Tooltip = 'Places a bamboo hat on your head',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			local cam = workspace.CurrentCamera
			chinaHatPart = Instance.new('MeshPart')
			chinaHatPart.Size       = Vector3.new(3, 0.7, 3)
			chinaHatPart.Name       = 'ChinaHat'
			chinaHatPart.MeshId     = 'rbxassetid://1778999'
			chinaHatPart.CanCollide = false
			chinaHatPart.CanQuery   = false
			chinaHatPart.Massless   = true
			chinaHatPart.Color      = Color3.fromRGB(210, 170, 90)
			chinaHatPart.Material   = Enum.Material.SmoothPlastic
			chinaHatPart.Parent     = cam

			local weld
			local function attachHat()
				if weld then weld:Destroy() end
				local char = lplr.Character
				if not char then return end
				local head = char:FindFirstChild('Head')
				if not head then return end
				chinaHatPart.CFrame = head.CFrame + Vector3.new(0, 1, 0)
				weld = Instance.new('WeldConstraint')
				weld.Part0  = chinaHatPart
				weld.Part1  = head
				weld.Parent = chinaHatPart
			end

			attachHat()
			vain:Clean(lplr.CharacterAdded:Connect(function()
				task.wait(0.5); if ChinaHat.Enabled then attachHat() end
			end))
			vain:Clean(runService.Heartbeat:Connect(function()
				if not chinaHatPart then return end
				local firstPerson = (cam.CFrame.Position - cam.Focus.Position).Magnitude <= 0.6
				chinaHatPart.LocalTransparencyModifier = firstPerson and 1 or 0
			end))
			vain:Clean(function()
				if chinaHatPart then chinaHatPart:Destroy(); chinaHatPart = nil end
			end)
		else
			if chinaHatPart then chinaHatPart:Destroy(); chinaHatPart = nil end
		end
	end,
})
end

-- ── RENDER — Atmosphere ────────────────────────────────────────────────────────
do
local atmosObjects  = {}
local atmosDensity  = 0.3
local atmosHaze     = 2

local Atmosphere
Atmosphere = Render:CreateModule({
	Name    = 'Atmosphere',
	Tooltip = 'Clears lighting effects and adds a custom atmosphere',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			for _, v in lightingService:GetChildren() do
				if v:IsA('Atmosphere') or v:IsA('Bloom') or v:IsA('ColorCorrectionEffect') or v:IsA('SunRaysEffect') then
					v.Parent = workspace.CurrentCamera
					table.insert(atmosObjects, v)
				end
			end
			local a = Instance.new('Atmosphere')
			a.Density = atmosDensity
			a.Haze    = atmosHaze
			a.Parent  = lightingService
			vain:Clean(a)
			table.insert(atmosObjects, a)
			vain:Clean(function()
				for _, v in atmosObjects do pcall(function() v.Parent = lightingService end) end
				table.clear(atmosObjects)
			end)
		else
			for _, v in atmosObjects do pcall(function() v.Parent = lightingService end) end
			table.clear(atmosObjects)
		end
	end,
})

Atmosphere:CreateSlider({
	Name    = 'Density',
	Min     = 0,
	Max     = 100,
	Default = 30,
	Function = function(val)
		atmosDensity = val / 100
		local atm = lightingService:FindFirstChildOfClass('Atmosphere')
		if atm then atm.Density = atmosDensity end
	end,
})

Atmosphere:CreateSlider({
	Name    = 'Haze',
	Min     = 0,
	Max     = 100,
	Default = 20,
	Function = function(val)
		atmosHaze = val / 10
		local atm = lightingService:FindFirstChildOfClass('Atmosphere')
		if atm then atm.Haze = atmosHaze end
	end,
})
end

-- ── RENDER — Search ────────────────────────────────────────────────────────────
do
local searchHighlights = {}
local searchName       = ''

local function clearSearch()
	for _, h in searchHighlights do pcall(h.Destroy, h) end
	table.clear(searchHighlights)
end

local function doSearch(name)
	clearSearch()
	if name == '' then return end
	for _, part in workspace:GetDescendants() do
		if part.Name:lower():find(name:lower(), 1, true) and part:IsA('BasePart') then
			local h = Instance.new('Highlight')
			h.FillColor    = Color3.fromRGB(255, 200, 0)
			h.OutlineColor = Color3.fromRGB(255, 255, 0)
			h.DepthMode    = Enum.HighlightDepthMode.AlwaysOnTop
			h.Adornee      = part
			h.Parent       = part
			table.insert(searchHighlights, h)
		end
	end
end

local Search
Search = Render:CreateModule({
	Name    = 'Search',
	Tooltip = 'Highlights workspace parts by name',
	Bind    = {},
	Function = function(enabled)
		if not enabled then clearSearch() end
	end,
})

Search:CreateTextBox({
	Name        = 'Part Name',
	Placeholder = 'e.g. Door, Wall...',
	Function = function(val)
		searchName = val or ''
		if Search.Enabled then doSearch(searchName) end
	end,
})
end

-- ── RENDER — Gaming Chair ──────────────────────────────────────────────────────
do
local chairPart

local GamingChair
GamingChair = Render:CreateModule({
	Name    = 'Gaming Chair',
	Tooltip = 'Sit in the best gaming chair known to mankind',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			chairPart = Instance.new('MeshPart')
			chairPart.Size       = Vector3.new(2, 3, 2)
			chairPart.Color      = Color3.fromRGB(21, 21, 21)
			chairPart.MeshId     = 'rbxassetid://12972961089'
			chairPart.Material   = Enum.Material.SmoothPlastic
			chairPart.CanCollide = false
			chairPart.Massless   = true
			chairPart.Parent     = workspace

			local hl = Instance.new('Highlight')
			hl.FillTransparency    = 1
			hl.OutlineColor        = Color3.fromRGB(255, 80, 80)
			hl.OutlineTransparency = 0.2
			hl.DepthMode           = Enum.HighlightDepthMode.Occluded
			hl.Parent              = chairPart

			local chairWeld
			local function attachChair()
				if chairWeld then chairWeld:Destroy() end
				local hrp = getHRP()
				if not hrp then return end
				chairPart.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(-90), 0)
				chairWeld = Instance.new('WeldConstraint')
				chairWeld.Part0  = chairPart
				chairWeld.Part1  = hrp
				chairWeld.Parent = chairPart
			end

			attachChair()
			vain:Clean(lplr.CharacterAdded:Connect(function()
				task.wait(0.5); if GamingChair.Enabled then attachChair() end
			end))
			vain:Clean(chairPart)
			vain:Clean(function()
				if chairPart then chairPart:Destroy(); chairPart = nil end
			end)
		else
			if chairPart then chairPart:Destroy(); chairPart = nil end
		end
	end,
})
end

-- ── RENDER — Player Model ──────────────────────────────────────────────────────
do
local modelMeshes = {}
local modelMeshId = ''
local modelScale  = 1

local function removeModel(p)
	if modelMeshes[p] then modelMeshes[p]:Destroy(); modelMeshes[p] = nil end
end

local function addModel(p)
	if p == lplr then return end
	if modelMeshes[p] then return end
	if modelMeshId == '' then return end
	local char = p.Character
	if not char then return end
	local torso = char:FindFirstChild('UpperTorso') or char:FindFirstChild('Torso')
	if not torso then return end
	local part = Instance.new('Part')
	part.Size       = Vector3.new(3, 3, 3)
	part.CFrame     = torso.CFrame
	part.CanCollide = false
	part.CanQuery   = false
	part.Massless   = true
	part.Parent     = workspace
	local mesh = Instance.new('SpecialMesh')
	mesh.MeshId = modelMeshId
	mesh.Scale  = Vector3.one * modelScale
	mesh.Parent = part
	local weld = Instance.new('WeldConstraint')
	weld.Part0  = part
	weld.Part1  = torso
	weld.Parent = part
	modelMeshes[p] = part
end

local PlayerModel
PlayerModel = Render:CreateModule({
	Name    = 'Player Model',
	Tooltip = 'Replaces player models with a custom mesh',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			for _, p in getLivingPlayers() do addModel(p) end
			vain:Clean(playersService.PlayerAdded:Connect(function(p)
				vain:Clean(p.CharacterAdded:Connect(function() task.wait(1); addModel(p) end))
			end))
			vain:Clean(playersService.PlayerRemoving:Connect(removeModel))
			vain:Clean(function() for p in modelMeshes do removeModel(p) end end)
		else
			for p in modelMeshes do removeModel(p) end
		end
	end,
})

PlayerModel:CreateTextBox({
	Name        = 'Mesh ID',
	Placeholder = 'rbxassetid://...',
	Function = function(val)
		modelMeshId = val or ''
		if PlayerModel.Enabled then
			for p in modelMeshes do removeModel(p) end
			for _, p in getLivingPlayers() do addModel(p) end
		end
	end,
})

PlayerModel:CreateSlider({
	Name    = 'Scale',
	Min     = 1,
	Max     = 50,
	Default = 10,
	Function = function(val)
		modelScale = val / 10
		for _, part in modelMeshes do
			local m = part:FindFirstChildOfClass('SpecialMesh')
			if m then m.Scale = Vector3.one * modelScale end
		end
	end,
})
end

-- ── UTILITY — Blink ────────────────────────────────────────────────────────────
do
local blinkAutoSend   = false
local blinkAutoLength = 0.5

local Blink
Blink = Utility:CreateModule({
	Name    = 'Blink',
	Tooltip = 'Chokes physics packets until disabled',
	Bind    = {},
	Function = function(enabled)
		if not setfflag then
			vain:CreateNotification('Blink', 'setfflag not available', 4, 'alert')
			Blink:Toggle(); return
		end
		if enabled then
			setfflag('S2PhysicsSenderRate', '0')
			setfflag('DataSenderRate', '0')
			vain:Clean(runService.Heartbeat:Connect(function()
				if not Blink.Enabled then return end
				if blinkAutoSend and tick() % (blinkAutoLength + 0.1) > blinkAutoLength then
					setfflag('S2PhysicsSenderRate', '15')
					setfflag('DataSenderRate', '60')
					task.wait(0.03)
					setfflag('S2PhysicsSenderRate', '0')
					setfflag('DataSenderRate', '0')
				end
			end))
		else
			setfflag('S2PhysicsSenderRate', '15')
			setfflag('DataSenderRate', '60')
		end
	end,
})

Blink:CreateToggle({
	Name    = 'Auto Send',
	Default = false,
	Function = function(val) blinkAutoSend = val end,
})

Blink:CreateSlider({
	Name    = 'Send Interval',
	Min     = 1,
	Max     = 30,
	Default = 5,
	Function = function(val) blinkAutoLength = val / 10 end,
})
end

-- ── UTILITY — Disabler ─────────────────────────────────────────────────────────
do
local disablerOld

local Disabler
Disabler = Utility:CreateModule({
	Name    = 'Disabler',
	Tooltip = 'Suppresses GetPropertyChangedSignal detections on movement',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			if not hookfunction then
				vain:CreateNotification('Disabler', 'hookfunction not available', 4, 'alert')
				Disabler:Toggle(); return
			end
			local function patchChar(char)
				if not char then return end
				local hrp = char:FindFirstChild('HumanoidRootPart')
				if not hrp then return end
				disablerOld = hookfunction(hrp.GetPropertyChangedSignal, function(self, prop)
					if prop == 'CFrame' or prop == 'Position' then
						return Instance.new('BindableEvent').Event
					end
					return disablerOld(self, prop)
				end)
			end
			patchChar(lplr.Character)
			vain:Clean(lplr.CharacterAdded:Connect(function(c) task.wait(0.1); patchChar(c) end))
		else
			if disablerOld then
				local hrp = getHRP()
				if hrp then pcall(hookfunction, hrp.GetPropertyChangedSignal, disablerOld) end
				disablerOld = nil
			end
		end
	end,
})
end

-- ── WORLD — Safe Walk ──────────────────────────────────────────────────────────
do
local swOld, swControls

local SafeWalk
SafeWalk = World:CreateModule({
	Name    = 'Safe Walk',
	Tooltip = 'Prevents you from walking off ledges',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			local ok, controls = pcall(function()
				return require(lplr.PlayerScripts.PlayerModule).controls
			end)
			if not ok or not controls then
				vain:CreateNotification('Safe Walk', 'Could not access PlayerModule', 4, 'alert')
				SafeWalk:Toggle(); return
			end
			swControls = controls
			swOld = controls.moveFunction
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			controls.moveFunction = function(self, vec, face)
				local hrp = getHRP()
				if hrp and vec ~= Vector3.zero then
					params.FilterDescendantsInstances = {lplr.Character, workspace.CurrentCamera}
					local movedir = hrp.Position + vec
					if not workspace:Raycast(movedir, Vector3.new(0, -15, 0), params) then
						vec = Vector3.zero
					end
				end
				return swOld(self, vec, face)
			end
		else
			if swControls and swOld then
				swControls.moveFunction = swOld
				swControls = nil; swOld = nil
			end
		end
	end,
})
end

-- ── LEGIT — Disguise ───────────────────────────────────────────────────────────
do
local disguiseId   = ''
local disguiseMode = 'Character'

local Disguise
Disguise = Legit:CreateModule({
	Name    = 'Disguise',
	Tooltip = 'Load another player\'s appearance or animation pack by ID',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			local function applyDisguise(char)
				if not char or disguiseId == '' then return end
				local id = tonumber(disguiseId)
				if not id then return end
				pcall(function()
					local hd
					if disguiseMode == 'Character' then
						hd = playersService:GetHumanoidDescriptionFromUserId(id)
					else
						hd = playersService:GetHumanoidDescriptionFromPackageId(id)
					end
					char:FindFirstChildOfClass('Humanoid'):ApplyDescription(hd)
				end)
			end
			applyDisguise(lplr.Character)
			vain:Clean(lplr.CharacterAdded:Connect(function(c)
				task.wait(1)
				if Disguise.Enabled then applyDisguise(c) end
			end))
		end
	end,
})

Disguise:CreateDropdown({
	Name    = 'Mode',
	List    = {'Character', 'Animation'},
	Default = 'Character',
	Function = function(val) disguiseMode = val end,
})

Disguise:CreateTextBox({
	Name        = 'User / Package ID',
	Placeholder = 'Numeric ID',
	Function = function(val) disguiseId = val or '' end,
})
end

-- ── LEGIT — Memory ─────────────────────────────────────────────────────────────
do
local Memory
Memory = Legit:CreateModule({
	Name    = 'Memory',
	Tooltip = 'Notifies you of current Roblox memory usage every 5 seconds',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			task.spawn(function()
				while Memory.Enabled do
					local perf = statsService:FindFirstChild('PerformanceStats')
					local mem  = perf and perf:FindFirstChild('Memory')
					local mb   = mem and math.floor(tonumber(mem:GetValue()) or 0) or 0
					vain:CreateNotification('Memory', mb .. ' MB', 4)
					task.wait(5)
				end
			end)
		end
	end,
})
end

-- ── LEGIT — Song Beats ─────────────────────────────────────────────────────────
do
local songObj       = nil
local songVolume    = 100
local beatFovOn     = true
local beatFovAdj    = 5
local beatOldFov

local SongBeats
SongBeats = Legit:CreateModule({
	Name    = 'Song Beats',
	Tooltip = 'Built-in audio player (provide rbxassetid)',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			songObj = Instance.new('Sound')
			songObj.Volume = songVolume / 100
			songObj.Looped = true
			songObj.Parent = workspace
			beatOldFov = workspace.CurrentCamera.FieldOfView
			vain:Clean(songObj)
		else
			if songObj  then songObj:Destroy(); songObj = nil end
			if beatOldFov then workspace.CurrentCamera.FieldOfView = beatOldFov; beatOldFov = nil end
		end
	end,
})

SongBeats:CreateTextBox({
	Name        = 'Sound ID',
	Placeholder = 'rbxassetid://...',
	Function = function(val)
		if songObj then
			songObj.SoundId = val:find('rbxassetid') and val or ('rbxassetid://' .. (val or ''))
			songObj:Play()
		end
	end,
})

SongBeats:CreateSlider({
	Name    = 'Volume',
	Min     = 0,
	Max     = 100,
	Default = 100,
	Function = function(val)
		songVolume = val
		if songObj then songObj.Volume = val / 100 end
	end,
})

SongBeats:CreateToggle({
	Name    = 'Beat FOV',
	Default = true,
	Function = function(val) beatFovOn = val end,
})

SongBeats:CreateSlider({
	Name    = 'FOV Adjustment',
	Min     = 1,
	Max     = 30,
	Default = 5,
	Function = function(val) beatFovAdj = val end,
})
end

-- ── LEGIT — Animation Changer ──────────────────────────────────────────────────
do
local animIds = {Run = '', Walk = '', Jump = '', Fall = '', Idle = ''}

local function applyAnimations()
	local char = lplr.Character
	if not char then return end
	local animate = char:FindFirstChild('Animate')
	if not animate then return end
	local slotMap = {Run = 'run', Walk = 'walk', Jump = 'jump', Fall = 'fall', Idle = 'idle'}
	for key, slot in slotMap do
		local id = animIds[key]
		if id and id ~= '' then
			local s = animate:FindFirstChild(slot)
			if s then
				local a = s:FindFirstChildOfClass('Animation')
				if a then a.AnimationId = id:find('rbxassetid') and id or ('rbxassetid://' .. id) end
			end
		end
	end
	local hum = char:FindFirstChildOfClass('Humanoid')
	if hum then hum.WalkSpeed = hum.WalkSpeed end
end

local AnimChanger
AnimChanger = Legit:CreateModule({
	Name    = 'Animation Changer',
	Tooltip = 'Override character animations with custom IDs',
	Bind    = {},
	Function = function(enabled)
		if enabled then
			applyAnimations()
			vain:Clean(lplr.CharacterAdded:Connect(function()
				task.wait(1)
				if AnimChanger.Enabled then applyAnimations() end
			end))
		end
	end,
})

for _, slot in {'Run', 'Walk', 'Jump', 'Fall', 'Idle'} do
	local s = slot
	AnimChanger:CreateTextBox({
		Name        = s,
		Placeholder = 'rbxassetid://...',
		Function = function(val)
			animIds[s] = val or ''
			if AnimChanger.Enabled then applyAnimations() end
		end,
	})
end
end

-- ── LEGIT — FFlag Editor ───────────────────────────────────────────────────────
if setfflag then
do
local FFlagEditor
FFlagEditor = Legit:CreateModule({
	Name    = 'FFlag Editor',
	Tooltip = 'Apply FFlags via JSON (e.g. {"FIntFoo": "123"})',
	Bind    = {},
	Function = function(enabled)
		if not enabled then
			vain:CreateNotification('FFlag Editor', 'Restart Roblox to revert FFlags', 8, 'alert')
		end
	end,
})

FFlagEditor:CreateTextBox({
	Name        = 'JSON Flags',
	Placeholder = '{"FlagName": "value"}',
	Function = function(val)
		if not val or val == '' then return end
		local ok, tbl = pcall(function() return httpService:JSONDecode(val) end)
		if not ok or type(tbl) ~= 'table' then
			vain:CreateNotification('FFlag Editor', 'Invalid JSON', 4, 'alert')
			return
		end
		local count = 0
		for k, v in tbl do
			local clean = k:gsub('DFInt',''):gsub('DFFlag',''):gsub('FFlag',''):gsub('FInt',''):gsub('DFString',''):gsub('FString','')
			pcall(setfflag, clean, tostring(v))
			count += 1
		end
		vain:CreateNotification('FFlag Editor', count .. ' flag(s) applied', 5)
	end,
})
end
end
