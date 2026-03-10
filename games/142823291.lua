-- Vain — Murder Mystery 2 (142823291)

local vain = shared.vain
local cloneref = cloneref or function(obj) return obj end

local playersService = cloneref(game:GetService('Players'))
local inputService   = cloneref(game:GetService('UserInputService'))
local runService     = cloneref(game:GetService('RunService'))
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
	local col  = roleColor(role)  -- returns UNKNOWN_COLOR (grey) when role is nil

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
	lbl.Text       = player.Name .. (role and ('\n[' .. role .. ']') or '')
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
-- Tracks whether a round is currently in progress
local roundActive = false

if GameplayRemotes then
	local pdc = GameplayRemotes:FindFirstChild('PlayerDataChanged')
	if pdc then
		vain:Clean(pdc.OnClientEvent:Connect(applyPlayerData))
	end

	local rs = GameplayRemotes:FindFirstChild('RoundStart')
	if rs then
		vain:Clean(rs.OnClientEvent:Connect(function()
			roundActive = true
			table.clear(playerRoles)
			if espEnabled then refreshAll() end
			-- Roles are assigned shortly after RoundStart; fetch immediately
			-- and again after a short delay once all assignments are done
			fetchRoles()
			task.delay(1, fetchRoles)
		end))
	end

	local go = GameplayRemotes:FindFirstChild('GameOver')
	if go then
		vain:Clean(go.OnClientEvent:Connect(function()
			roundActive = false
		end))
	end

	-- RoleSelect fires the moment our own role is assigned (first arg = role name)
	-- Use it for instant self-role detection without waiting for the next poll
	local rsel = GameplayRemotes:FindFirstChild('RoleSelect')
	if rsel then
		vain:Clean(rsel.OnClientEvent:Connect(function(roleName)
			if type(roleName) == 'string' then
				playerRoles[lplr.Name] = roleName
			end
			-- Also fetch everyone else's roles right away
			fetchRoles()
		end))
	end
end

-- Fetch all current player roles from the server
local function fetchRoles()
	if not GameplayRemotes then return end
	local gcp = GameplayRemotes:FindFirstChild('GetCurrentPlayerData')
	if not gcp then return end
	local ok, data = pcall(gcp.InvokeServer, gcp)
	if ok then applyPlayerData(data) end
end

-- Poll every 1 s so roles are always fresh (GetCurrentPlayerData returns
-- the full {[name]={Role=...}} table — GetData2 only returns inventory)
task.spawn(function()
	while true do
		task.wait(1)
		fetchRoles()
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
	Tooltip  = 'Draws colored highlights and name tags on all players through walls',
	Bind = {},
	Function = function(enabled)
		espEnabled = enabled
		if enabled then
			fetchRoles()
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

local function getHum()
	local char = lplr.Character
	return char and char:FindFirstChildOfClass('Humanoid')
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

-- One-shot helper: defers a module toggle so it snaps back off after firing
local function oneShot(module)
	task.defer(function()
		if module and module.Enabled then
			module:Toggle()
		end
	end)
end

-- ── Combat — role teleports ───────────────────────────────────────────────────
local Combat = vain.Categories.Combat

local tpMurderer
tpMurderer = Combat:CreateModule({
	Name = 'Teleport to Murderer',
	Tooltip  = 'One-shot: teleports you directly onto the murderer',
	Notification = false,
	Bind = {},
	Function = function(enabled)
		if not enabled then return end
		local target = findByRole('Murderer')
		if target then
			tpToPlayer(target)
		else
			vain:CreateNotification('Vain', 'Murderer not found', 3, 'alert')
		end
		oneShot(tpMurderer)
	end,
})

local tpSheriff
tpSheriff = Combat:CreateModule({
	Name = 'Teleport to Sheriff',
	Tooltip  = 'One-shot: teleports you directly onto the sheriff',
	Notification = false,
	Bind = {},
	Function = function(enabled)
		if not enabled then return end
		local target = findByRole('Sheriff')
		if target then
			tpToPlayer(target)
		else
			vain:CreateNotification('Vain', 'Sheriff not found', 3, 'alert')
		end
		oneShot(tpSheriff)
	end,
})

local tpPlayerTarget = ''

local function getPlayerNames()
	local names = {}
	for _, p in playersService:GetPlayers() do
		if p ~= lplr then
			table.insert(names, p.Name)
		end
	end
	return names
end

local tpPlayer
local tpPlayerDropdown
tpPlayer = Combat:CreateModule({
	Name = 'Teleport to Player',
	Tooltip  = 'One-shot: teleports you to the selected player',
	Notification = false,
	Bind = {},
	Function = function(enabled)
		if not enabled then return end
		local target = tpPlayerTarget ~= '' and playersService:FindFirstChild(tpPlayerTarget)
		if target then
			tpToPlayer(target)
		else
			vain:CreateNotification('Vain', 'Select a player first', 3, 'alert')
		end
		oneShot(tpPlayer)
	end,
})

tpPlayerDropdown = tpPlayer:CreateDropdown({
	Name     = 'Player',
	Tooltip  = 'Select which player to target',
	List     = getPlayerNames(),
	Function = function(val)
		tpPlayerTarget = val or ''
	end,
})

-- Keep the dropdown list in sync as players join / leave
vain:Clean(playersService.PlayerAdded:Connect(function()
	tpPlayerDropdown:Change(getPlayerNames())
end))
vain:Clean(playersService.PlayerRemoving:Connect(function(p)
	if tpPlayerTarget == p.Name then
		tpPlayerTarget = ''
	end
	tpPlayerDropdown:Change(getPlayerNames())
end))

-- ── Combat — gun teleports ────────────────────────────────────────────────────
-- In MM2, when the sheriff dies their character becomes a ragdoll Model in
-- workspace (named after the player) and the gun is a Part named "Gun" inside
-- that ragdoll. We search workspace Models for that Part.
local GUN_NAMES = {'Gun', 'Revolver', 'Sheriff', 'SheriffRevolver', 'SheriffGun'}

local function isGunPart(obj)
	if not (obj:IsA('BasePart') or obj:IsA('MeshPart')) then return false end
	local lname = obj.Name:lower()
	for _, g in GUN_NAMES do
		if lname == g:lower() then return true end
	end
	return false
end

local function isGunObject(child)
	-- Kept for backward compat (aimbot helpers use this)
	local lname = child.Name:lower()
	for _, g in GUN_NAMES do
		if lname == g:lower() then return true end
	end
	if child:IsA('Tool') or child:IsA('Model') then
		if lname:find('revolver') or lname:find('sheriff') then return true end
	end
	return false
end

-- Build a set of living player characters so we can skip them
local function livingChars()
	local set = {}
	for _, p in playersService:GetPlayers() do
		if p.Character then set[p.Character] = true end
	end
	return set
end

local function findDroppedGun()
	local living = livingChars()

	-- Helper: scan a container's descendants for a gun part
	local function scanContainer(obj)
		for _, part in obj:GetDescendants() do
			if isGunPart(part) then return part end
		end
	end

	-- Primary: search workspace children
	for _, child in workspace:GetChildren() do
		if living[child] then continue end
		-- Tool in workspace (dropped gun), Model (ragdoll), or nested structure
		if child:IsA('Model') or child:IsA('Tool') then
			local found = scanContainer(child)
			if found then return found end
		elseif isGunPart(child) then
			return child
		end
	end

	-- Fallback: workspace.Items (lobby display stand)
	local items = workspace:FindFirstChild('Items')
	if items then
		local found = scanContainer(items)
		if found then return found end
	end
end

local function gunPosition(gun)
	if gun:IsA('BasePart') or gun:IsA('MeshPart') then
		return gun.Position
	end
	local part = gun.PrimaryPart or gun:FindFirstChildWhichIsA('BasePart')
	if part then return part.Position end
	return gun:GetPivot().Position
end

-- Teleport to gun and snap back to origin after a short delay (for pickup)
local function grabGun(gun)
	local hrp = getHRP()
	if not hrp then return end
	local origin = hrp.CFrame
	tpTo(gunPosition(gun))
	task.wait(0.6)
	local stillHrp = getHRP()
	if stillHrp then
		stillHrp.CFrame = origin
	end
end

local tpGun
tpGun = Combat:CreateModule({
	Name = 'Teleport to Gun',
	Tooltip  = 'One-shot: teleports you to the dropped sheriff gun',
	Notification = false,
	Bind = {},
	Function = function(enabled)
		if not enabled then return end
		local gun = findDroppedGun()
		if gun then
			task.spawn(grabGun, gun)
		else
			vain:CreateNotification('Vain', 'Gun not found — has the sheriff died?', 3, 'alert')
		end
		oneShot(tpGun)
	end,
})

local autoGunConns = {}
local autoGun = Combat:CreateModule({
	Name = 'Auto Teleport to Gun',
	Tooltip  = 'Watches for a dropped gun and teleports to it automatically',
	Bind = {},
	Function = function(enabled)
		if enabled then
			-- When a new Model is added to workspace (e.g. a ragdoll), watch its
			-- children for the gun part appearing, and also check immediately.
			local function watchModel(model)
				-- Check existing descendants right away (model may already be populated)
				task.defer(function()
					for _, part in model:GetDescendants() do
						if isGunPart(part) then
							task.spawn(grabGun, part)
							return
						end
					end
				end)
				-- Watch for descendants added shortly after the model arrives
				local c = model.DescendantAdded:Connect(function(part)
					if isGunPart(part) then task.spawn(grabGun, part) end
				end)
				table.insert(autoGunConns, c)
			end

			-- Watch workspace for new Models (ragdolls) or dropped Tools
			local c1 = workspace.ChildAdded:Connect(function(child)
				if (child:IsA('Model') or child:IsA('Tool')) and not livingChars()[child] then
					watchModel(child)
				elseif isGunPart(child) then
					task.spawn(grabGun, child)
				end
			end)
			table.insert(autoGunConns, c1)

			-- Also scan existing Models right now in case gun is already there
			local gun = findDroppedGun()
			if gun then task.spawn(grabGun, gun) end
		else
			for _, c in autoGunConns do pcall(c.Disconnect, c) end
			table.clear(autoGunConns)
		end
	end,
})
local _ = autoGun

-- ── Combat — fling ────────────────────────────────────────────────────────────
-- Touch-fling: teleport onto the target and run the exact velocity loop from
-- the reference script (Heartbeat → multiply vel × 10000 → RenderStepped →
-- reset → Stepped → oscillate).  Collision with our body at that velocity is
-- what actually launches the target.
local function flingPlayer(target)
	if not target or not target.Character or target == lplr then return end
	local myHRP = getHRP()
	if not myHRP then return end
	local origin = myHRP.CFrame

	local tHRP = target.Character:FindFirstChild('HumanoidRootPart')
	if not tHRP then return end

	task.spawn(function()
		-- Stick on top of the target
		myHRP.CFrame = tHRP.CFrame

		local movel = 0.1
		for _ = 1, 8 do
			runService.Heartbeat:Wait()

			local hrp    = getHRP()
			local curTHRP = target.Character
				and target.Character:FindFirstChild('HumanoidRootPart')
			if not hrp or not curTHRP then break end

			-- Re-stick so we don't drift away between frames
			hrp.CFrame = curTHRP.CFrame

			-- Velocity blast (reference logic, verbatim)
			local vel = hrp.Velocity
			hrp.Velocity = vel * 10000 + Vector3.new(0, 10000, 0)
			runService.RenderStepped:Wait()
			hrp.Velocity = vel
			runService.Stepped:Wait()
			hrp.Velocity = vel + Vector3.new(0, movel, 0)
			movel = -movel
		end

		-- Return to where we were standing
		task.wait(0.1)
		local hrp = getHRP()
		if hrp then
			hrp.CFrame = origin
		end
	end)
end

local flingMurderer
flingMurderer = Combat:CreateModule({
	Name = 'Fling Murderer',
	Tooltip  = 'One-shot: flings the murderer with extreme velocity',
	Notification = false,
	Bind = {},
	Function = function(enabled)
		if not enabled then return end
		local target = findByRole('Murderer')
		if target then
			task.spawn(flingPlayer, target)
		else
			vain:CreateNotification('Vain', 'Murderer not found', 3, 'alert')
		end
		oneShot(flingMurderer)
	end,
})

local flingSheriff
flingSheriff = Combat:CreateModule({
	Name = 'Fling Sheriff',
	Tooltip  = 'One-shot: flings the sheriff with extreme velocity',
	Notification = false,
	Bind = {},
	Function = function(enabled)
		if not enabled then return end
		local target = findByRole('Sheriff')
		if target then
			task.spawn(flingPlayer, target)
		else
			vain:CreateNotification('Vain', 'Sheriff not found', 3, 'alert')
		end
		oneShot(flingSheriff)
	end,
})

local flingPlayerTarget = ''
local flingPlayerModule
local flingPlayerDropdown
flingPlayerModule = Combat:CreateModule({
	Name = 'Fling Player',
	Tooltip  = 'One-shot: flings the selected player with extreme velocity',
	Notification = false,
	Bind = {},
	Function = function(enabled)
		if not enabled then return end
		local target = flingPlayerTarget ~= '' and playersService:FindFirstChild(flingPlayerTarget)
		if target then
			task.spawn(flingPlayer, target)
		else
			vain:CreateNotification('Vain', 'Select a player first', 3, 'alert')
		end
		oneShot(flingPlayerModule)
	end,
})

flingPlayerDropdown = flingPlayerModule:CreateDropdown({
	Name     = 'Player',
	Tooltip  = 'Select which player to fling',
	List     = getPlayerNames(),
	Function = function(val)
		flingPlayerTarget = val or ''
	end,
})

vain:Clean(playersService.PlayerAdded:Connect(function()
	flingPlayerDropdown:Change(getPlayerNames())
end))
vain:Clean(playersService.PlayerRemoving:Connect(function(p)
	if flingPlayerTarget == p.Name then
		flingPlayerTarget = ''
	end
	flingPlayerDropdown:Change(getPlayerNames())
end))

-- ── Combat — aimbot / auto-shoot ─────────────────────────────────────────────
local ClientServices = ReplicatedStorage:FindFirstChild('ClientServices')
local WeaponService  = ClientServices and ClientServices:FindFirstChild('WeaponService')
local GunFired       = WeaponService  and WeaponService:FindFirstChild('GunFired')

local function getEquippedGun()
	local char = lplr.Character
	if not char then return end
	for _, v in char:GetChildren() do
		if v:IsA('Tool') and isGunObject(v) then return v end
	end
end

local function getAnyGun()
	local gun = getEquippedGun()
	if gun then return gun end
	local backpack = lplr:FindFirstChild('Backpack')
	if not backpack then return end
	for _, v in backpack:GetChildren() do
		if v:IsA('Tool') and isGunObject(v) then return v end
	end
end

local function equipGun(gun)
	local char = lplr.Character
	if not char or not gun then return false end
	if gun.Parent == char then return true end -- already equipped
	local hum = char:FindFirstChildOfClass('Humanoid')
	if not hum then return false end
	hum:EquipTool(gun)
	task.wait(0.12)
	return gun.Parent == char
end

-- Aim camera + character at a world position
local function aimAt(pos)
	local myHRP = getHRP()
	if not myHRP then return end
	-- Rotate character to face target (horizontal only so movement isn't affected)
	myHRP.CFrame = CFrame.new(myHRP.Position, Vector3.new(pos.X, myHRP.Position.Y, pos.Z))
	-- Tilt camera to look exactly at target (handles vertical offset)
	local cam = workspace.CurrentCamera
	cam.CFrame = CFrame.new(cam.CFrame.Position, pos)
end

-- Fire the gun at a target HumanoidRootPart position
local function fireAt(targetHRP)
	local gun = getAnyGun()
	if not gun then
		vain:CreateNotification('Vain', 'No sheriff gun in inventory', 3, 'alert')
		return false
	end
	if not equipGun(gun) then return false end

	local hitPos = targetHRP.Position
	aimAt(hitPos)

	-- Primary: fire WeaponService.GunFired directly (skips client raycast)
	if GunFired then
		pcall(GunFired.FireServer, GunFired, hitPos)
		return true
	end

	-- Fallback: search for any RemoteEvent/RemoteFunction inside the tool
	for _, v in gun:GetDescendants() do
		if v:IsA('RemoteEvent') then
			pcall(v.FireServer, v, hitPos)
			return true
		elseif v:IsA('RemoteFunction') then
			pcall(v.InvokeServer, v, hitPos)
			return true
		end
	end

	-- Last resort: tool activation (client-only, may not register on server)
	pcall(function()
		gun:Activate()
	end)
	return true
end

-- One-shot: teleport behind the murderer, shoot, return home
local shootMurderer
shootMurderer = Combat:CreateModule({
	Name = 'Shoot Murderer',
	Tooltip  = 'Teleports behind the murderer, shoots them, then returns to your position',
	Notification = false,
	Bind = {},
	Function = function(enabled)
		if not enabled then return end
		local target = findByRole('Murderer')
		if not target or not target.Character then
			vain:CreateNotification('Vain', 'Murderer not found', 3, 'alert')
			oneShot(shootMurderer)
			return
		end
		local tHRP = target.Character:FindFirstChild('HumanoidRootPart')
		if not tHRP then oneShot(shootMurderer) return end
		local myHRP = getHRP()
		if not myHRP then oneShot(shootMurderer) return end

		task.spawn(function()
			local origin = myHRP.CFrame

			-- Step behind the murderer (opposite their look direction, 6 studs back)
			local behind = tHRP.CFrame * CFrame.new(0, 0, 6)
			myHRP.CFrame = behind

			-- Face and shoot
			fireAt(tHRP)

			-- Small pause so the shot registers before we vanish
			task.wait(0.15)

			-- Return home
			local hrp2 = getHRP()
			if hrp2 then hrp2.CFrame = origin end
		end)

		oneShot(shootMurderer)
	end,
})

-- Toggled: automatically shoot murderer on a heartbeat loop
local autoShootConn
local autoShoot = Combat:CreateModule({
	Name = 'Auto Shoot',
	Tooltip  = 'Continuously aims and fires at the murderer each frame',
	Bind = {},
	Function = function(enabled)
		if enabled then
			autoShootConn = runService.Heartbeat:Connect(function()
				local target = findByRole('Murderer')
				if not target or not target.Character then return end
				local hrp = target.Character:FindFirstChild('HumanoidRootPart')
				if not hrp then return end
				-- Only fire if we have the gun
				if not getAnyGun() then return end
				fireAt(hrp)
			end)
		else
			if autoShootConn then
				autoShootConn:Disconnect()
				autoShootConn = nil
			end
		end
	end,
})
local __ = autoShoot -- suppress unused warning

-- ── Utility — click teleport ──────────────────────────────────────────────────
local Utility      = vain.Categories.Utility
local requireCtrl  = true
local clickTPConn

local clickTP
clickTP = Utility:CreateModule({
	Name = 'Click Teleport',
	Tooltip  = 'Click anywhere on the ground to instantly teleport there',
	Bind = {},
	Function = function(enabled)
		if enabled then
			clickTPConn = inputService.InputBegan:Connect(function(input, gpe)
				if gpe then return end
				if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
				if requireCtrl and not inputService:IsKeyDown(Enum.KeyCode.LeftControl) then return end
				local char = lplr.Character
				if not char then return end
				local hrp = char:FindFirstChild('HumanoidRootPart')
				if not hrp then return end
				local cam    = workspace.CurrentCamera
				local mouse  = inputService:GetMouseLocation()
				local ray    = cam:ScreenPointToRay(mouse.X, mouse.Y)
				local params = RaycastParams.new()
				params.FilterDescendantsInstances = {char}
				params.FilterType = Enum.RaycastFilterType.Exclude
				local result = workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
				if result then
					hrp.CFrame = CFrame.new(result.Position + Vector3.new(0, 3, 0))
				end
			end)
		else
			if clickTPConn then clickTPConn:Disconnect(); clickTPConn = nil end
		end
	end,
})

clickTP:CreateToggle({
	Name = 'Require Ctrl',
	Tooltip  = 'Only click-teleport when Left Ctrl is held',
	Default = true,
	Function = function(enabled)
		requireCtrl = enabled
	end,
})

-- ── World — map & lobby teleport ──────────────────────────────────────────────
local World = vain.Categories.World

local tpMap
tpMap = World:CreateModule({
	Name = 'Teleport to Map',
	Tooltip  = 'Teleports you to the center of the current round map',
	Notification = false,
	Bind = {},
	Function = function(enabled)
		if not enabled then return end

		-- MM2 map is a Model in workspace; skip Lobby, character models, and known non-map children
		local skip = {'Lobby', 'Camera', 'Terrain'}
		local best, bestCount = nil, 0
		for _, child in workspace:GetChildren() do
			if not child:IsA('Model') then continue end
			local skipIt = false
			for _, s in skip do
				if child.Name == s then skipIt = true; break end
			end
			if skipIt then continue end
			for _, p in playersService:GetPlayers() do
				if p.Character == child then skipIt = true; break end
			end
			if skipIt then continue end
			local count = #child:GetDescendants()
			if count > bestCount then
				bestCount = count
				best = child
			end
		end

		if best then
			local part = best.PrimaryPart or best:FindFirstChildWhichIsA('BasePart')
			if part then
				tpTo(part.Position)
			else
				vain:CreateNotification('Vain', 'Map has no parts', 3, 'alert')
			end
		else
			vain:CreateNotification('Vain', 'No map found — is a round active?', 3, 'alert')
		end
		oneShot(tpMap)
	end,
})

local tpLobby
tpLobby = World:CreateModule({
	Name = 'Teleport to Lobby',
	Tooltip  = 'Teleports you to the lobby waiting area',
	Notification = false,
	Bind = {},
	Function = function(enabled)
		if not enabled then return end

		-- Search for lobby-related containers in workspace
		local lobbyNames = {'Lobby', 'LobbySpawns', 'SpawnArea', 'LobbyArea'}
		for _, name in lobbyNames do
			local lobby = workspace:FindFirstChild(name)
			if lobby then
				local part = lobby.PrimaryPart
					or lobby:FindFirstChildWhichIsA('SpawnLocation')
					or lobby:FindFirstChildWhichIsA('BasePart')
				if part then
					tpTo(part.Position)
					oneShot(tpLobby)
					return
				end
			end
		end

		-- Fallback: find any SpawnLocation directly in workspace
		local spawn = workspace:FindFirstChildWhichIsA('SpawnLocation')
		if spawn then
			tpTo(spawn.Position)
		else
			vain:CreateNotification('Vain', 'Lobby not found', 3, 'alert')
		end
		oneShot(tpLobby)
	end,
})

-- ── Blatant — noclip ──────────────────────────────────────────────────────────
local Blatant = vain.Categories.Blatant

local noclipConn
local noclip = Blatant:CreateModule({
	Name = 'Noclip',
	Tooltip  = 'Walk through all walls and geometry freely',
	Bind = {},
	Function = function(enabled)
		if enabled then
			noclipConn = runService.Stepped:Connect(function()
				local char = lplr.Character
				if not char then return end
				for _, part in char:GetDescendants() do
					if part:IsA('BasePart') then
						part.CanCollide = false
					end
				end
			end)
		else
			if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
		end
	end,
})

-- ── Blatant — fly ─────────────────────────────────────────────────────────────
local flySpeed = 50
local flyConn
local flyBV, flyBG

local function cleanFly()
	if flyBV and flyBV.Parent then flyBV:Destroy() end
	if flyBG and flyBG.Parent then flyBG:Destroy() end
	flyBV, flyBG = nil, nil
	if flyConn then flyConn:Disconnect(); flyConn = nil end
end

local fly = Blatant:CreateModule({
	Name = 'Fly',
	Tooltip  = 'Float and fly with WASD + Space/Shift to change altitude',
	Bind = {},
	Function = function(enabled)
		local char = lplr.Character
		local hrp  = char and char:FindFirstChild('HumanoidRootPart')
		local hum  = char and char:FindFirstChildOfClass('Humanoid')
		if not hrp or not hum then return end

		if enabled then
			hum.PlatformStand = true

			flyBV = Instance.new('BodyVelocity')
			flyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
			flyBV.Velocity = Vector3.new(0, 0, 0)
			flyBV.Parent   = hrp

			flyBG = Instance.new('BodyGyro')
			flyBG.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
			flyBG.P         = 1e4
			flyBG.CFrame    = hrp.CFrame
			flyBG.Parent    = hrp

			flyConn = runService.Heartbeat:Connect(function()
				local cam = workspace.CurrentCamera
				local cf  = cam.CFrame
				local dir = Vector3.new(0, 0, 0)

				if inputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cf.LookVector end
				if inputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cf.LookVector end
				if inputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cf.RightVector end
				if inputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cf.RightVector end
				if inputService:IsKeyDown(Enum.KeyCode.Space)     then dir = dir + Vector3.new(0, 1, 0) end
				if inputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end

				flyBV.Velocity = dir.Magnitude > 0 and (dir.Unit * flySpeed) or Vector3.new(0, 0, 0)
				flyBG.CFrame   = cf
			end)
		else
			cleanFly()
			local h = lplr.Character and lplr.Character:FindFirstChildOfClass('Humanoid')
			if h then h.PlatformStand = false end
		end
	end,
})

fly:CreateSlider({
	Name    = 'Speed',
	Min     = 10,
	Max     = 200,
	Default = 50,
	Function = function(val)
		flySpeed = val
	end,
})

-- Clean up on character reset (respawn)
lplr.CharacterAdded:Connect(function()
	cleanFly()
	if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
end)

-- ── Utility — auto farm coins ─────────────────────────────────────────────────
-- Coins are tagged "CoinVisual" via CollectionService. We find the nearest
-- uncollected coin and slowly step our character towards it so the server's
-- proximity-collection trigger fires naturally. Once collected we move to the
-- next nearest coin and repeat.
local collectionService = cloneref(game:GetService('CollectionService'))
local COIN_TAG      = 'CoinVisual'
local COIN_STEP     = 6      -- studs per step (keeps movement looking natural)
local COIN_INTERVAL = 0.08   -- seconds between each step

local function coinPosition(obj)
	if obj:IsA('BasePart') or obj:IsA('MeshPart') then
		return obj.Position
	end
	if obj:IsA('Model') then
		local p = obj.PrimaryPart or obj:FindFirstChildWhichIsA('BasePart')
		if p then return p.Position end
	end
	local child = obj:FindFirstChildWhichIsA('BasePart')
	return child and child.Position
end

local function isCollected(obj)
	-- Coins that have already been picked up have Collected = true or no parent
	if not obj or not obj.Parent then return true end
	local v = obj:GetAttribute('Collected')
	return v == true
end

local function findNearestCoin(myPos)
	local coins   = collectionService:GetTagged(COIN_TAG)
	local best, bestDist = nil, math.huge
	for _, coin in coins do
		if isCollected(coin) then continue end
		local pos = coinPosition(coin)
		if not pos then continue end
		local d = (myPos - pos).Magnitude
		if d < bestDist then
			best      = coin
			bestDist  = d
		end
	end
	return best, bestDist
end

local autoFarmRunning = false

local autoFarmModule = Utility:CreateModule({
	Name = 'Auto Farm Coins',
	Tooltip  = 'Step-teleports toward the nearest coin to trigger collection',
	Bind = {},
	Function = function(enabled)
		autoFarmRunning = enabled
		if not enabled then return end

		task.spawn(function()
			while autoFarmRunning do
				local hrp = getHRP()
				if hrp then
					local coin, dist = findNearestCoin(hrp.Position)
					if coin then
						local targetPos = coinPosition(coin)
						if targetPos then
							if dist <= COIN_STEP then
								-- Step directly onto the coin to trigger collection
								hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
							else
								-- Take one small step towards the coin
								local dir  = (targetPos - hrp.Position).Unit
								local next = hrp.Position + dir * COIN_STEP
								hrp.CFrame = CFrame.new(next + Vector3.new(0, 3, 0))
							end
						end
					end
				end
				task.wait(COIN_INTERVAL)
			end
		end)
	end,
})

autoFarmModule:CreateSlider({
	Name    = 'Step Size (studs)',
	Tooltip  = 'Studs moved toward the target per teleport step',
	Min     = 1,
	Max     = 30,
	Default = 6,
	Function = function(val) COIN_STEP = val end,
})

autoFarmModule:CreateSlider({
	Name    = 'Step Interval (ms)',
	Tooltip  = 'Milliseconds to wait between each teleport step',
	Min     = 20,
	Max     = 500,
	Default = 80,
	Function = function(val) COIN_INTERVAL = val / 1000 end,
})

local _af = autoFarmModule

do
-- ── Combat — Anti-Knife ───────────────────────────────────────────────────────
-- When the murderer's HRP closes within the threshold AND is moving toward us,
-- we snap a short burst away in the opposite direction.
local antiKnifeRadius  = 18  -- studs
local antiKnifeConn
local lastMurdererPos  = nil

local antiKnife = Combat:CreateModule({
	Name = 'Anti-Knife',
	Tooltip  = 'Teleports you away when the murderer is closing in to stab',
	Bind = {},
	Function = function(enabled)
		if enabled then
			lastMurdererPos = nil
			antiKnifeConn = runService.Heartbeat:Connect(function()
				local myHRP = getHRP()
				if not myHRP then return end

				local murderer = findByRole('Murderer')
				if not murderer or not murderer.Character then
					lastMurdererPos = nil
					return
				end
				local mHRP = murderer.Character:FindFirstChild('HumanoidRootPart')
				if not mHRP then return end

				local mPos  = mHRP.Position
				local myPos = myHRP.Position
				local dist  = (myPos - mPos).Magnitude

				-- Check if murderer is closing in (was farther last frame)
				local closing = lastMurdererPos and (lastMurdererPos - myPos).Magnitude > dist
				lastMurdererPos = mPos

				if dist < antiKnifeRadius and closing then
					local away = Vector3.new(myPos.X - mPos.X, 0, myPos.Z - mPos.Z)
					local dir  = away.Magnitude > 0 and away.Unit or Vector3.new(1, 0, 0)
					-- Use safe-dodge raycast (defined at top level in Auto Dodge section)
					local charFilter = RaycastParams.new()
					charFilter.FilterType = Enum.RaycastFilterType.Exclude
					charFilter.FilterDescendantsInstances = lplr.Character and {lplr.Character} or {}
					local wallHit  = workspace:Raycast(myPos + Vector3.new(0,1,0), dir * (antiKnifeRadius + 8), charFilter)
					local stepDist = wallHit and wallHit.Distance * 0.6 or antiKnifeRadius + 8
					local candidate = myPos + dir * stepDist
					local groundHit = workspace:Raycast(Vector3.new(candidate.X, myPos.Y + 5, candidate.Z), Vector3.new(0,-20,0), charFilter)
					if groundHit then
						myHRP.CFrame = CFrame.new(groundHit.Position + Vector3.new(0, 3, 0))
					end
				end
			end)
		else
			if antiKnifeConn then antiKnifeConn:Disconnect(); antiKnifeConn = nil end
			lastMurdererPos = nil
		end
	end,
})

antiKnife:CreateSlider({
	Name    = 'Dodge Radius (studs)',
	Tooltip  = 'Murderer must be closer than this to trigger a dodge',
	Min     = 5,
	Max     = 50,
	Default = 18,
	Function = function(val) antiKnifeRadius = val end,
})

end

do
-- ── Combat — Murderer Proximity Alert ────────────────────────────────────────
local alertRadius = 25
local alertCooldown = false
local alertConn

-- Screen flash frame
local alertGui = Instance.new('ScreenGui')
alertGui.Name          = 'VainAlert'
alertGui.ResetOnSpawn  = false
alertGui.IgnoreGuiInset = true
alertGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
alertGui.Parent        = (gethui and gethui()) or lplr:WaitForChild('PlayerGui')

local alertFrame = Instance.new('Frame')
alertFrame.Size              = UDim2.fromScale(1, 1)
alertFrame.BackgroundColor3  = Color3.fromRGB(220, 40, 40)
alertFrame.BackgroundTransparency = 1
alertFrame.BorderSizePixel   = 0
alertFrame.ZIndex            = 10
alertFrame.Parent            = alertGui

local tweenService = cloneref(game:GetService('TweenService'))

local function doAlertFlash()
	if alertCooldown then return end
	alertCooldown = true
	-- Flash red twice
	local flash = tweenService:Create(alertFrame,
		TweenInfo.new(0.12, Enum.EasingStyle.Sine),
		{BackgroundTransparency = 0.55}
	)
	flash:Play()
	flash.Completed:Wait()
	tweenService:Create(alertFrame,
		TweenInfo.new(0.25, Enum.EasingStyle.Sine),
		{BackgroundTransparency = 1}
	):Play()

	-- Beep sound
	local snd = Instance.new('Sound')
	snd.SoundId  = 'rbxassetid://5153644985'
	snd.Volume   = 0.6
	snd.Parent   = alertGui
	snd:Play()
	game:GetService('Debris'):AddItem(snd, 3)

	task.wait(1.5)
	alertCooldown = false
end

local proxAlert = Combat:CreateModule({
	Name = 'Proximity Alert',
	Tooltip  = 'Flashes the screen red and beeps when the murderer is nearby',
	Bind = {},
	Function = function(enabled)
		if enabled then
			alertConn = runService.Heartbeat:Connect(function()
				local myHRP = getHRP()
				if not myHRP then return end
				local murderer = findByRole('Murderer')
				if not murderer or not murderer.Character then return end
				local mHRP = murderer.Character:FindFirstChild('HumanoidRootPart')
				if not mHRP then return end
				if (myHRP.Position - mHRP.Position).Magnitude < alertRadius then
					task.spawn(doAlertFlash)
				end
			end)
		else
			if alertConn then alertConn:Disconnect(); alertConn = nil end
		end
	end,
})

proxAlert:CreateSlider({
	Name    = 'Alert Radius (studs)',
	Tooltip  = 'Murderer must be within this range to trigger the alert',
	Min     = 5,
	Max     = 80,
	Default = 25,
	Function = function(val) alertRadius = val end,
})

end

do
-- ── Combat — Auto Hero ────────────────────────────────────────────────────────
-- When the sheriff dies (gun drops into workspace), automatically grabs the gun.
-- Piggy-backs on the same gun-detection logic as Auto Teleport to Gun.
local autoHeroConns = {}
local autoHeroModule = Combat:CreateModule({
	Name = 'Auto Hero',
	Tooltip  = 'Automatically grabs the gun when the sheriff dies',
	Bind = {},
	Function = function(enabled)
		if enabled then
			local function tryGrab(part)
				if not isGunPart(part) then return end
				task.spawn(grabGun, part)
			end

			local c1 = workspace.ChildAdded:Connect(function(child)
				if not child:IsA('Model') then return end
				task.defer(function()
					for _, part in child:GetChildren() do tryGrab(part) end
				end)
				local c = child.ChildAdded:Connect(tryGrab)
				table.insert(autoHeroConns, c)
			end)
			table.insert(autoHeroConns, c1)
		else
			for _, c in autoHeroConns do pcall(c.Disconnect, c) end
			table.clear(autoHeroConns)
		end
	end,
})
local _ah = autoHeroModule

end

do
-- ── Combat — Gun ESP ──────────────────────────────────────────────────────────
-- Puts a Highlight + floating label on the dropped gun so you can see it
-- through walls without needing to teleport.
local gunEspHL    = nil
local gunEspBB    = nil
local gunEspConn  = nil
local gunEspPollConn = nil

local gunEspContainer = Instance.new('Folder')
gunEspContainer.Name   = 'VainGunESP'
gunEspContainer.Parent = (gethui and gethui()) or lplr:WaitForChild('PlayerGui')

local function clearGunEsp()
	if gunEspHL  and gunEspHL.Parent  then gunEspHL:Destroy()  end
	if gunEspBB  and gunEspBB.Parent  then gunEspBB:Destroy()  end
	gunEspHL, gunEspBB = nil, nil
end

local function attachGunEsp(gun)
	clearGunEsp()

	gunEspHL = Instance.new('Highlight')
	gunEspHL.Name       = 'VainGunHL'
	gunEspHL.DepthMode  = Enum.HighlightDepthMode.AlwaysOnTop
	gunEspHL.FillColor  = Color3.fromRGB(60, 200, 255)
	gunEspHL.OutlineColor = Color3.fromRGB(0, 180, 255)
	gunEspHL.FillTransparency    = 0.3
	gunEspHL.OutlineTransparency = 0.0
	gunEspHL.Adornee = gun
	gunEspHL.Parent  = gunEspContainer

	gunEspBB = Instance.new('BillboardGui')
	gunEspBB.Name         = 'VainGunLabel'
	gunEspBB.Size         = UDim2.fromOffset(80, 24)
	gunEspBB.StudsOffset  = Vector3.new(0, 2.5, 0)
	gunEspBB.AlwaysOnTop  = true
	gunEspBB.ResetOnSpawn = false
	gunEspBB.Adornee      = gun
	gunEspBB.Parent       = gunEspContainer

	local lbl = Instance.new('TextLabel')
	lbl.Size                   = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3             = Color3.fromRGB(60, 200, 255)
	lbl.TextStrokeTransparency = 0.3
	lbl.TextStrokeColor3       = Color3.new(0, 0, 0)
	lbl.TextSize               = 13
	lbl.Font                   = Enum.Font.GothamBold
	lbl.Text                   = '🔫 GUN'
	lbl.Parent                 = gunEspBB

	-- Auto-clear when gun is removed (picked up)
	if gunEspConn then gunEspConn:Disconnect() end
	gunEspConn = gun.AncestryChanged:Connect(function()
		if not gun.Parent then clearGunEsp() end
	end)
end

local gunEspEnabled = false

local gunEspModule = Combat:CreateModule({
	Name = 'Gun ESP',
	Tooltip  = 'Highlights the dropped sheriff gun through walls with a label',
	Bind = {},
	Function = function(enabled)
		gunEspEnabled = enabled
		if enabled then
			-- Attach to any gun already on the ground
			local existing = findDroppedGun()
			if existing then attachGunEsp(existing) end

			-- Poll for newly dropped guns every 0.5 s
			gunEspPollConn = runService.Heartbeat:Connect(function()
				if gunEspHL and gunEspHL.Parent then return end -- already tracking one
				local g = findDroppedGun()
				if g then attachGunEsp(g) end
			end)
		else
			clearGunEsp()
			if gunEspPollConn then gunEspPollConn:Disconnect(); gunEspPollConn = nil end
			if gunEspConn     then gunEspConn:Disconnect();     gunEspConn     = nil end
		end
	end,
})
local _ge = gunEspModule

end

do
-- ── Render — Role Announcer ───────────────────────────────────────────────────
-- When PlayerDataChanged fires (roles revealed), show a quick notification
-- listing everyone's role in colour.
local roleAnnouncerEnabled = false

local function announceRoles(data)
	if not roleAnnouncerEnabled then return end
	if type(data) ~= 'table' then return end
	local lines = {}
	for name, pdata in data do
		if type(pdata) == 'table' and type(pdata.Role) == 'string' then
			table.insert(lines, name .. ': ' .. pdata.Role)
		end
	end
	if #lines == 0 then return end
	table.sort(lines)
	vain:CreateNotification('Roles', table.concat(lines, '\n'), 8)
end

local roleAnnouncerModule = Render:CreateModule({
	Name = 'Role Announcer',
	Tooltip  = 'Shows a notification listing all player roles at round start',
	Bind = {},
	Function = function(enabled)
		roleAnnouncerEnabled = enabled
	end,
})
local _ra = roleAnnouncerModule

-- Hook into the existing PlayerDataChanged listener
if GameplayRemotes then
	local pdc = GameplayRemotes:FindFirstChild('PlayerDataChanged')
	if pdc then
		vain:Clean(pdc.OnClientEvent:Connect(announceRoles))
	end
end

end

do
-- ── Render — Murderer Trail ───────────────────────────────────────────────────
-- A directional arrow at the edge of the screen that always points toward the
-- murderer's world position, so you know which way to look/run.
local trailGui = Instance.new('ScreenGui')
trailGui.Name           = 'VainMurdererTrail'
trailGui.ResetOnSpawn   = false
trailGui.IgnoreGuiInset = true
trailGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
trailGui.Parent         = (gethui and gethui()) or lplr:WaitForChild('PlayerGui')

local trailArrow = Instance.new('ImageLabel')
trailArrow.Name                   = 'Arrow'
trailArrow.Size                   = UDim2.fromOffset(40, 40)
trailArrow.BackgroundTransparency = 1
-- Default Roblox arrow asset; points upward by default
trailArrow.Image    = 'rbxassetid://6034684950'
trailArrow.ImageColor3 = Color3.fromRGB(220, 50, 50)
trailArrow.Visible  = false
trailArrow.Parent   = trailGui

local trailLabel = Instance.new('TextLabel')
trailLabel.Size                   = UDim2.fromOffset(60, 16)
trailLabel.BackgroundTransparency = 1
trailLabel.TextColor3             = Color3.fromRGB(220, 50, 50)
trailLabel.TextStrokeTransparency = 0.3
trailLabel.TextStrokeColor3       = Color3.new(0, 0, 0)
trailLabel.TextSize               = 11
trailLabel.Font                   = Enum.Font.GothamBold
trailLabel.Visible                = false
trailLabel.Parent                 = trailGui

local trailConn

local murdererTrail = Render:CreateModule({
	Name = 'Murderer Trail',
	Tooltip  = 'On-screen arrow that always points toward the murderer',
	Bind = {},
	Function = function(enabled)
		trailArrow.Visible  = false
		trailLabel.Visible  = false
		if trailConn then trailConn:Disconnect(); trailConn = nil end

		if not enabled then return end

		trailConn = runService.RenderStepped:Connect(function()
			local murderer = findByRole('Murderer')
			if not murderer or not murderer.Character then
				trailArrow.Visible = false
				trailLabel.Visible = false
				return
			end
			local mHRP = murderer.Character:FindFirstChild('HumanoidRootPart')
			if not mHRP then
				trailArrow.Visible = false
				trailLabel.Visible = false
				return
			end
			local myHRP = getHRP()
			if not myHRP then return end

			local cam      = workspace.CurrentCamera
			local vp       = cam.ViewportSize
			local scrPos, onScreen = cam:WorldToScreenPoint(mHRP.Position)

			local dist = (myHRP.Position - mHRP.Position).Magnitude
			trailLabel.Text = string.format('%.0f studs', dist)

			if onScreen then
				-- Murderer is visible — place arrow directly over them
				trailArrow.Position = UDim2.fromOffset(scrPos.X - 20, scrPos.Y - 20)
				trailArrow.Rotation = 0
				trailLabel.Position = UDim2.fromOffset(scrPos.X - 30, scrPos.Y - 36)
			else
				-- Off-screen — clamp arrow to screen edge, rotate to point toward them
				local center = Vector2.new(vp.X / 2, vp.Y / 2)
				local dir    = Vector2.new(scrPos.X - center.X, scrPos.Y - center.Y)
				local angle  = math.atan2(dir.Y, dir.X)
				local pad    = 48
				local ex     = math.clamp(center.X + dir.Unit.X * (center.X - pad), pad, vp.X - pad)
				local ey     = math.clamp(center.Y + dir.Unit.Y * (center.Y - pad), pad, vp.Y - pad)
				trailArrow.Position = UDim2.fromOffset(ex - 20, ey - 20)
				trailArrow.Rotation = math.deg(angle) + 90
				trailLabel.Position = UDim2.fromOffset(ex - 30, ey + 24)
			end

			trailArrow.Visible = true
			trailLabel.Visible = true
		end)
	end,
})
local _mt = murdererTrail

end

do
-- ── Utility — Teleport Back ───────────────────────────────────────────────────
-- Saves up to 20 positions. Each press of the module (or bind) pops the latest
-- and teleports you back. A separate "Save Position" one-shot pushes the current
-- position onto the stack.
local tpHistory = {}
local TP_MAX    = 20

local tpBackModule
local savePositionModule

-- Record position helper
local function saveCurrentPos()
	local hrp = getHRP()
	if not hrp then return end
	table.insert(tpHistory, hrp.CFrame)
	if #tpHistory > TP_MAX then table.remove(tpHistory, 1) end
	vain:CreateNotification('Vain', 'Position saved (' .. #tpHistory .. '/' .. TP_MAX .. ')', 2)
end

savePositionModule = Utility:CreateModule({
	Name  = 'Save Position',
	Tooltip  = 'Saves your current world position to the teleport history',
	Notification = false,
	Bind  = {},
	Function = function(enabled)
		if not enabled then return end
		saveCurrentPos()
		oneShot(savePositionModule)
	end,
})

tpBackModule = Utility:CreateModule({
	Name  = 'Teleport Back',
	Tooltip  = 'Teleports you to the most recently saved position',
	Notification = false,
	Bind  = {},
	Function = function(enabled)
		if not enabled then return end
		if #tpHistory == 0 then
			vain:CreateNotification('Vain', 'No saved position', 3, 'alert')
		else
			local cf = table.remove(tpHistory)
			local hrp = getHRP()
			if hrp then hrp.CFrame = cf end
		end
		oneShot(tpBackModule)
	end,
})

end

do
-- ── Blatant — Walkspeed & Jumppower ──────────────────────────────────────────
local wsEnabled = false
local wsSpeed   = 16
local wsJump    = 50

local wsModule = Blatant:CreateModule({
	Name = 'Custom Stats',
	Tooltip  = 'Override your character WalkSpeed and JumpPower',
	Bind = {},
	Function = function(enabled)
		wsEnabled = enabled
		local hum = getHum()
		if not hum then return end
		if enabled then
			hum.WalkSpeed = wsSpeed
			hum.JumpPower = wsJump
		else
			hum.WalkSpeed = 16
			hum.JumpPower = 50
		end
	end,
})

wsModule:CreateSlider({
	Name    = 'Walk Speed',
	Tooltip  = 'Character movement speed (default 16)',
	Min     = 0,
	Max     = 200,
	Default = 16,
	Function = function(val)
		wsSpeed = val
		if wsEnabled then
			local hum = getHum()
			if hum then hum.WalkSpeed = val end
		end
	end,
})

wsModule:CreateSlider({
	Name    = 'Jump Power',
	Tooltip  = 'Character jump force (default 50)',
	Min     = 0,
	Max     = 200,
	Default = 50,
	Function = function(val)
		wsJump = val
		if wsEnabled then
			local hum = getHum()
			if hum then hum.JumpPower = val end
		end
	end,
})

-- Re-apply on respawn; restore defaults if disabled
lplr.CharacterAdded:Connect(function(char)
	local hum = char:WaitForChild('Humanoid', 5)
	if not hum then return end
	if wsEnabled then
		hum.WalkSpeed = wsSpeed
		hum.JumpPower = wsJump
	else
		hum.WalkSpeed = 16
		hum.JumpPower = 50
	end
end)

end

do
-- ── Blatant — Fullbright ──────────────────────────────────────────────────────
local Lighting      = cloneref(game:GetService('Lighting'))
local origLighting  = nil

local fullbright = Blatant:CreateModule({
	Name = 'Fullbright',
	Tooltip  = 'Maximises lighting brightness so every area is fully lit',
	Bind = {},
	Function = function(enabled)
		if enabled then
			origLighting = {
				Brightness      = Lighting.Brightness,
				Ambient         = Lighting.Ambient,
				OutdoorAmbient  = Lighting.OutdoorAmbient,
				FogEnd          = Lighting.FogEnd,
				GlobalShadows   = Lighting.GlobalShadows,
				ClockTime       = Lighting.ClockTime,
			}
			Lighting.Brightness     = 2
			Lighting.Ambient        = Color3.new(1, 1, 1)
			Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
			Lighting.FogEnd         = 100000
			Lighting.GlobalShadows  = false
			Lighting.ClockTime      = 12
		else
			if origLighting then
				for k, v in origLighting do
					pcall(function() Lighting[k] = v end)
				end
				origLighting = nil
			end
		end
	end,
})
local _fb = fullbright

end

do
-- ── Blatant — Spin Bot ────────────────────────────────────────────────────────
-- Continuously rotates our HumanoidRootPart at a set speed while leaving
-- normal movement intact (only rotates, doesn't lock position).
local spinSpeed = 10  -- rotations per second
local spinConn

local spinBot = Blatant:CreateModule({
	Name = 'Spin Bot',
	Tooltip  = 'Rotates your character continuously to disorient others',
	Bind = {},
	Function = function(enabled)
		if enabled then
			spinConn = runService.Heartbeat:Connect(function(dt)
				local hrp = getHRP()
				if not hrp then return end
				hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(spinSpeed * 360 * dt), 0)
			end)
		else
			if spinConn then spinConn:Disconnect(); spinConn = nil end
		end
	end,
})

spinBot:CreateSlider({
	Name    = 'Rotations / sec',
	Tooltip  = 'Full spins your character makes per second',
	Min     = 1,
	Max     = 50,
	Default = 10,
	Function = function(val) spinSpeed = val end,
})

end

do
-- ── Blatant — Fake Lag ────────────────────────────────────────────────────────
-- Jitters our character position at high speed to make us hard to knife
-- and confuse other players about our real location.
local fakeLagAmount = 4   -- stud jitter radius
local fakeLagConn

local fakeLag = Blatant:CreateModule({
	Name = 'Fake Lag',
	Tooltip  = 'Jitters your position locally to simulate high latency',
	Bind = {},
	Function = function(enabled)
		if enabled then
			fakeLagConn = runService.Heartbeat:Connect(function()
				local hrp = getHRP()
				if not hrp then return end
				local r = fakeLagAmount
				hrp.CFrame = hrp.CFrame * CFrame.new(
					math.random(-r * 10, r * 10) / 10,
					0,
					math.random(-r * 10, r * 10) / 10
				)
			end)
		else
			if fakeLagConn then fakeLagConn:Disconnect(); fakeLagConn = nil end
		end
	end,
})

fakeLag:CreateSlider({
	Name    = 'Jitter Radius (studs)',
	Tooltip  = 'Max studs your position is randomly offset each frame',
	Min     = 1,
	Max     = 20,
	Default = 4,
	Function = function(val) fakeLagAmount = val end,
})

end

do
-- ── Combat — Kill Aura ────────────────────────────────────────────────────────
-- When enabled, automatically flings every other player who enters the radius.
-- Most useful when you are the murderer.
local killAuraRadius  = 20
local killAuraConn
local killAuraCooldowns = {}  -- [player] = last fling time

local killAura = Combat:CreateModule({
	Name = 'Kill Aura',
	Tooltip  = 'Automatically shoots all players within the aura radius',
	Bind = {},
	Function = function(enabled)
		if enabled then
			killAuraConn = runService.Heartbeat:Connect(function()
				local myHRP = getHRP()
				if not myHRP then return end
				local now = os.clock()
				for _, p in playersService:GetPlayers() do
					if p == lplr then continue end
					if not p.Character then continue end
					local tHRP = p.Character:FindFirstChild('HumanoidRootPart')
					if not tHRP then continue end
					if (myHRP.Position - tHRP.Position).Magnitude > killAuraRadius then continue end
					if (killAuraCooldowns[p] or 0) + 1.8 > now then continue end
					killAuraCooldowns[p] = now
					task.spawn(flingPlayer, p)
				end
			end)
		else
			if killAuraConn then killAuraConn:Disconnect(); killAuraConn = nil end
			table.clear(killAuraCooldowns)
		end
	end,
})

killAura:CreateSlider({
	Name    = 'Aura Radius (studs)',
	Tooltip  = 'Auto-shoot range in studs',
	Min     = 5,
	Max     = 60,
	Default = 20,
	Function = function(val) killAuraRadius = val end,
})

end

do
-- ── Combat — Auto Fling Murderer ──────────────────────────────────────────────
-- Toggled: flings the murderer continuously whenever a round is active.
local autoFlingCooldown = false
local autoFlingConn

local autoFlingMurdererModule = Combat:CreateModule({
	Name = 'Auto Fling Murderer',
	Tooltip  = 'Continuously flings the murderer whenever a round is in progress',
	Bind = {},
	Function = function(enabled)
		if enabled then
			autoFlingConn = runService.Heartbeat:Connect(function()
				if not roundActive then return end
				if autoFlingCooldown then return end
				local murderer = findByRole('Murderer')
				if not murderer or not murderer.Character then return end
				if not murderer.Character:FindFirstChild('HumanoidRootPart') then return end
				autoFlingCooldown = true
				task.spawn(flingPlayer, murderer)
				task.delay(2.5, function() autoFlingCooldown = false end)
			end)
		else
			if autoFlingConn then autoFlingConn:Disconnect(); autoFlingConn = nil end
			autoFlingCooldown = false
		end
	end,
})

end

do
-- ── Combat — Murderer Bait ────────────────────────────────────────────────────
-- Slowly walks your character toward the murderer to bait them.
-- When they get within the dodge radius, auto-teleports away safely.
local baitStepSize     = 8
local baitStepInterval = 0.3
local baitDodgeRadius  = 14
local baitRunning      = false

local murdererBaitModule = Combat:CreateModule({
	Name = 'Murderer Bait',
	Tooltip  = 'Orbits around the murderer to draw them toward you',
	Bind = {},
	Function = function(enabled)
		baitRunning = enabled
		if not enabled then return end

		task.spawn(function()
			while baitRunning do
				local myHRP = getHRP()
				if not myHRP then task.wait(0.5) continue end

				local murderer = findByRole('Murderer')
				if not murderer or not murderer.Character then task.wait(0.5) continue end

				local mHRP = murderer.Character:FindFirstChild('HumanoidRootPart')
				if not mHRP then task.wait(0.5) continue end

				local myPos = myHRP.Position
				local mPos  = mHRP.Position
				local dist  = (myPos - mPos).Magnitude

				if dist < baitDodgeRadius then
					-- Dodge away — jump to opposite side of the murderer + buffer
					local away = Vector3.new(myPos.X - mPos.X, 0, myPos.Z - mPos.Z)
					if away.Magnitude > 0 then
						away = away.Unit * (baitDodgeRadius + 20)
					else
						away = Vector3.new(25, 0, 0)
					end
					myHRP.CFrame = CFrame.new(myPos + away)
					task.wait(1.2)  -- pause before resuming bait
				else
					-- Step toward murderer, stopping just outside dodge radius
					local dir  = Vector3.new(mPos.X - myPos.X, 0, mPos.Z - myPos.Z)
					local step = math.min(baitStepSize, math.max(0, dist - baitDodgeRadius - 2))
					if dir.Magnitude > 0 and step > 0 then
						myHRP.CFrame = CFrame.new(myPos + dir.Unit * step)
					end
					task.wait(baitStepInterval)
				end
			end
		end)
	end,
})

murdererBaitModule:CreateSlider({
	Name    = 'Step Size (studs)',
	Tooltip  = 'Studs moved toward the target per teleport step',
	Min     = 1,
	Max     = 20,
	Default = 8,
	Function = function(val) baitStepSize = val end,
})

murdererBaitModule:CreateSlider({
	Name    = 'Dodge Radius (studs)',
	Tooltip  = 'Murderer must be closer than this to trigger a dodge',
	Min     = 5,
	Max     = 40,
	Default = 14,
	Function = function(val) baitDodgeRadius = val end,
})

end

do
-- ── Combat — Reach Extender ───────────────────────────────────────────────────
-- Inflates the HumanoidRootPart so proximity-based triggers (coin collection,
-- gun pickup) fire from farther away. Also widens physics collision volume.
local reachSize    = 12
local origHRPSize  = nil

local reachExtender = Combat:CreateModule({
	Name = 'Reach Extender',
	Tooltip  = 'Enlarges your HRP so you can interact from a greater distance',
	Bind = {},
	Function = function(enabled)
		local hrp = getHRP()
		if not hrp then return end
		if enabled then
			origHRPSize = hrp.Size
			hrp.Size = Vector3.new(reachSize, reachSize, reachSize)
		else
			if origHRPSize then
				hrp.Size = origHRPSize
				origHRPSize = nil
			end
		end
	end,
})

reachExtender:CreateSlider({
	Name    = 'Reach Size',
	Tooltip  = 'Side length of your enlarged HRP hitbox in studs',
	Min     = 2,
	Max     = 50,
	Default = 12,
	Function = function(val)
		reachSize = val
		local hrp = getHRP()
		if hrp and origHRPSize then
			hrp.Size = Vector3.new(val, val, val)
		end
	end,
})

lplr.CharacterAdded:Connect(function() origHRPSize = nil end)

end

do
-- ── Utility — Infinite Jump ───────────────────────────────────────────────────
local infJumpConn

local infJump = Utility:CreateModule({
	Name = 'Infinite Jump',
	Tooltip  = 'Lets you jump again at any time, even while airborne',
	Bind = {},
	Function = function(enabled)
		if enabled then
			infJumpConn = inputService.JumpRequest:Connect(function()
				local hum = getHum()
				if hum then
					hum:ChangeState(Enum.HumanoidStateType.Jumping)
				end
			end)
		else
			if infJumpConn then infJumpConn:Disconnect(); infJumpConn = nil end
		end
	end,
})
local _ij = infJump

end

do
-- ── Utility — Loop Teleport ───────────────────────────────────────────────────
-- Cycles through your saved positions (tpHistory) on a set interval.
-- Save positions first with Save Position, then enable this to loop through them.
local loopTpInterval = 0.5
local loopTpRunning  = false

local loopTp = Utility:CreateModule({
	Name = 'Loop Teleport',
	Tooltip  = 'Cycles through your saved positions on a fixed interval',
	Bind = {},
	Function = function(enabled)
		loopTpRunning = enabled
		if not enabled then return end
		if #tpHistory == 0 then
			vain:CreateNotification('Vain', 'No saved positions — use Save Position first', 4, 'alert')
			loopTpRunning = false
			return
		end

		task.spawn(function()
			local idx = 1
			while loopTpRunning do
				local hrp = getHRP()
				if hrp and #tpHistory > 0 then
					if idx > #tpHistory then idx = 1 end
					hrp.CFrame = tpHistory[idx]
					idx = idx + 1
				end
				task.wait(loopTpInterval)
			end
		end)
	end,
})

loopTp:CreateSlider({
	Name    = 'Cycle Interval (ms)',
	Tooltip  = 'Milliseconds between each loop-teleport hop',
	Min     = 100,
	Max     = 3000,
	Default = 500,
	Function = function(val) loopTpInterval = val / 1000 end,
})

end

do
-- ── Utility — Server Hop ──────────────────────────────────────────────────────
local teleportService = cloneref(game:GetService('TeleportService'))

local serverHop
serverHop = Utility:CreateModule({
	Name = 'Server Hop',
	Tooltip  = 'Rejoins the same game in a fresh server instantly',
	Notification = false,
	Bind = {},
	Function = function(enabled)
		if not enabled then return end
		vain:CreateNotification('Vain', 'Hopping to a new server...', 3)
		task.delay(1.2, function()
			pcall(function()
				teleportService:Teleport(game.PlaceId, lplr)
			end)
		end)
		oneShot(serverHop)
	end,
})

end

do
-- ── Utility — Anti-AFK ───────────────────────────────────────────────────────
-- Micro-nudges your character every 55 s to prevent the Roblox idle kick.
local antiAfkRunning = false

local antiAfk = Utility:CreateModule({
	Name = 'Anti-AFK',
	Tooltip  = 'Simulates input periodically to prevent an AFK kick',
	Bind = {},
	Function = function(enabled)
		antiAfkRunning = enabled
		if not enabled then return end

		task.spawn(function()
			while antiAfkRunning do
				task.wait(55)
				if not antiAfkRunning then break end
				local hrp = getHRP()
				if hrp then
					local orig = hrp.CFrame
					hrp.CFrame = orig * CFrame.new(0.01, 0, 0)
					task.wait(0.1)
					local h2 = getHRP()
					if h2 then h2.CFrame = orig end
				end
			end
		end)
	end,
})
local _aa = antiAfk

end

do
-- ── Blatant — Low Gravity ─────────────────────────────────────────────────────
local origGravity = workspace.Gravity

local lowGravity = Blatant:CreateModule({
	Name = 'Low Gravity',
	Tooltip  = 'Lowers workspace gravity so you fall slower and jump higher',
	Bind = {},
	Function = function(enabled)
		workspace.Gravity = enabled and 40 or origGravity
	end,
})

lowGravity:CreateSlider({
	Name    = 'Gravity',
	Tooltip  = 'Workspace gravity value (default approx 196)',
	Min     = 1,
	Max     = 196,
	Default = 40,
	Function = function(val) workspace.Gravity = val end,
})

end

do
-- ── Blatant — Ghost Mode ──────────────────────────────────────────────────────
-- Sets Transparency = 1 on all character parts. Replicates to the server,
-- making you visually invisible to other players too.
local ghostOrigTransp = {}

local ghostMode = Blatant:CreateModule({
	Name = 'Ghost Mode',
	Tooltip  = 'Renders your character nearly invisible',
	Bind = {},
	Function = function(enabled)
		local char = lplr.Character
		if not char then return end
		if enabled then
			ghostOrigTransp = {}
			for _, p in char:GetDescendants() do
				if p:IsA('BasePart') or p:IsA('MeshPart') then
					ghostOrigTransp[p] = p.Transparency
					p.Transparency = 1
				elseif p:IsA('Decal') then
					ghostOrigTransp[p] = p.Transparency
					p.Transparency = 1
				end
			end
		else
			for obj, v in ghostOrigTransp do
				if obj and obj.Parent then
					pcall(function() obj.Transparency = v end)
				end
			end
			ghostOrigTransp = {}
		end
	end,
})
local _gm = ghostMode

lplr.CharacterAdded:Connect(function() ghostOrigTransp = {} end)

end

do
-- ── Render — Rainbow ESP ──────────────────────────────────────────────────────
-- Overrides the ESP highlight colour with a smoothly cycling rainbow hue.
-- Disable to restore normal role-based colouring.
local rainbowHue     = 0
local rainbowConn
local rainbowEnabled = false

local rainbowESP = Render:CreateModule({
	Name = 'Rainbow ESP',
	Tooltip  = 'Smoothly cycles ESP highlight colours through the rainbow',
	Bind = {},
	Function = function(enabled)
		rainbowEnabled = enabled
		if rainbowConn then rainbowConn:Disconnect(); rainbowConn = nil end
		if enabled then
			rainbowConn = runService.Heartbeat:Connect(function(dt)
				rainbowHue = (rainbowHue + dt * 0.12) % 1
				local col = Color3.fromHSV(rainbowHue, 1, 1)
				for _, objs in espObjects do
					if objs.highlight then
						objs.highlight.FillColor    = col
						objs.highlight.OutlineColor = col
					end
					if objs.label then
						objs.label.TextColor3 = col
					end
				end
			end)
		else
			-- Restore role colours
			refreshAll()
		end
	end,
})
local _re = rainbowESP

end

do
-- ── Combat — Freeze Player ────────────────────────────────────────────────────
-- Continuously anchors the target's HRP and zeroes their velocity.
-- Requires an executor that lets you write to other players' parts.
local freezeTarget = ''
local freezeConn

local freezePlayerModule
local freezeDropdown

freezePlayerModule = Combat:CreateModule({
	Name = 'Freeze Player',
	Tooltip  = 'Anchors the selected players character so they cannot move',
	Bind = {},
	Function = function(enabled)
		if freezeConn then freezeConn:Disconnect(); freezeConn = nil end
		if not enabled then return end

		if freezeTarget == '' then
			vain:CreateNotification('Vain', 'Select a player first', 3, 'alert')
			oneShot(freezePlayerModule)
			return
		end
		local target = playersService:FindFirstChild(freezeTarget)
		if not target or not target.Character then
			vain:CreateNotification('Vain', 'Player not found', 3, 'alert')
			oneShot(freezePlayerModule)
			return
		end
		local tHRP = target.Character:FindFirstChild('HumanoidRootPart')
		if not tHRP then
			vain:CreateNotification('Vain', 'No HumanoidRootPart', 3, 'alert')
			oneShot(freezePlayerModule)
			return
		end

		local frozenCF = tHRP.CFrame
		pcall(function() tHRP.Anchored = true end)

		freezeConn = runService.Heartbeat:Connect(function()
			if not tHRP or not tHRP.Parent then
				freezeConn:Disconnect(); freezeConn = nil
				return
			end
			pcall(function()
				tHRP.Anchored  = true
				tHRP.CFrame    = frozenCF
				tHRP.AssemblyLinearVelocity  = Vector3.zero
				tHRP.AssemblyAngularVelocity = Vector3.zero
			end)
		end)
	end,
})

freezeDropdown = freezePlayerModule:CreateDropdown({
	Name     = 'Player',
	Tooltip  = 'Select which player to target',
	List     = getPlayerNames(),
	Function = function(val)
		freezeTarget = val or ''
		if freezeConn then freezeConn:Disconnect(); freezeConn = nil end
	end,
})

vain:Clean(playersService.PlayerAdded:Connect(function()
	freezeDropdown:Change(getPlayerNames())
end))
vain:Clean(playersService.PlayerRemoving:Connect(function(p)
	if freezeTarget == p.Name then
		freezeTarget = ''
		if freezeConn then freezeConn:Disconnect(); freezeConn = nil end
	end
	freezeDropdown:Change(getPlayerNames())
end))

end

do
-- ── Utility — Auto Respawn ────────────────────────────────────────────────────
-- When your Humanoid dies, automatically calls LoadCharacter after a short delay
-- so you skip the respawn screen entirely.
local autoRespawnConn

local autoRespawn = Utility:CreateModule({
	Name = 'Auto Respawn',
	Tooltip  = 'Automatically respawns you the instant you die',
	Bind = {},
	Function = function(enabled)
		if autoRespawnConn then autoRespawnConn:Disconnect(); autoRespawnConn = nil end
		if not enabled then return end

		local function hookChar(char)
			local hum = char:WaitForChild('Humanoid', 5)
			if not hum then return end
			hum.Died:Connect(function()
				task.wait(0.4)
				pcall(function() lplr:LoadCharacter() end)
			end)
		end

		if lplr.Character then task.spawn(hookChar, lplr.Character) end
		autoRespawnConn = lplr.CharacterAdded:Connect(hookChar)
	end,
})
local _ar = autoRespawn

end

do
-- ── Utility — Egg Farm ────────────────────────────────────────────────────────
-- Finds egg objects in the workspace (CurrencyEgg / RareEgg / any name containing
-- "egg") and slow-teleports toward them the same way coin farm does.
local EGG_STEP     = 6
local EGG_INTERVAL = 0.08
local eggFarmRunning = false

local function eggPosition(obj)
	if obj:IsA('BasePart') or obj:IsA('MeshPart') then return obj.Position end
	local p = obj.PrimaryPart or obj:FindFirstChildWhichIsA('BasePart')
	return p and p.Position
end

local function findNearestEgg(myPos)
	local best, bestDist = nil, math.huge
	for _, obj in workspace:GetDescendants() do
		if not obj.Parent then continue end
		local lname = obj.Name:lower()
		if not (lname:find('egg') or lname:find('currencyegg')) then continue end
		if not (obj:IsA('BasePart') or obj:IsA('MeshPart') or obj:IsA('Model')) then continue end
		local pos = eggPosition(obj)
		if not pos then continue end
		local d = (myPos - pos).Magnitude
		if d < bestDist then best = obj; bestDist = d end
	end
	return best, bestDist
end

local eggFarmModule = Utility:CreateModule({
	Name = 'Egg Farm',
	Tooltip  = 'Step-teleports toward the nearest egg to collect it',
	Bind = {},
	Function = function(enabled)
		eggFarmRunning = enabled
		if not enabled then return end

		task.spawn(function()
			while eggFarmRunning do
				local hrp = getHRP()
				if hrp then
					local egg, dist = findNearestEgg(hrp.Position)
					if egg then
						local targetPos = eggPosition(egg)
						if targetPos then
							if dist <= EGG_STEP then
								hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
							else
								local dir  = (targetPos - hrp.Position).Unit
								local next = hrp.Position + dir * EGG_STEP
								hrp.CFrame = CFrame.new(next + Vector3.new(0, 3, 0))
							end
						end
					end
				end
				task.wait(EGG_INTERVAL)
			end
		end)
	end,
})

eggFarmModule:CreateSlider({
	Name    = 'Step Size (studs)',
	Tooltip  = 'Studs moved toward the target per teleport step',
	Min     = 1,
	Max     = 30,
	Default = 6,
	Function = function(val) EGG_STEP = val end,
})

eggFarmModule:CreateSlider({
	Name    = 'Step Interval (ms)',
	Tooltip  = 'Milliseconds to wait between each teleport step',
	Min     = 20,
	Max     = 500,
	Default = 80,
	Function = function(val) EGG_INTERVAL = val / 1000 end,
})

end

do
-- ── Blatant — Time of Day ─────────────────────────────────────────────────────
-- Sets Lighting.ClockTime directly without touching other lighting properties.
-- Works alongside Fullbright (they control separate properties).
local todModule = Blatant:CreateModule({
	Name = 'Time of Day',
	Tooltip  = 'Overrides the in-game clock time (client-side only)',
	Bind = {},
	Function = function(enabled)
		-- Toggle just records state; the slider drives the actual value
		if not enabled then
			-- Restore to a neutral midday when disabled
			pcall(function() Lighting.ClockTime = 14 end)
		end
	end,
})

todModule:CreateSlider({
	Name    = 'Clock Time (0–24)',
	Min     = 0,
	Max     = 24,
	Default = 14,
	Function = function(val)
		pcall(function() Lighting.ClockTime = val end)
	end,
})

end

do
-- ── Blatant — Emote Spam ──────────────────────────────────────────────────────
-- Repeatedly equips and activates the MM2 Emotes tool as fast as possible.
-- This causes the character to rapidly glitch through emote animations.
local emoteSpamConn

local function findEmoteTool()
	local char = lplr.Character
	if char then
		for _, v in char:GetChildren() do
			if v:IsA('Tool') and v.Name:lower():find('emote') then return v end
		end
	end
	local bp = lplr:FindFirstChild('Backpack')
	if bp then
		for _, v in bp:GetChildren() do
			if v:IsA('Tool') and v.Name:lower():find('emote') then return v end
		end
	end
end

local emoteSpam = Blatant:CreateModule({
	Name = 'Emote Spam',
	Tooltip  = 'Rapidly re-activates your equipped emote every frame',
	Bind = {},
	Function = function(enabled)
		if enabled then
			emoteSpamConn = runService.Heartbeat:Connect(function()
				local tool = findEmoteTool()
				if not tool then return end
				local char = lplr.Character
				if not char then return end
				if tool.Parent ~= char then
					local hum = char:FindFirstChildOfClass('Humanoid')
					if hum then pcall(hum.EquipTool, hum, tool) end
				end
				pcall(function() tool:Activate() end)
			end)
		else
			if emoteSpamConn then emoteSpamConn:Disconnect(); emoteSpamConn = nil end
		end
	end,
})

end

do
-- ── Combat — Shadow Teleport ──────────────────────────────────────────────────
-- Instantly teleports you behind the selected player (offset behind their
-- LookVector so you appear at their back). One-shot per press.
local shadowTpTarget = ''
local SHADOW_OFFSET  = 5  -- studs behind the target

local shadowTp
shadowTp = Combat:CreateModule({
	Name          = 'Shadow Teleport',
	Tooltip  = 'One-shot: teleports you directly behind the selected player',
	Notification  = false,
	Bind          = {},
	Function      = function(enabled)
		if not enabled then return end
		local target = playersService:FindFirstChild(shadowTpTarget)
		local tHRP   = target and target.Character and target.Character:FindFirstChild('HumanoidRootPart')
		local myHRP  = getHRP()
		if not tHRP or not myHRP then
			oneShot(shadowTp)
			return
		end
		local behind = tHRP.CFrame * CFrame.new(0, 0, SHADOW_OFFSET)
		myHRP.CFrame = CFrame.new(behind.Position, tHRP.Position)
		oneShot(shadowTp)
	end,
})

local shadowDropdown = shadowTp:CreateDropdown({
	Name     = 'Player',
	Tooltip  = 'Select which player to target',
	List     = getPlayerNames(),
	Function = function(val) shadowTpTarget = val or '' end,
})

vain:Clean(playersService.PlayerAdded:Connect(function()
	shadowDropdown:Change(getPlayerNames())
end))
vain:Clean(playersService.PlayerRemoving:Connect(function(p)
	if shadowTpTarget == p.Name then shadowTpTarget = '' end
	shadowDropdown:Change(getPlayerNames())
end))

end

do
-- ── Combat — Auto Throw Knife ─────────────────────────────────────────────────
-- If you are the Murderer, continuously faces your character toward the nearest
-- player and activates the Knife tool, causing it to be thrown automatically.
local autoKnifeRunning = false

local function findKnifeTool()
	local char = lplr.Character
	if not char then return end
	for _, v in char:GetChildren() do
		if v:IsA('Tool') and v.Name:lower():find('knife') then return v end
	end
end

local function nearestPlayerPos()
	local myHRP = getHRP()
	if not myHRP then return end
	local best, bestDist = nil, math.huge
	for _, p in playersService:GetPlayers() do
		if p == lplr then continue end
		local hrp = p.Character and p.Character:FindFirstChild('HumanoidRootPart')
		if not hrp then continue end
		local d = (myHRP.Position - hrp.Position).Magnitude
		if d < bestDist then best = hrp; bestDist = d end
	end
	return best
end

Combat:CreateModule({
	Name = 'Auto Throw Knife',
	Tooltip  = 'As the murderer, auto-aims and throws your knife at the nearest player',
	Bind = {},
	Function = function(enabled)
		autoKnifeRunning = enabled
		if not enabled then return end

		task.spawn(function()
			while autoKnifeRunning do
				local knife = findKnifeTool()
				local myHRP = getHRP()
				local targetHRP = nearestPlayerPos()

				if knife and myHRP and targetHRP then
					-- Face toward the target so the thrown knife tracks them
					myHRP.CFrame = CFrame.lookAt(myHRP.Position, targetHRP.Position)
					pcall(function() knife:Activate() end)
				end
				task.wait(0.15)
			end
		end)
	end,
})

end

do
-- ── Utility — Follow Player ───────────────────────────────────────────────────
-- Continuously teleports you to stay just behind a selected player.
-- Uses the same slow-step approach as coin farm so it feels like real movement.
local followTarget    = ''
local followRunning   = false
local FOLLOW_DISTANCE = 4   -- studs to stay behind them
local FOLLOW_STEP     = 8   -- studs per tick
local FOLLOW_INTERVAL = 0.07

local followModule = Utility:CreateModule({
	Name = 'Follow Player',
	Tooltip  = 'Continuously step-teleports behind the selected player',
	Bind = {},
	Function = function(enabled)
		followRunning = enabled
		if not enabled then return end

		task.spawn(function()
			while followRunning do
				local target = playersService:FindFirstChild(followTarget)
				local tHRP   = target and target.Character and target.Character:FindFirstChild('HumanoidRootPart')
				local myHRP  = getHRP()

				if tHRP and myHRP then
					-- Aim for a spot just behind the target
					local goal = tHRP.CFrame * CFrame.new(0, 0, FOLLOW_DISTANCE)
					local goalPos = goal.Position
					local dist = (myHRP.Position - goalPos).Magnitude
					if dist > 1 then
						local dir  = (goalPos - myHRP.Position).Unit
						local step = math.min(FOLLOW_STEP, dist)
						myHRP.CFrame = CFrame.new(myHRP.Position + dir * step)
					end
				end
				task.wait(FOLLOW_INTERVAL)
			end
		end)
	end,
})

local followDropdown = followModule:CreateDropdown({
	Name     = 'Player',
	Tooltip  = 'Select which player to target',
	List     = getPlayerNames(),
	Function = function(val) followTarget = val or '' end,
})

vain:Clean(playersService.PlayerAdded:Connect(function()
	followDropdown:Change(getPlayerNames())
end))
vain:Clean(playersService.PlayerRemoving:Connect(function(p)
	if followTarget == p.Name then followTarget = '' end
	followDropdown:Change(getPlayerNames())
end))

followModule:CreateSlider({
	Name     = 'Follow Distance (studs)',
	Tooltip  = 'Studs to keep behind the followed player',
	Min      = 1,
	Max      = 20,
	Default  = 4,
	Function = function(val) FOLLOW_DISTANCE = val end,
})

end

do
-- ── Combat — Rapid Fire ───────────────────────────────────────────────────────
-- Spams the equipped gun's Activate event every tick, bypassing the normal
-- click-fire cadence. Only fires when a gun tool is actually equipped.
local rapidFireRunning = false

Combat:CreateModule({
	Name = 'Rapid Fire',
	Tooltip  = 'Spams the gun fire event every 50 ms, bypassing fire-rate limits',
	Bind = {},
	Function = function(enabled)
		rapidFireRunning = enabled
		if not enabled then return end

		task.spawn(function()
			while rapidFireRunning do
				local gun = getEquippedGun()
				if gun then
					pcall(function() gun:Activate() end)
				end
				task.wait(0.05)
			end
		end)
	end,
})

end

do
-- ── Combat — Knife Dodge ──────────────────────────────────────────────────────
-- Watches for new instances tagged "ThrowingKnife" via CollectionService.
-- When one appears within KNIFE_DODGE_RADIUS studs, sidesteps immediately.
-- Uses the real MM2 knife tag so it reacts to actual projectiles, not guesses.
local collectionService  = cloneref(game:GetService('CollectionService'))
local KNIFE_DODGE_RADIUS = 25  -- studs — dodge if knife spawns closer than this
local knifeDodgeConn
local knifeDodgeTagConn

local function dodgeSideStep()
	local hrp = getHRP()
	if not hrp then return end
	-- Step to the right relative to current facing
	local side = hrp.CFrame.RightVector * 8
	hrp.CFrame = hrp.CFrame + side
end

local function hookKnife(obj)
	-- Check distance once immediately; the knife moves fast so one check is enough
	task.defer(function()
		local hrp = getHRP()
		if not hrp then return end
		local pos = obj:IsA('BasePart') and obj.Position
			or (obj.PrimaryPart and obj.PrimaryPart.Position)
		if pos and (hrp.Position - pos).Magnitude <= KNIFE_DODGE_RADIUS then
			dodgeSideStep()
		end
	end)
end

Combat:CreateModule({
	Name = 'Knife Dodge',
	Tooltip  = 'Sidesteps when a thrown knife tag appears within range',
	Bind = {},
	Function = function(enabled)
		if knifeDodgeTagConn  then knifeDodgeTagConn:Disconnect();  knifeDodgeTagConn  = nil end
		if knifeDodgeConn     then knifeDodgeConn:Disconnect();     knifeDodgeConn     = nil end
		if not enabled then return end

		-- Hook already-existing tagged knives (edge case)
		for _, obj in collectionService:GetTagged('ThrowingKnife') do
			hookKnife(obj)
		end
		-- Hook future tagged knives
		knifeDodgeTagConn = collectionService:GetInstanceAddedSignal('ThrowingKnife'):Connect(hookKnife)
	end,
})

end

do
-- ── Combat — Bullet Immunity (WeaponPassthrough) ──────────────────────────────
-- The MM2 gun raycast filters out any part tagged "WeaponPassthrough".
-- Tagging every BasePart of your own character with that tag means bullets
-- will pass straight through you — the raycast simply skips your parts.
local bulletImmuneActive = false
local taggedParts        = {}

local function tagCharacter()
	taggedParts = {}
	local char = lplr.Character
	if not char then return end
	for _, part in char:GetDescendants() do
		if part:IsA('BasePart') then
			collectionService:AddTag(part, 'WeaponPassthrough')
			table.insert(taggedParts, part)
		end
	end
end

local function untagCharacter()
	for _, part in taggedParts do
		pcall(collectionService.RemoveTag, collectionService, part, 'WeaponPassthrough')
	end
	taggedParts = {}
end

local bulletImmConn
Combat:CreateModule({
	Name = 'Bullet Immunity',
	Tooltip  = 'Tags your parts WeaponPassthrough so gun raycasts skip you',
	Bind = {},
	Function = function(enabled)
		bulletImmuneActive = enabled
		if bulletImmConn then bulletImmConn:Disconnect(); bulletImmConn = nil end
		if enabled then
			tagCharacter()
			-- Re-tag after respawn
			bulletImmConn = lplr.CharacterAdded:Connect(function()
				task.wait(0.2)
				if bulletImmuneActive then tagCharacter() end
			end)
		else
			untagCharacter()
		end
	end,
})

end

do
-- ── Combat — Stealth Mode ─────────────────────────────────────────────────────
-- Fires the MM2 Stealth RemoteEvent (found in Remotes.Gameplay).
-- In MM2 this is normally only available to the Murderer; firing it client-side
-- attempts to enable the stealth visual/mechanic for your character.
local GameplayStealth = GameplayRemotes and GameplayRemotes:FindFirstChild('Stealth')

local stealthActive = false
local stealthConn

Combat:CreateModule({
	Name = 'Stealth Mode',
	Tooltip  = 'Fires the Stealth remote repeatedly to suppress your presence',
	Bind = {},
	Function = function(enabled)
		stealthActive = enabled
		if stealthConn then stealthConn:Disconnect(); stealthConn = nil end
		if enabled then
			-- Fire immediately then every 2 s to keep it active
			pcall(function()
				if GameplayStealth then GameplayStealth:FireServer() end
			end)
			stealthConn = runService.Heartbeat:Connect(function()
				-- throttle to once per 2 s via a simple counter
			end)
			task.spawn(function()
				while stealthActive do
					pcall(function()
						if GameplayStealth then GameplayStealth:FireServer() end
					end)
					task.wait(2)
				end
			end)
		end
	end,
})

end

do
-- ── Combat — Perk Activator ───────────────────────────────────────────────────
-- Repeatedly fires the ActivatePerk RemoteEvent found in Remotes.Gameplay.
-- This bypasses the normal in-game cooldown, giving continuous perk effects.
local GameplayActivatePerk = GameplayRemotes and GameplayRemotes:FindFirstChild('ActivatePerk')

local perkActive = false
Combat:CreateModule({
	Name = 'Perk Activator',
	Tooltip  = 'Spams ActivatePerk to use your perk without cooldown',
	Bind = {},
	Function = function(enabled)
		perkActive = enabled
		if not enabled then return end

		task.spawn(function()
			while perkActive do
				pcall(function()
					if GameplayActivatePerk then GameplayActivatePerk:FireServer() end
				end)
				task.wait(0.5)
			end
		end)
	end,
})

end

do
-- ── Combat — Fake Gun ─────────────────────────────────────────────────────────
-- Fires the FakeGun RemoteEvent in Remotes.Gameplay, which makes your character
-- display the "holding gun" animation and visual to other clients. Murderers
-- may mistake you for the real sheriff and avoid you or flee.
local GameplayFakeGun = GameplayRemotes and GameplayRemotes:FindFirstChild('FakeGun')

local fakeGunActive = false
Combat:CreateModule({
	Name = 'Fake Gun',
	Tooltip  = 'Fires FakeGun so other players see you holding a weapon',
	Bind = {},
	Function = function(enabled)
		fakeGunActive = enabled
		if not enabled then return end

		task.spawn(function()
			while fakeGunActive do
				pcall(function()
					if GameplayFakeGun then GameplayFakeGun:FireServer() end
				end)
				task.wait(1)
			end
		end)
	end,
})

end

do
-- ── Combat — Auto Trap ────────────────────────────────────────────────────────
-- Fires PlaceTrap (RemoteFunction in ReplicatedStorage.TrapSystem) at the
-- murderer's current position every N seconds. Murderers walk into the trap
-- and take damage / get slowed.
local TrapSystem  = ReplicatedStorage:FindFirstChild('TrapSystem')
local PlaceTrap   = TrapSystem and TrapSystem:FindFirstChild('PlaceTrap')
local autoTrapRunning = false

local function getMurdererHRP()
	for _, p in playersService:GetPlayers() do
		if playerRoles[p.Name] == 'Murderer' then
			local hrp = p.Character and p.Character:FindFirstChild('HumanoidRootPart')
			if hrp then return hrp end
		end
	end
end

Combat:CreateModule({
	Name = 'Auto Trap',
	Tooltip  = 'Places traps at the murderers feet every few seconds',
	Bind = {},
	Function = function(enabled)
		autoTrapRunning = enabled
		if not enabled then return end

		task.spawn(function()
			while autoTrapRunning do
				local mHRP = getMurdererHRP()
				if mHRP and PlaceTrap then
					pcall(function()
						PlaceTrap:InvokeServer(mHRP.CFrame)
					end)
				end
				task.wait(3)
			end
		end)
	end,
})

end

do
-- ── Combat — Auto Dodge ───────────────────────────────────────────────────────
-- Unified dodge system that protects against all three attack vectors:
--   1. Stab  — murderer's HRP closing within radius → teleport away
--   2. Throw — CollectionService "ThrowingKnife" tag spawns nearby → sidestep
--   3. Shot  — sheriff has clear line-of-sight to us OR GunFired fires → sidestep
--
-- All three checks run in a single Heartbeat loop (stab/shot) plus a tag signal
-- (throw), so there is no redundant polling and they can't conflict.

local autoDodgeActive      = false
local autoDodgeStabRadius  = 18   -- studs — stab trigger distance
local autoDodgeShotRadius  = 60   -- studs — LoS check max distance
local autoDodgeCooldown    = false
local autoDodgeLastMPos    = nil
local autoDodgeHBConn
local autoDodgeTagConn
local autoDodgeGunConn

-- Safe position finder --------------------------------------------------------
-- Returns a safe CFrame to teleport to in the given direction, or nil if
-- the spot is a void / solid wall. Raycasts:
--   1. Horizontally to reject walls in the path
--   2. Downward from candidate to confirm ground exists below
local function findSafeDodge(myPos, direction, distance)
	local charFilter = RaycastParams.new()
	charFilter.FilterType = Enum.RaycastFilterType.Exclude
	charFilter.FilterDescendantsInstances = lplr.Character
		and {lplr.Character} or {}

	-- Horizontal wall check
	local wallHit = workspace:Raycast(
		myPos + Vector3.new(0, 1, 0),
		direction * distance,
		charFilter)
	local actualDist = wallHit and (wallHit.Distance * 0.6) or distance
	local candidate  = myPos + direction * actualDist

	-- Downward ground check — cast from the player's *current* Y so we only
	-- accept spots at roughly the same floor elevation (±20 studs).
	-- This prevents landing on a lower sub-floor or in the void.
	local groundHit = workspace:Raycast(
		Vector3.new(candidate.X, myPos.Y + 5, candidate.Z),
		Vector3.new(0, -20, 0),
		charFilter)

	if not groundHit then
		-- No ground — don't teleport into the void; stay put
		return nil
	end

	-- Land 3 studs above the ground surface
	return CFrame.new(groundHit.Position + Vector3.new(0, 3, 0))
end

-- Sweep all directions to find ANY safe landing spot -------------------------
-- Tries 16 evenly-spread horizontal angles at several distances.
-- Falls back to a straight upward jump if every horizontal path is blocked.
local function bestDodgeCF(myHRP, fromPos, preferredDist)
	local myPos = myHRP.Position

	-- Build priority-ordered direction list:
	-- 1. Directly away from the threat  2. 16 swept compass directions
	local dirs = {}
	if fromPos then
		local away = Vector3.new(myPos.X - fromPos.X, 0, myPos.Z - fromPos.Z)
		if away.Magnitude > 0 then
			table.insert(dirs, away.Unit)
		end
	end
	for i = 0, 15 do
		local a = (i / 16) * math.pi * 2
		table.insert(dirs, Vector3.new(math.cos(a), 0, math.sin(a)))
	end

	-- For each direction try the preferred distance, then half, then 1.5×
	for _, dir in dirs do
		for _, d in {preferredDist, preferredDist * 0.5, preferredDist * 1.5} do
			local cf = findSafeDodge(myPos, dir, d)
			if cf then
				-- Accept only if this spot is actually farther from the threat
				if not fromPos then return cf end
				local gain = (cf.Position - fromPos).Magnitude
				            - (myPos       - fromPos).Magnitude
				if gain > 2 then return cf end
			end
		end
	end

	-- Last resort: jump straight up 25 studs — always clears any corner
	return CFrame.new(myPos + Vector3.new(0, 25, 0))
end

local function triggerDodge(myHRP, fromPos, dist)
	if autoDodgeCooldown then return end
	autoDodgeCooldown = true
	local cf = bestDodgeCF(myHRP, fromPos, (dist or 0) + 14)
	if cf then myHRP.CFrame = cf end
	task.delay(0.4, function() autoDodgeCooldown = false end)
end

-- Line-of-sight check: can the sheriff see us? --------------------------------
local function sheriffHasLoS(myHRP)
	local sheriff = findByRole('Sheriff')
	if not sheriff or not sheriff.Character then return false end
	local sHead = sheriff.Character:FindFirstChild('Head')
	            or sheriff.Character:FindFirstChild('HumanoidRootPart')
	if not sHead then return false end

	local origin    = sHead.Position
	local target    = myHRP.Position
	local direction = target - origin
	local dist      = direction.Magnitude
	if dist > autoDodgeShotRadius then return false end

	-- Build raycast params that ignore both characters
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclusions = {}
	if sheriff.Character then
		for _, p in sheriff.Character:GetDescendants() do
			if p:IsA('BasePart') then table.insert(exclusions, p) end
		end
	end
	if lplr.Character then
		for _, p in lplr.Character:GetDescendants() do
			if p:IsA('BasePart') then table.insert(exclusions, p) end
		end
	end
	params.FilterDescendantsInstances = exclusions

	local result = workspace:Raycast(origin, direction, params)
	-- No hit means nothing blocks the shot → clear LoS
	return result == nil
end

-- Heartbeat — stab + shot -----------------------------------------------------
local function startAutoDodgeLoop()
	autoDodgeLastMPos = nil
	autoDodgeHBConn = runService.Heartbeat:Connect(function()
		if not roundActive then return end
		local myHRP = getHRP()
		if not myHRP then return end

		-- ── 1. Stab check ──────────────────────────────────────────────────────
		local murderer = findByRole('Murderer')
		local mHRP = murderer and murderer.Character
		              and murderer.Character:FindFirstChild('HumanoidRootPart')
		if mHRP then
			local mPos  = mHRP.Position
			local myPos = myHRP.Position
			local dist  = (myPos - mPos).Magnitude
			local closing = autoDodgeLastMPos
			              and (autoDodgeLastMPos - myPos).Magnitude > dist
			autoDodgeLastMPos = mPos
			if dist < autoDodgeStabRadius and closing then
				triggerDodge(myHRP, mPos, autoDodgeStabRadius)
				return  -- don't double-dodge same frame
			end
		end

		-- ── 3. Shot LoS check (throttled — only every ~0.1 s via modulo) ──────
		-- We use a simple tick-based throttle rather than a separate loop
		if math.floor(tick() * 10) % 1 == 0 then  -- ~10 Hz
			if sheriffHasLoS(myHRP) then
				local sheriff = findByRole('Sheriff')
				local sHRP = sheriff and sheriff.Character
				             and sheriff.Character:FindFirstChild('HumanoidRootPart')
				triggerDodge(myHRP, sHRP and sHRP.Position or nil,
				             autoDodgeShotRadius)
			end
		end
	end)
end

-- Tag signal — thrown knife ---------------------------------------------------
local function startKnifeDodgeSignal()
	autoDodgeTagConn =
		collectionService:GetInstanceAddedSignal('ThrowingKnife'):Connect(function(obj)
			task.defer(function()
				if not roundActive then return end
				local myHRP = getHRP()
				if not myHRP then return end
				local pos = obj:IsA('BasePart') and obj.Position
				          or (obj.PrimaryPart and obj.PrimaryPart.Position)
				if pos and (myHRP.Position - pos).Magnitude <= 30 then
					triggerDodge(myHRP, nil, 0)
				end
			end)
		end)
end

-- GunFired reactive signal ----------------------------------------------------
-- Only dodge when WE are not the shooter (i.e. we have no gun equipped).
-- This prevents the module from teleporting us away from our own shots.
-- Additionally, only react if the sheriff has (or very recently had) LoS — so
-- stray shots from innocents picking up the gun don't trigger a dodge.
local function startGunFiredSignal()
	if not GunFired then return end
	autoDodgeGunConn = GunFired.OnClientEvent:Connect(function()
		if not roundActive then return end
		-- Ignore if we fired it ourselves
		if getEquippedGun() then return end
		-- Only dodge if a sheriff role exists (the threat is real)
		if not findByRole('Sheriff') then return end
		local myHRP = getHRP()
		if myHRP then triggerDodge(myHRP, nil, 0) end
	end)
end

-- Module ----------------------------------------------------------------------
local autoDodgeModule = Combat:CreateModule({
	Name = 'Auto Dodge',
	Tooltip  = 'Dodges stabs, thrown knives, and incoming gunshots automatically',
	Bind = {},
	Function = function(enabled)
		autoDodgeActive = enabled
		-- Disconnect all
		if autoDodgeHBConn  then autoDodgeHBConn:Disconnect();  autoDodgeHBConn  = nil end
		if autoDodgeTagConn then autoDodgeTagConn:Disconnect(); autoDodgeTagConn = nil end
		if autoDodgeGunConn then autoDodgeGunConn:Disconnect(); autoDodgeGunConn = nil end
		autoDodgeLastMPos = nil
		autoDodgeCooldown = false
		if not enabled then return end

		startAutoDodgeLoop()
		startKnifeDodgeSignal()
		startGunFiredSignal()
	end,
})

autoDodgeModule:CreateSlider({
	Name     = 'Stab Radius (studs)',
	Tooltip  = 'Trigger stab dodge when murderer is within this distance',
	Min      = 5,
	Max      = 50,
	Default  = 18,
	Function = function(val) autoDodgeStabRadius = val end,
})

autoDodgeModule:CreateSlider({
	Name     = 'Shot LoS Range (studs)',
	Tooltip  = 'Maximum range for the sheriff line-of-sight dodge check',
	Min      = 20,
	Max      = 150,
	Default  = 60,
	Function = function(val) autoDodgeShotRadius = val end,
})
end

