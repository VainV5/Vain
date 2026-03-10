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
	if not role then
		-- Role not yet known — remove any stale grey ESP and wait for PlayerDataChanged
		removeESP(player)
		return
	end
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

	-- Primary: search inside every non-character Model in workspace.
	-- The dead sheriff's ragdoll is a Model (named after the player) whose
	-- direct children include a Part named "Gun".
	for _, child in workspace:GetChildren() do
		if living[child] then continue end
		if child:IsA('Model') then
			for _, part in child:GetChildren() do
				if isGunPart(part) then return part end
			end
		elseif isGunPart(child) then
			return child
		end
	end

	-- Fallback: workspace.Items (lobby display stand)
	local items = workspace:FindFirstChild('Items')
	if items then
		for _, child in items:GetChildren() do
			if isGunPart(child) then return child end
		end
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
	Bind = {},
	Function = function(enabled)
		if enabled then
			-- When a new Model is added to workspace (e.g. a ragdoll), watch its
			-- children for the gun part appearing, and also check immediately.
			local function watchModel(model)
				-- Check existing children right away (model may already be populated)
				task.defer(function()
					for _, part in model:GetChildren() do
						if isGunPart(part) then
							task.spawn(grabGun, part)
							return
						end
					end
				end)
				-- Watch for children added shortly after the model arrives
				local c = model.ChildAdded:Connect(function(part)
					if isGunPart(part) then task.spawn(grabGun, part) end
				end)
				table.insert(autoGunConns, c)
			end

			-- Watch workspace for new Models (ragdolls)
			local c1 = workspace.ChildAdded:Connect(function(child)
				if child:IsA('Model') and not livingChars()[child] then
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
-- Fling by spinning our own character rapidly while overlapping the target.
-- This uses physics-driven collision: our HRP spins at high angular velocity,
-- which transfers momentum to the target through the physics engine.
local function flingPlayer(target)
	if not target or not target.Character then return end
	local targetHRP = target.Character:FindFirstChild('HumanoidRootPart')
	if not targetHRP then return end

	local myHRP = getHRP()
	if not myHRP then return end
	local myChar = lplr.Character

	local origin   = myHRP.CFrame
	local hum      = myChar:FindFirstChildOfClass('Humanoid')

	-- PlatformStand lets us take manual control of physics
	if hum then hum.PlatformStand = true end

	-- Disable own collision so we can enter the target's space, then
	-- re-enable it so the physics engine actually registers the overlap
	for _, p in myChar:GetDescendants() do
		if p:IsA('BasePart') then p.CanCollide = false end
	end

	-- Move into target
	myHRP.CFrame = targetHRP.CFrame + Vector3.new(0, 0.5, 0)

	-- Re-enable collision to trigger physics interaction
	for _, p in myChar:GetDescendants() do
		if p:IsA('BasePart') then p.CanCollide = true end
	end

	-- Spin our own HRP at extreme angular velocity; the spin + collision
	-- transfers kinetic energy to the target
	local bav = Instance.new('BodyAngularVelocity')
	bav.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	bav.AngularVelocity = Vector3.new(
		math.random(-1, 1) * 9000,
		9000,
		math.random(-1, 1) * 9000
	)
	bav.Parent = myHRP

	-- Small upward push so there is room for the physics to act
	local bv = Instance.new('BodyVelocity')
	bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bv.Velocity  = Vector3.new(0, 80, 0)
	bv.Parent    = myHRP

	task.wait(0.3)

	if bav.Parent then bav:Destroy() end
	if bv.Parent  then bv:Destroy()  end
	if hum then hum.PlatformStand = false end

	-- Return to where we were
	local hrp2 = getHRP()
	if hrp2 then hrp2.CFrame = origin end
end

local flingMurderer
flingMurderer = Combat:CreateModule({
	Name = 'Fling Murderer',
	Notification = false,
	Bind = {},
	Function = function(enabled)
		if not enabled then return end
		local target = findByRole('Murderer')
		if target then
			flingPlayer(target)
		else
			vain:CreateNotification('Vain', 'Murderer not found', 3, 'alert')
		end
		oneShot(flingMurderer)
	end,
})

local flingSheriff
flingSheriff = Combat:CreateModule({
	Name = 'Fling Sheriff',
	Notification = false,
	Bind = {},
	Function = function(enabled)
		if not enabled then return end
		local target = findByRole('Sheriff')
		if target then
			flingPlayer(target)
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
	Notification = false,
	Bind = {},
	Function = function(enabled)
		if not enabled then return end
		local target = flingPlayerTarget ~= '' and playersService:FindFirstChild(flingPlayerTarget)
		if target then
			flingPlayer(target)
		else
			vain:CreateNotification('Vain', 'Select a player first', 3, 'alert')
		end
		oneShot(flingPlayerModule)
	end,
})

flingPlayerDropdown = flingPlayerModule:CreateDropdown({
	Name     = 'Player',
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

-- One-shot: aim + shoot murderer once
local shootMurderer
shootMurderer = Combat:CreateModule({
	Name = 'Shoot Murderer',
	Notification = false,
	Bind = {},
	Function = function(enabled)
		if not enabled then return end
		local target = findByRole('Murderer')
		if target and target.Character then
			local hrp = target.Character:FindFirstChild('HumanoidRootPart')
			if hrp then
				fireAt(hrp)
			end
		else
			vain:CreateNotification('Vain', 'Murderer not found', 3, 'alert')
		end
		oneShot(shootMurderer)
	end,
})

-- Toggled: automatically shoot murderer on a heartbeat loop
local autoShootConn
local autoShoot = Combat:CreateModule({
	Name = 'Auto Shoot',
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
	Min     = 1,
	Max     = 30,
	Default = 6,
	Function = function(val) COIN_STEP = val end,
})

autoFarmModule:CreateSlider({
	Name    = 'Step Interval (ms)',
	Min     = 20,
	Max     = 500,
	Default = 80,
	Function = function(val) COIN_INTERVAL = val / 1000 end,
})

local _af = autoFarmModule

-- ── Combat — Anti-Knife ───────────────────────────────────────────────────────
-- When the murderer's HRP closes within the threshold AND is moving toward us,
-- we snap a short burst away in the opposite direction.
local antiKnifeRadius  = 18  -- studs
local antiKnifeConn
local lastMurdererPos  = nil

local antiKnife = Combat:CreateModule({
	Name = 'Anti-Knife',
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
					-- Dodge away: opposite direction from murderer, same height
					local away = (myPos - mPos)
					away = Vector3.new(away.X, 0, away.Z)
					if away.Magnitude > 0 then
						away = away.Unit * (antiKnifeRadius + 5)
					else
						away = Vector3.new(15, 0, 0)
					end
					myHRP.CFrame = CFrame.new(myPos + away)
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
	Min     = 5,
	Max     = 50,
	Default = 18,
	Function = function(val) antiKnifeRadius = val end,
})

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
	Min     = 5,
	Max     = 80,
	Default = 25,
	Function = function(val) alertRadius = val end,
})

-- ── Combat — Auto Hero ────────────────────────────────────────────────────────
-- When the sheriff dies (gun drops into workspace), automatically grabs the gun.
-- Piggy-backs on the same gun-detection logic as Auto Teleport to Gun.
local autoHeroConns = {}
local autoHeroModule = Combat:CreateModule({
	Name = 'Auto Hero',
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

-- ── Blatant — Walkspeed & Jumppower ──────────────────────────────────────────
local function getHum()
	local char = lplr.Character
	return char and char:FindFirstChildOfClass('Humanoid')
end

local wsModule = Blatant:CreateModule({
	Name = 'Custom Stats',
	Bind = {},
	Function = function(enabled)
		local hum = getHum()
		if not hum then return end
		if enabled then
			-- Values applied via sliders; nothing extra on toggle
		else
			hum.WalkSpeed  = 16
			hum.JumpPower  = 50
		end
	end,
})

wsModule:CreateSlider({
	Name    = 'Walk Speed',
	Min     = 0,
	Max     = 200,
	Default = 16,
	Function = function(val)
		local hum = getHum()
		if hum then hum.WalkSpeed = val end
	end,
})

wsModule:CreateSlider({
	Name    = 'Jump Power',
	Min     = 0,
	Max     = 200,
	Default = 50,
	Function = function(val)
		local hum = getHum()
		if hum then hum.JumpPower = val end
	end,
})

-- Re-apply on respawn so stats persist across deaths
lplr.CharacterAdded:Connect(function(char)
	-- Stats are re-applied once the Humanoid exists
	local hum = char:WaitForChild('Humanoid', 5)
	if not hum then return end
	-- wsModule stores current slider values internally via Vain API if supported;
	-- fallback: nothing to do (sliders will re-fire on next interaction)
end)

-- ── Blatant — Fullbright ──────────────────────────────────────────────────────
local Lighting      = cloneref(game:GetService('Lighting'))
local origLighting  = nil

local fullbright = Blatant:CreateModule({
	Name = 'Fullbright',
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

-- ── Blatant — Spin Bot ────────────────────────────────────────────────────────
-- Continuously rotates our HumanoidRootPart at a set speed while leaving
-- normal movement intact (only rotates, doesn't lock position).
local spinSpeed = 10  -- rotations per second
local spinConn

local spinBot = Blatant:CreateModule({
	Name = 'Spin Bot',
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
	Min     = 1,
	Max     = 50,
	Default = 10,
	Function = function(val) spinSpeed = val end,
})

-- ── Blatant — Fake Lag ────────────────────────────────────────────────────────
-- Jitters our character position at high speed to make us hard to knife
-- and confuse other players about our real location.
local fakeLagAmount = 4   -- stud jitter radius
local fakeLagConn

local fakeLag = Blatant:CreateModule({
	Name = 'Fake Lag',
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
	Min     = 1,
	Max     = 20,
	Default = 4,
	Function = function(val) fakeLagAmount = val end,
})
