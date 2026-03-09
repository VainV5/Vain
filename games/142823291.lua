-- Vain — Murder Mystery 2 (142823291)

local vain = shared.vain
local cloneref = cloneref or function(obj) return obj end

local playersService = cloneref(game:GetService('Players'))
local inputService   = cloneref(game:GetService('UserInputService'))
local lplr           = playersService.LocalPlayer

-- ── Remote paths ──────────────────────────────────────────────────────────────
local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local Remotes           = ReplicatedStorage:WaitForChild('Remotes', 10)
local GameplayRemotes   = Remotes and Remotes:FindFirstChild('Gameplay')
local ExtrasRemotes     = Remotes and Remotes:FindFirstChild('Extras')

-- ── Role colours ──────────────────────────────────────────────────────────────
local ROLE_COLOR = {
	Murderer = Color3.fromRGB(220, 50,  50),
	Sheriff  = Color3.fromRGB(60,  130, 255),
	Innocent = Color3.fromRGB(60,  220, 60),
	Hero     = Color3.fromRGB(255, 200, 50),
}
local UNKNOWN_COLOR = Color3.fromRGB(180, 180, 180)

local function roleColor(role)
	return ROLE_COLOR[role] or UNKNOWN_COLOR
end

-- ── State ─────────────────────────────────────────────────────────────────────
local espEnabled         = false
local showNames          = true
local fillTransp         = 0.7
local outlineTransp      = 0.0
local playerRoles        = {}   -- [player.Name] = "Murderer" | "Sheriff" | "Innocent" | nil
local espObjects         = {}   -- [player]      = { highlight, billboard, label }

-- ESP container — parented to the protected GUI layer
local espContainer = Instance.new('Folder')
espContainer.Name  = 'VainESP_MM2'
espContainer.Parent = (gethui and gethui()) or lplr:WaitForChild('PlayerGui')

-- ── ESP object management ─────────────────────────────────────────────────────
local function removeESP(player)
	local objs = espObjects[player]
	if not objs then return end
	for _, obj in objs do
		if typeof(obj) ~= 'string' then
			pcall(obj.Destroy, obj)
		end
	end
	espObjects[player] = nil
end

local function buildESP(player)
	if not espEnabled then return end
	if player == lplr then return end
	local char = player.Character
	if not char then return end
	local hrp  = char:FindFirstChild('HumanoidRootPart')
	if not hrp then return end

	local role = playerRoles[player.Name]
	local col  = roleColor(role)

	local objs = espObjects[player]
	if not objs then
		objs = {}
		espObjects[player] = objs
	end

	-- Highlight (coloured box, works through walls with AlwaysOnTop)
	local hl = objs.highlight
	if not hl or not hl.Parent then
		hl = Instance.new('Highlight')
		hl.Name      = 'VainHL'
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Parent    = espContainer
		objs.highlight = hl
	end
	hl.Adornee             = char
	hl.FillColor           = col
	hl.OutlineColor        = col
	hl.FillTransparency    = fillTransp
	hl.OutlineTransparency = outlineTransp

	-- BillboardGui name + role label
	local bb = objs.billboard
	if not bb or not bb.Parent then
		bb = Instance.new('BillboardGui')
		bb.Name         = 'VainESPLabel'
		bb.Size         = UDim2.fromOffset(120, 36)
		bb.StudsOffset  = Vector3.new(0, 3.2, 0)
		bb.AlwaysOnTop  = true
		bb.ResetOnSpawn = false
		bb.Parent       = espContainer

		local lbl = Instance.new('TextLabel')
		lbl.Size                  = UDim2.fromScale(1, 1)
		lbl.BackgroundTransparency = 1
		lbl.TextStrokeTransparency = 0.4
		lbl.TextStrokeColor3      = Color3.new(0, 0, 0)
		lbl.TextSize              = 13
		lbl.Font                  = Enum.Font.GothamBold
		lbl.TextWrapped           = true
		lbl.Parent                = bb

		objs.billboard = bb
		objs.label     = lbl
	end

	bb.Adornee = hrp
	bb.Enabled = showNames

	local lbl = objs.label
	lbl.Text       = player.Name .. '\n[' .. (role or '?') .. ']'
	lbl.TextColor3 = col
end

local function refreshAll()
	for _, player in playersService:GetPlayers() do
		if player ~= lplr then
			buildESP(player)
		end
	end
end

local function clearAll()
	for player in espObjects do
		removeESP(player)
	end
end

-- ── Role data ─────────────────────────────────────────────────────────────────
local function applyPlayerData(data)
	if type(data) ~= 'table' then return end
	for name, pdata in data do
		if type(pdata) == 'table' and type(pdata.Role) == 'string' then
			playerRoles[name] = pdata.Role
			local player = playersService:FindFirstChild(name)
			if player then buildESP(player) end
		end
	end
end

-- PlayerDataChanged fires with the full PlayerData table whenever roles update
if GameplayRemotes then
	local pdc = GameplayRemotes:FindFirstChild('PlayerDataChanged')
	if pdc then
		vain:Clean(pdc.OnClientEvent:Connect(applyPlayerData))
	end

	-- Reset roles at round start so dead / spectating players go grey
	local rs = GameplayRemotes:FindFirstChild('RoundStart')
	if rs then
		vain:Clean(rs.OnClientEvent:Connect(function()
			table.clear(playerRoles)
			if espEnabled then refreshAll() end
		end))
	end
end

-- Poll GetData2 every 2 s as a fallback (catches any missed PlayerDataChanged)
task.spawn(function()
	while true do
		task.wait(2)
		if espEnabled and ExtrasRemotes then
			local getdata = ExtrasRemotes:FindFirstChild('GetData2')
			if getdata then
				local ok, data = pcall(getdata.InvokeServer, getdata)
				if ok then applyPlayerData(data) end
			end
		end
	end
end)

-- ── Player / character lifecycle ──────────────────────────────────────────────
vain:Clean(playersService.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.15)
		buildESP(player)
	end)
end))

vain:Clean(playersService.PlayerRemoving:Connect(function(player)
	playerRoles[player.Name] = nil
	removeESP(player)
end))

for _, player in playersService:GetPlayers() do
	if player ~= lplr then
		player.CharacterAdded:Connect(function()
			task.wait(0.15)
			buildESP(player)
		end)
	end
end

-- ── Vain UI ───────────────────────────────────────────────────────────────────
local Render = vain.Categories.Render

local esp = Render:CreateModule({
	Name = 'Player ESP',
	Bind = {},
	Function = function(enabled)
		espEnabled = enabled
		if enabled then
			refreshAll()
		else
			clearAll()
		end
	end,
})

esp:CreateToggle({
	Name = 'Show Names',
	Function = function(enabled)
		showNames = enabled
		for _, objs in espObjects do
			if objs.billboard then
				objs.billboard.Enabled = enabled
			end
		end
	end,
})

esp:CreateSlider({
	Name    = 'Fill Opacity',
	Min     = 0,
	Max     = 100,
	Default = 30,
	Function = function(val)
		fillTransp = 1 - (val / 100)
		for _, objs in espObjects do
			if objs.highlight then
				objs.highlight.FillTransparency = fillTransp
			end
		end
	end,
})

esp:CreateSlider({
	Name    = 'Outline Opacity',
	Min     = 0,
	Max     = 100,
	Default = 100,
	Function = function(val)
		outlineTransp = 1 - (val / 100)
		for _, objs in espObjects do
			if objs.highlight then
				objs.highlight.OutlineTransparency = outlineTransp
			end
		end
	end,
})

-- ── Teleport helpers ──────────────────────────────────────────────────────────
local function getHRP()
	local char = lplr.Character
	return char and char:FindFirstChild('HumanoidRootPart')
end

local function tpTo(pos)
	local hrp = getHRP()
	if hrp then hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) end
end

local function tpToPlayer(player)
	if not player or not player.Character then return end
	local hrp = player.Character:FindFirstChild('HumanoidRootPart')
	if hrp then tpTo(hrp.Position) end
end

local function findByRole(role)
	for name, r in playerRoles do
		if r == role then
			return playersService:FindFirstChild(name)
		end
	end
end

-- ── Combat — role teleports ───────────────────────────────────────────────────
local Combat = vain.Categories.Combat

local tpMurderer = Combat:CreateModule({
	Name = 'Teleport to Murderer',
	Function = function(enabled)
		if not enabled then return end
		local target = findByRole('Murderer')
		if target then
			tpToPlayer(target)
		else
			vain:CreateNotification('Vain', 'Murderer not found', 3, 'alert')
		end
		tpMurderer:Toggle()
	end,
})

local tpSheriff = Combat:CreateModule({
	Name = 'Teleport to Sheriff',
	Function = function(enabled)
		if not enabled then return end
		local target = findByRole('Sheriff')
		if target then
			tpToPlayer(target)
		else
			vain:CreateNotification('Vain', 'Sheriff not found', 3, 'alert')
		end
		tpSheriff:Toggle()
	end,
})

local tpPlayerTarget = 'None'
local tpPlayer = Combat:CreateModule({
	Name = 'Teleport to Player',
	Function = function(enabled)
		if not enabled then return end
		local target = playersService:FindFirstChild(tpPlayerTarget)
		if target then
			tpToPlayer(target)
		else
			vain:CreateNotification('Vain', 'Player not found', 3, 'alert')
		end
		tpPlayer:Toggle()
	end,
})

local playerOptions = {'None'}
for _, p in playersService:GetPlayers() do
	if p ~= lplr then table.insert(playerOptions, p.Name) end
end

local tpPlayerDropdown = tpPlayer:CreateDropdown({
	Name    = 'Target',
	Options = playerOptions,
	Default = 'None',
	Function = function(val)
		tpPlayerTarget = val
	end,
})

-- Keep dropdown in sync as players join/leave
playersService.PlayerAdded:Connect(function(p)
	table.insert(playerOptions, p.Name)
end)
playersService.PlayerRemoving:Connect(function(p)
	local i = table.find(playerOptions, p.Name)
	if i then table.remove(playerOptions, i) end
	if tpPlayerTarget == p.Name then tpPlayerTarget = 'None' end
end)

-- ── Utility — click teleport ──────────────────────────────────────────────────
local Utility = vain.Categories.Utility

local clickTPConn
local clickTP = Utility:CreateModule({
	Name = 'Click Teleport',
	Function = function(enabled)
		if enabled then
			clickTPConn = inputService.InputBegan:Connect(function(input, gpe)
				if gpe then return end
				if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
				if not inputService:IsKeyDown(Enum.KeyCode.LeftControl) then return end
				local hrp = getHRP()
				if not hrp then return end
				local cam = workspace.CurrentCamera
				local mouse = inputService:GetMouseLocation()
				local ray = cam:ScreenPointToRay(mouse.X, mouse.Y)
				local params = RaycastParams.new()
				params.FilterDescendantsInstances = {lplr.Character}
				params.FilterType = Enum.RaycastFilterType.Exclude
				local result = workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
				if result then
					hrp.CFrame = CFrame.new(result.Position + Vector3.new(0, 3, 0))
				end
			end)
		else
			if clickTPConn then
				clickTPConn:Disconnect()
				clickTPConn = nil
			end
		end
	end,
})

clickTP:CreateToggle({
	Name = 'Require Ctrl',
	Function = function() end,
})

-- ── World — map & lobby teleport ──────────────────────────────────────────────
local World = vain.Categories.World

local tpMap = World:CreateModule({
	Name = 'Teleport to Map',
	Function = function(enabled)
		if not enabled then return end
		-- MM2 loads the map as a Model in workspace during a round
		-- Find the largest non-character model (the map)
		local best, bestCount = nil, 0
		for _, child in workspace:GetChildren() do
			if child:IsA('Model') and child ~= workspace.Terrain then
				-- skip player characters
				local isChar = false
				for _, p in playersService:GetPlayers() do
					if p.Character == child then isChar = true; break end
				end
				if not isChar then
					local count = #child:GetDescendants()
					if count > bestCount then
						bestCount = count
						best = child
					end
				end
			end
		end
		if best then
			local part = best.PrimaryPart or best:FindFirstChildWhichIsA('BasePart')
			if part then
				tpTo(part.Position)
			else
				vain:CreateNotification('Vain', 'Map center not found', 3, 'alert')
			end
		else
			vain:CreateNotification('Vain', 'No map loaded', 3, 'alert')
		end
		tpMap:Toggle()
	end,
})

local tpLobby = World:CreateModule({
	Name = 'Teleport to Lobby',
	Function = function(enabled)
		if not enabled then return end
		-- Try known MM2 lobby structures
		local lobby = workspace:FindFirstChild('Lobby')
			or workspace:FindFirstChild('LobbySpawns')
		if lobby then
			local part = lobby:FindFirstChildWhichIsA('BasePart')
				or lobby:FindFirstChildWhichIsA('SpawnLocation')
			if part then tpTo(part.Position); tpLobby:Toggle(); return end
		end
		-- Fallback: any SpawnLocation in workspace
		local spawn = workspace:FindFirstChildWhichIsA('SpawnLocation')
		if spawn then
			tpTo(spawn.Position)
		else
			vain:CreateNotification('Vain', 'Lobby not found', 3, 'alert')
		end
		tpLobby:Toggle()
	end,
})
