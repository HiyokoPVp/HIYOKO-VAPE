local loadstring = function(...)
	local res, err = loadstring(...)
	if err and vape then
		vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert')
	end
	return res
end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/HiyokoPVp/HIYOKO-VAPE/'..readfile('newvape/profiles/commit.txt')..'/'..select(1, path:gsub('newvape/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end
local run = function(func)
	func()
end

local saferun = function(func)
	pcall(func)
end


local queue_on_teleport = queue_on_teleport or function() end
local cloneref = cloneref or function(obj)
	return obj
end

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local lightingService = cloneref(game:GetService('Lighting'))
local marketplaceService = cloneref(game:GetService('MarketplaceService'))
local teleportService = cloneref(game:GetService('TeleportService'))
local httpService = cloneref(game:GetService('HttpService'))
local guiService = cloneref(game:GetService('GuiService'))
local groupService = cloneref(game:GetService('GroupService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local contextService = cloneref(game:GetService('ContextActionService'))
local coreGui = cloneref(game:GetService('CoreGui'))

local isnetworkowner = identifyexecutor and table.find({'AWP', 'Nihon'}, ({identifyexecutor()})[1]) and isnetworkowner or function()
	return true
end
local gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
local lplr = playersService.LocalPlayer
local assetfunction = getcustomasset

local vape = shared.vape
local tween = vape.Libraries.tween
local targetinfo = vape.Libraries.targetinfo
local getfontsize = vape.Libraries.getfontsize
local getcustomasset = vape.Libraries.getcustomasset

local TargetStrafeVector, SpiderShift, WaypointFolder
local Spider = {Enabled = false}
local Phase = {Enabled = false}

local function addBlur(parent)
	local blur = Instance.new('ImageLabel')
	blur.Name = 'Blur'
	blur.Size = UDim2.new(1, 89, 1, 52)
	blur.Position = UDim2.fromOffset(-48, -31)
	blur.BackgroundTransparency = 1
	blur.Image = getcustomasset('newvape/assets/new/blur.png')
	blur.ScaleType = Enum.ScaleType.Slice
	blur.SliceCenter = Rect.new(52, 31, 261, 502)
	blur.Parent = parent
	return blur
end

local function calculateMoveVector(vec)
	local c, s
	local _, _, _, R00, R01, R02, _, _, R12, _, _, R22 = gameCamera.CFrame:GetComponents()
	if R12 < 1 and R12 > -1 then
		c = R22
		s = R02
	else
		c = R00
		s = -R01 * math.sign(R12)
	end
	vec = Vector3.new((c * vec.X + s * vec.Z), 0, (c * vec.Z - s * vec.X)) / math.sqrt(c * c + s * s)
	return vec.Unit == vec.Unit and vec.Unit or Vector3.zero
end

local function isFriend(plr, recolor)
	if vape.Categories.Friends.Options['Use friends'].Enabled then
		local friend = table.find(vape.Categories.Friends.ListEnabled, plr.Name) and true
		if recolor then
			friend = friend and vape.Categories.Friends.Options['Recolor visuals'].Enabled
		end
		return friend
	end
	return nil
end

local function isTarget(plr)
	return table.find(vape.Categories.Targets.ListEnabled, plr.Name) and true
end

local function canClick()
	local mousepos = (inputService:GetMouseLocation() - guiService:GetGuiInset())
	for _, v in lplr.PlayerGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
		local obj = v:FindFirstAncestorOfClass('ScreenGui')
		if v.Active and v.Visible and obj and obj.Enabled then
			return false
		end
	end
	for _, v in coreGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
		local obj = v:FindFirstAncestorOfClass('ScreenGui')
		if v.Active and v.Visible and obj and obj.Enabled then
			return false
		end
	end
	return (not vape.gui.ScaledGui.ClickGui.Visible) and (not inputService:GetFocusedTextBox())
end

local function getTableSize(tab)
	local ind = 0
	for _ in tab do ind += 1 end
	return ind
end

local function getTool()
	return lplr.Character and lplr.Character:FindFirstChildWhichIsA('Tool', true) or nil
end

local function notif(...)
	return vape:CreateNotification(...)
end

local function removeTags(str)
	str = str:gsub('<br%s*/>', '\n')
	return (str:gsub('<[^<>]->', ''))
end

local visited, attempted, tpSwitch = {}, {}, false
local cacheExpire, cache = tick()
local function serverHop(pointer, filter)
	visited = shared.vapeserverhoplist and shared.vapeserverhoplist:split('/') or {}
	if not table.find(visited, game.JobId) then
		table.insert(visited, game.JobId)
	end
	if not pointer then
		notif('Vape', 'Searching for an available server.', 2)
	end

	local suc, httpdata = pcall(function()
		return cacheExpire < tick() and game:HttpGet('https://games.roblox.com/v1/games/'..game.PlaceId..'/servers/Public?sortOrder='..(filter == 'Ascending' and 1 or 2)..'&excludeFullGames=true&limit=100'..(pointer and '&cursor='..pointer or '')) or cache
	end)
	local data = suc and httpService:JSONDecode(httpdata) or nil
	if data and data.data then
		for _, v in data.data do
			if tonumber(v.playing) < playersService.MaxPlayers and not table.find(visited, v.id) and not table.find(attempted, v.id) then
				cacheExpire, cache = tick() + 60, httpdata
				table.insert(attempted, v.id)

				notif('Vape', 'Found! Teleporting.', 5)
				teleportService:TeleportToPlaceInstance(game.PlaceId, v.id)
				return
			end
		end

		if data.nextPageCursor then
			serverHop(data.nextPageCursor, filter)
		else
			notif('Vape', 'Failed to find an available server.', 5, 'warning')
		end
	else
		notif('Vape', 'Failed to grab servers. ('..(data and data.errors[1].message or 'no data')..')', 5, 'warning')
	end
end

vape:Clean(lplr.OnTeleport:Connect(function()
	if not tpSwitch then
		tpSwitch = true
		queue_on_teleport("shared.vapeserverhoplist = '"..table.concat(visited, '/').."'\nshared.vapeserverhopprevious = '"..game.JobId.."'")
	end
end))

local frictionTable, oldfrict, entitylib = {}, {}
local function updateVelocity()
	if getTableSize(frictionTable) > 0 then
		if entitylib.isAlive then
			for _, v in entitylib.character.Character:GetChildren() do
				if v:IsA('BasePart') and v.Name ~= 'HumanoidRootPart' and not oldfrict[v] then
					oldfrict[v] = v.CustomPhysicalProperties or 'none'
					v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
				end
			end
		end
	else
		for i, v in oldfrict do
			i.CustomPhysicalProperties = v ~= 'none' and v or nil
		end
		table.clear(oldfrict)
	end
end

local function motorMove(target, cf)
	local part = Instance.new('Part')
	part.Anchored = true
	part.Parent = workspace
	local motor = Instance.new('Motor6D')
	motor.Part0 = target
	motor.Part1 = part
	motor.C1 = cf
	motor.Parent = part
	task.delay(0, part.Destroy, part)
end

local hash = loadstring(downloadFile('newvape/libraries/hash.lua'), 'hash')()
local prediction = loadstring(downloadFile('newvape/libraries/prediction.lua'), 'prediction')()
entitylib = loadstring(downloadFile('newvape/libraries/entity.lua'), 'entitylibrary')()
local whitelist = {
	alreadychecked = {},
	customtags = {},
	data = {WhitelistedUsers = {}},
	hashes = setmetatable({}, {
		__index = function(_, v)
			return hash and hash.sha512(v..'SelfReport') or ''
		end
	}),
	hooked = false,
	loaded = false,
	localprio = 0,
	said = {}
}
vape.Libraries.entity = entitylib
vape.Libraries.whitelist = whitelist
vape.Libraries.prediction = prediction
vape.Libraries.hash = hash
vape.Libraries.auraanims = {
	Normal = {
		{CFrame = CFrame.new(-0.17, -0.14, -0.12) * CFrame.Angles(math.rad(-53), math.rad(50), math.rad(-64)), Time = 0.1},
		{CFrame = CFrame.new(-0.55, -0.59, -0.1) * CFrame.Angles(math.rad(-161), math.rad(54), math.rad(-6)), Time = 0.08},
		{CFrame = CFrame.new(-0.62, -0.68, -0.07) * CFrame.Angles(math.rad(-167), math.rad(47), math.rad(-1)), Time = 0.03},
		{CFrame = CFrame.new(-0.56, -0.86, 0.23) * CFrame.Angles(math.rad(-167), math.rad(49), math.rad(-1)), Time = 0.03}
	},
	Random = {},
	['Horizontal Spin'] = {
		{CFrame = CFrame.Angles(math.rad(-10), math.rad(-90), math.rad(-80)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(-10), math.rad(180), math.rad(-80)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(-10), math.rad(90), math.rad(-80)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(-10), 0, math.rad(-80)), Time = 0.12}
	},
	['Vertical Spin'] = {
		{CFrame = CFrame.Angles(math.rad(-90), 0, math.rad(15)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(180), 0, math.rad(15)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(90), 0, math.rad(15)), Time = 0.12},
		{CFrame = CFrame.Angles(0, 0, math.rad(15)), Time = 0.12}
	},
	Exhibition = {
		{CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.1},
		{CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.2}
	},
	['Exhibition Old'] = {
		{CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.15},
		{CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.05},
		{CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.1},
		{CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.05},
		{CFrame = CFrame.new(0.63, -0.1, 1.37) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.15}
	}
}

local SpeedMethods
local SpeedMethodList = {'Velocity'}
SpeedMethods = {
	Velocity = function(options, moveDirection)
		local root = entitylib.character.RootPart
		root.AssemblyLinearVelocity = (moveDirection * options.Value.Value) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	end,
	Impulse = function(options, moveDirection)
		local root = entitylib.character.RootPart
		local diff = ((moveDirection * options.Value.Value) - root.AssemblyLinearVelocity) * Vector3.new(1, 0, 1)
		if diff.Magnitude > (moveDirection == Vector3.zero and 10 or 2) then
			root:ApplyImpulse(diff * root.AssemblyMass)
		end
	end,
	CFrame = function(options, moveDirection, dt)
		local root = entitylib.character.RootPart
		local dest = (moveDirection * math.max(options.Value.Value - entitylib.character.Humanoid.WalkSpeed, 0) * dt)
		if options.WallCheck.Enabled then
			options.rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
			options.rayCheck.CollisionGroup = root.CollisionGroup
			local ray = workspace:Raycast(root.Position, dest, options.rayCheck)
			if ray then
				dest = ((ray.Position + ray.Normal) - root.Position)
			end
		end
		root.CFrame += dest
	end,
	TP = function(options, moveDirection)
		if options.TPTiming < tick() then
			options.TPTiming = tick() + options.TPFrequency.Value
			SpeedMethods.CFrame(options, moveDirection, 1)
		end
	end,
	WalkSpeed = function(options)
		if not options.WalkSpeed then options.WalkSpeed = entitylib.character.Humanoid.WalkSpeed end
		entitylib.character.Humanoid.WalkSpeed = options.Value.Value
	end,
	Pulse = function(options, moveDirection)
		local root = entitylib.character.RootPart
		local dt = math.max(options.Value.Value - entitylib.character.Humanoid.WalkSpeed, 0)
		dt = dt * (1 - math.min((tick() % (options.PulseLength.Value + options.PulseDelay.Value)) / options.PulseLength.Value, 1))
		root.AssemblyLinearVelocity = (moveDirection * (entitylib.character.Humanoid.WalkSpeed + dt)) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	end
}
for name in SpeedMethods do
	if not table.find(SpeedMethodList, name) then
		table.insert(SpeedMethodList, name)
	end
end

run(function()
	entitylib.getUpdateConnections = function(ent)
		local hum = ent.Humanoid
		return {
			hum:GetPropertyChangedSignal('Health'),
			hum:GetPropertyChangedSignal('MaxHealth'),
			{
				Connect = function()
					ent.Friend = ent.Player and isFriend(ent.Player) or nil
					ent.Target = ent.Player and isTarget(ent.Player) or nil
					return {
						Disconnect = function() end
					}
				end
			}
		}
	end

	entitylib.targetCheck = function(ent)
		if ent.TeamCheck then
			return ent:TeamCheck()
		end
		if ent.NPC then return true end
		if isFriend(ent.Player) then return false end
		if not select(2, whitelist:get(ent.Player)) then return false end
		if vape.Categories.Main.Options['Teams by server'].Enabled then
			if not lplr.Team then return true end
			if not ent.Player.Team then return true end
			if ent.Player.Team ~= lplr.Team then return true end
			return #ent.Player.Team:GetPlayers() == #playersService:GetPlayers()
		end
		return true
	end

	entitylib.getEntityColor = function(ent)
		ent = ent.Player
		if not (ent and vape.Categories.Main.Options['Use team color'].Enabled) then return end
		if isFriend(ent, true) then
			return Color3.fromHSV(vape.Categories.Friends.Options['Friends color'].Hue, vape.Categories.Friends.Options['Friends color'].Sat, vape.Categories.Friends.Options['Friends color'].Value)
		end
		return tostring(ent.TeamColor) ~= 'White' and ent.TeamColor.Color or nil
	end

	vape:Clean(function()
		entitylib.kill()
		entitylib = nil
	end)
	vape:Clean(vape.Categories.Friends.Update.Event:Connect(function() entitylib.refresh() end))
	vape:Clean(vape.Categories.Targets.Update.Event:Connect(function() entitylib.refresh() end))
	vape:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))
	vape:Clean(workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
		gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
	end))
end)

run(function()
	function whitelist:get(plr)
		local plrstr = self.hashes[plr.Name..plr.UserId]
		for _, v in self.data.WhitelistedUsers do
			if v.hash == plrstr then
				return v.level, v.attackable or whitelist.localprio >= v.level, v.tags
			end
		end
		return 0, true
	end

	function whitelist:isingame()
		for _, v in playersService:GetPlayers() do
			if self:get(v) ~= 0 then return true end
		end
		return false
	end

	function whitelist:tag(plr, text, rich)
		local plrtag, newtag = select(3, self:get(plr)) or self.customtags[plr.Name] or {}, ''
		if not text then return plrtag end
		for _, v in plrtag do
			newtag = newtag..(rich and '<font color="#'..v.color:ToHex()..'">['..v.text..']</font>' or '['..removeTags(v.text)..']')..' '
		end
		return newtag
	end

	function whitelist:getplayer(arg)
		if arg == 'default' and self.localprio == 0 then return true end
		if arg == 'private' and self.localprio == 1 then return true end
		if arg and lplr.Name:lower():sub(1, arg:len()) == arg:lower() then return true end
		return false
	end

	local olduninject
	function whitelist:playeradded(v, joined)
		if self:get(v) ~= 0 then
			if self.alreadychecked[v.UserId] then return end
			self.alreadychecked[v.UserId] = true
			self:hook()
			if self.localprio == 0 then
				olduninject = vape.Uninject
				vape.Uninject = function()
					notif('Vape', 'No escaping the private members :)', 10)
				end
				if joined then
					task.wait(10)
				end
				if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
					local oldchannel = textChatService.ChatInputBarConfiguration.TargetTextChannel
					local newchannel = cloneref(game:GetService('RobloxReplicatedStorage')).ExperienceChat.WhisperChat:InvokeServer(v.UserId)
					if newchannel then
						newchannel:SendAsync('helloimusinginhaler')
					end
					textChatService.ChatInputBarConfiguration.TargetTextChannel = oldchannel
				elseif replicatedStorage:FindFirstChild('DefaultChatSystemChatEvents') then
					replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer('/w '..v.Name..' helloimusinginhaler', 'All')
				end
			end
		end
	end

	function whitelist:process(msg, plr)
		if plr == lplr and msg == 'helloimusinginhaler' then return true end

		if self.localprio > 0 and not self.said[plr.Name] and msg == 'helloimusinginhaler' and plr ~= lplr then
			self.said[plr.Name] = true
			notif('Vape', plr.Name..' is using vape!', 60)
			self.customtags[plr.Name] = {{
				text = 'VAPE USER',
				color = Color3.new(1, 1, 0)
			}}
			local newent = entitylib.getEntity(plr)
			if newent then
				entitylib.Events.EntityUpdated:Fire(newent)
			end
			return true
		end

		if self.localprio < self:get(plr) or plr == lplr then
			local args = msg:split(' ')
			table.remove(args, 1)
			if self:getplayer(args[1]) then
				table.remove(args, 1)
				for cmd, func in self.commands do
					if msg:sub(1, cmd:len() + 1):lower() == ';'..cmd:lower() then
						func(args, plr)
						return true
					end
				end
			end
		end

		return false
	end

	function whitelist:newchat(obj, plr, skip)
		obj.Text = self:tag(plr, true, true)..obj.Text
		local sub = obj.ContentText:find(': ')
		if sub then
			if not skip and self:process(obj.ContentText:sub(sub + 3, #obj.ContentText), plr) then
				obj.Visible = false
			end
		end
	end

	function whitelist:oldchat(func)
		local msgtable, oldchat = debug.getupvalue(func, 3)
		if typeof(msgtable) == 'table' and msgtable.CurrentChannel then
			whitelist.oldchattable = msgtable
		end

		oldchat = hookfunction(func, function(data, ...)
			local plr = playersService:GetPlayerByUserId(data.SpeakerUserId)
			if plr then
				data.ExtraData.Tags = data.ExtraData.Tags or {}
				for _, v in self:tag(plr) do
					table.insert(data.ExtraData.Tags, {TagText = v.text, TagColor = v.color})
				end
				if data.Message and self:process(data.Message, plr) then
					data.Message = ''
				end
			end
			return oldchat(data, ...)
		end)

		vape:Clean(function()
			hookfunction(func, oldchat)
		end)
	end

	function whitelist:hook()
		if self.hooked then return end
		self.hooked = true

		local exp = coreGui:FindFirstChild('ExperienceChat')
		if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			if exp and exp:WaitForChild('appLayout', 5) then
				vape:Clean(exp:FindFirstChild('RCTScrollContentView', true).ChildAdded:Connect(function(obj)
					local plr = playersService:GetPlayerByUserId(tonumber(obj.Name:split('-')[1]) or 0)
					obj = obj:FindFirstChild('TextMessage', true)
					if obj and obj:IsA('TextLabel') then
						if plr then
							self:newchat(obj, plr, true)
							obj:GetPropertyChangedSignal('Text'):Wait()
							self:newchat(obj, plr)
						end

						if obj.ContentText:sub(1, 35) == 'You are now privately chatting with' then
							obj.Visible = false
						end
					end
				end))
			end
		elseif replicatedStorage:FindFirstChild('DefaultChatSystemChatEvents') then
			pcall(function()
				for _, v in getconnections(replicatedStorage.DefaultChatSystemChatEvents.OnNewMessage.OnClientEvent) do
					if v.Function and table.find(debug.getconstants(v.Function), 'UpdateMessagePostedInChannel') then
						whitelist:oldchat(v.Function)
						break
					end
				end

				for _, v in getconnections(replicatedStorage.DefaultChatSystemChatEvents.OnMessageDoneFiltering.OnClientEvent) do
					if v.Function and table.find(debug.getconstants(v.Function), 'UpdateMessageFiltered') then
						whitelist:oldchat(v.Function)
						break
					end
				end
			end)
		end

		if exp then
			local bubblechat = exp:WaitForChild('bubbleChat', 5)
			if bubblechat then
				vape:Clean(bubblechat.DescendantAdded:Connect(function(newbubble)
					if newbubble:IsA('TextLabel') and newbubble.Text:find('helloimusinginhaler') then
						newbubble.Parent.Parent.Visible = false
					end
				end))
			end
		end
	end

	function whitelist:update(first)
		local suc = pcall(function()
			local _, subbed = pcall(function()
				return game:HttpGet('https://github.com/7GrandDadPGN/whitelists')
			end)
			local commit = subbed:find('currentOid')
			commit = commit and subbed:sub(commit + 13, commit + 52) or nil
			commit = commit and #commit == 40 and commit or 'main'
			whitelist.textdata = game:HttpGet('https://raw.githubusercontent.com/7GrandDadPGN/whitelists/'..commit..'/PlayerWhitelist.json', true)
		end)
		if not suc or not hash or not whitelist.get then return true end
		whitelist.loaded = true

		if not first or whitelist.textdata ~= whitelist.olddata then
			if not first then
				whitelist.olddata = isfile('newvape/profiles/whitelist.json') and readfile('newvape/profiles/whitelist.json') or nil
			end

			local suc, res = pcall(function()
				return httpService:JSONDecode(whitelist.textdata)
			end)

			whitelist.data = suc and type(res) == 'table' and res or whitelist.data
			whitelist.localprio = whitelist:get(lplr)

			for _, v in whitelist.data.WhitelistedUsers do
				if v.tags then
					for _, tag in v.tags do
						tag.color = Color3.fromRGB(unpack(tag.color))
					end
				end
			end

			if not whitelist.connection then
				whitelist.connection = playersService.PlayerAdded:Connect(function(v)
					whitelist:playeradded(v, true)
				end)
				vape:Clean(whitelist.connection)
			end

			for _, v in playersService:GetPlayers() do
				whitelist:playeradded(v)
			end

			if entitylib.Running and vape.Loaded then
				entitylib.refresh()
			end

			if whitelist.textdata ~= whitelist.olddata then
				if whitelist.data.Announcement.expiretime > os.time() then
					local targets = whitelist.data.Announcement.targets
					targets = targets == 'all' and {tostring(lplr.UserId)} or targets:split(',')

					if table.find(targets, tostring(lplr.UserId)) then
						local hint = Instance.new('Hint')
						hint.Text = 'VAPE ANNOUNCEMENT: '..whitelist.data.Announcement.text
						hint.Parent = workspace
						game:GetService('Debris'):AddItem(hint, 20)
					end
				end
				whitelist.olddata = whitelist.textdata
				pcall(function()
					writefile('newvape/profiles/whitelist.json', whitelist.textdata)
				end)
			end

			if whitelist.data.KillVape then
				vape:Uninject()
				return true
			end

			if whitelist.data.BlacklistedUsers[tostring(lplr.UserId)] then
				task.spawn(lplr.kick, lplr, whitelist.data.BlacklistedUsers[tostring(lplr.UserId)])
				return true
			end
		end
	end

	whitelist.commands = {
		byfron = function()
			task.spawn(function()
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				local UIBlox = getrenv().require(game:GetService('CorePackages').UIBlox)
				local Roact = getrenv().require(game:GetService('CorePackages').Roact)
				UIBlox.init(getrenv().require(game:GetService('CorePackages').Workspace.Packages.RobloxAppUIBloxConfig))
				local auth = getrenv().require(coreGui.RobloxGui.Modules.LuaApp.Components.Moderation.ModerationPrompt)
				local darktheme = getrenv().require(game:GetService('CorePackages').Workspace.Packages.Style).Themes.DarkTheme
				local fonttokens = getrenv().require(game:GetService("CorePackages").Packages._Index.UIBlox.UIBlox.App.Style.Tokens).getTokens('Desktop', 'Dark', true)
				local buildersans = getrenv().require(game:GetService('CorePackages').Packages._Index.UIBlox.UIBlox.App.Style.Fonts.FontLoader).new(true, fonttokens):loadFont()
				local tLocalization = getrenv().require(game:GetService('CorePackages').Workspace.Packages.RobloxAppLocales).Localization
				local localProvider = getrenv().require(game:GetService('CorePackages').Workspace.Packages.Localization).LocalizationProvider
				lplr.PlayerGui:ClearAllChildren()
				vape.gui.Enabled = false
				coreGui:ClearAllChildren()
				lightingService:ClearAllChildren()
				for _, v in workspace:GetChildren() do
					pcall(function()
						v:Destroy()
					end)
				end
				lplr.kick(lplr)
				guiService:ClearError()
				local gui = Instance.new('ScreenGui')
				gui.IgnoreGuiInset = true
				gui.Parent = coreGui
				local frame = Instance.new('ImageLabel')
				frame.BorderSizePixel = 0
				frame.Size = UDim2.fromScale(1, 1)
				frame.BackgroundColor3 = Color3.fromRGB(224, 223, 225)
				frame.ScaleType = Enum.ScaleType.Crop
				frame.Parent = gui
				task.delay(0.3, function()
					frame.Image = 'rbxasset://textures/ui/LuaApp/graphic/Auth/GridBackground.jpg'
				end)
				task.delay(0.6, function()
					local modPrompt = Roact.createElement(auth, {
						style = {},
						screenSize = vape.gui.AbsoluteSize or Vector2.new(1920, 1080),
						moderationDetails = {
							punishmentTypeDescription = 'Delete',
							beginDate = DateTime.fromUnixTimestampMillis(DateTime.now().UnixTimestampMillis - ((60 * math.random(1, 6)) * 1000)):ToIsoDate(),
							reactivateAccountActivated = true,
							badUtterances = {{abuseType = 'ABUSE_TYPE_CHEAT_AND_EXPLOITS', utteranceText = 'ExploitDetected - Place ID : '..game.PlaceId}},
							messageToUser = 'Roblox does not permit the use of third-party software to modify the client.'
						},
						termsActivated = function() end,
						communityGuidelinesActivated = function() end,
						supportFormActivated = function() end,
						reactivateAccountActivated = function() end,
						logoutCallback = function() end,
						globalGuiInset = {top = 0}
					})

					local screengui = Roact.createElement(localProvider, {
						localization = tLocalization.new('en-us')
					}, {Roact.createElement(UIBlox.Style.Provider, {
						style = {
							Theme = darktheme,
							Font = buildersans
						},
					}, {modPrompt})})

					Roact.mount(screengui, coreGui)
				end)
			end)
		end,
		crash = function()
			task.spawn(function()
				repeat
					local part = Instance.new('Part')
					part.Size = Vector3.new(1e10, 1e10, 1e10)
					part.Parent = workspace
				until false
			end)
		end,
		deletemap = function()
			local terrain = workspace:FindFirstChildWhichIsA('Terrain')
			if terrain then
				terrain:Clear()
			end

			for _, v in workspace:GetChildren() do
				if v ~= terrain and not v:IsDescendantOf(lplr.Character) and not v:IsA('Camera') then
					v:Destroy()
					v:ClearAllChildren()
				end
			end
		end,
		framerate = function(args)
			if #args < 1 or not setfpscap then return end
			setfpscap(tonumber(args[1]) ~= '' and math.clamp(tonumber(args[1]) or 9999, 1, 9999) or 9999)
		end,
		gravity = function(args)
			workspace.Gravity = tonumber(args[1]) or workspace.Gravity
		end,
		jump = function()
			if entitylib.isAlive and entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end,
		kick = function(args)
			task.spawn(function()
				lplr:Kick(table.concat(args, ' '))
			end)
		end,
		kill = function()
			if entitylib.isAlive then
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Dead)
				entitylib.character.Humanoid.Health = 0
			end
		end,
		reveal = function()
			task.delay(0.1, function()
				if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
					textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync('I am using the inhaler client')
				else
					replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer('I am using the inhaler client', 'All')
				end
			end)
		end,
		shutdown = function()
			game:Shutdown()
		end,
		toggle = function(args)
			if #args < 1 then return end
			if args[1]:lower() == 'all' then
				for i, v in vape.Modules do
					if i ~= 'Panic' and i ~= 'ServerHop' and i ~= 'Rejoin' then
						v:Toggle()
					end
				end
			else
				for i, v in vape.Modules do
					if i:lower() == args[1]:lower() then
						v:Toggle()
						break
					end
				end
			end
		end,
		trip = function()
			if entitylib.isAlive then
				if entitylib.character.RootPart.Velocity.Magnitude < 15 then
					entitylib.character.RootPart.Velocity = entitylib.character.RootPart.CFrame.LookVector * 15
				end
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
			end
		end,
		uninject = function()
			if olduninject then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				olduninject(vape)
			else
				vape:Uninject()
			end
		end,
		void = function()
			if entitylib.isAlive then
				entitylib.character.RootPart.CFrame += Vector3.new(0, -1000, 0)
			end
		end
	}

	task.spawn(function()
		repeat
			if whitelist:update(whitelist.loaded) then return end
			task.wait(10)
		until vape.Loaded == nil
	end)

	vape:Clean(function()
		table.clear(whitelist.commands)
		table.clear(whitelist.data)
		table.clear(whitelist)
	end)
end)

local function hasSword()
	local player = game:GetService("Players").LocalPlayer
	local character = player.Character
	if not character then return false end
	
	for _, child in pairs(character:GetChildren()) do
		if string.find(string.lower(child.Name), "sword") then
			return true
		end
	end
	
	return false
end

run(function()

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Combat = vape.Categories.Combat

local MaxAngle = 120
local WallCheck = false
local MouseRequire = false
local MouseClickReq = false  
local UpdateHz = 10
local TeamCheck = false
local Range = 14
local ToolCheck = true 
local GUICheck = true
local CustomHitReg = 1
local AirHits = 100
local MaxAngleVisualiser = false
local TargetNPC = false

local MouseDown = false
local JustClicked = false  


local lastFireTime = 0
local fireInterval = 10 / 1  

UIS.InputBegan:Connect(function(input,gp)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        MouseDown = true
        JustClicked = true  
    end
end)

UIS.InputEnded:Connect(function(input,gp)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        MouseDown = false
    end
end)


local visualiserPart
local function updateVisualiser()
    if MaxAngleVisualiser then
        if not visualiserPart then
            visualiserPart = Instance.new("Part")
            visualiserPart.Anchored = true
            visualiserPart.CanCollide = false
            visualiserPart.Material = Enum.Material.Neon
            visualiserPart.Color = Color3.fromRGB(255, 0, 0)
            visualiserPart.Transparency = 0.7
            visualiserPart.Parent = workspace
        end
        
        local character = player.Character
        if character then
            local root = character:FindFirstChild("HumanoidRootPart")
            if root then
                local angle = math.rad(MaxAngle / 2)
                local distance = Range
                
                visualiserPart.Size = Vector3.new(0.5, 0.5, distance)
                visualiserPart.CFrame = root.CFrame * CFrame.new(0, 0, -distance/2)
                visualiserPart.Parent = workspace
            end
        end
    else
        if visualiserPart then
            visualiserPart:Destroy()
            visualiserPart = nil
        end
    end
end

RunService.RenderStepped:Connect(function()
    updateVisualiser()
end)

local Hits
Hits = Combat:CreateModule({
    Name = "Killaura",
    Tooltip = "Closest enemy hit",
    Function = function(enabled)

        if enabled then
            task.spawn(function()

                while Hits.Enabled do  

                    if MouseRequire then
                        if MouseClickReq then
                            if not JustClicked then
                                task.wait(1/UpdateHz)
                                continue
                            end
                        else
                            if not MouseDown then
                                task.wait(1/UpdateHz)
                                continue
                            end
                        end
                    end
                    
                    if ToolCheck and not hasSword() then
                        task.wait(1/UpdateHz)
                        continue
                    end

                    if GUICheck then
                        local playerGui = player:WaitForChild("PlayerGui")
                        local itemShop = playerGui:FindFirstChild("ItemShop")
                        local inventoryApp = playerGui:FindFirstChild("InventoryApp")
                        
                        if itemShop or inventoryApp then
                            task.wait(1/UpdateHz)
                            continue
                        end
                    end

                    local character = player.Character
                    if not character then task.wait() continue end

                    local root = character:FindFirstChild("HumanoidRootPart")
                    local head = character:FindFirstChild("Head")

                    if not root or not head then
                        task.wait()
                        continue
                    end

                    local closest
                    local closestDist = math.huge

                    
                    local targets = {}
                    
                    if TargetNPC then
                        
                        for _, obj in pairs(workspace:GetDescendants()) do
                            if obj:IsA("Humanoid") and obj.Parent ~= character then
                                local char = obj.Parent
                                if char:FindFirstChild("HumanoidRootPart") then
                                    table.insert(targets, char)
                                end
                            end
                        end
                    else
                        
                        for _,v in pairs(Players:GetPlayers()) do
                            if v ~= player and v.Character then
                                table.insert(targets, v.Character)
                            end
                        end
                    end

                    for _, targetChar in pairs(targets) do

                        local enemyRoot = targetChar:FindFirstChild("HumanoidRootPart")
                        if not enemyRoot then continue end

                        if not TargetNPC then
                            local targetPlayer = Players:GetPlayerFromCharacter(targetChar)
                            if TeamCheck and targetPlayer and targetPlayer.Team == player.Team then
                                continue
                            end
                        end

                        local dist = (enemyRoot.Position - root.Position).Magnitude

                        if dist > Range then
                            continue
                        end

                        local localFacing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
                        local targetDirection = ((enemyRoot.Position - root.Position) * Vector3.new(1, 0, 1)).Unit
                        
                        local angle = math.acos(math.clamp(localFacing:Dot(targetDirection), -1, 1))

                        if angle > math.rad(MaxAngle / 2) then
                            continue
                        end

                        
                        local humanoid = targetChar:FindFirstChild("Humanoid")
                        if humanoid then
                            local isAirborne = humanoid:GetState() == Enum.HumanoidStateType.Freefall or 
                                             humanoid:GetState() == Enum.HumanoidStateType.Flying
                            
                            if isAirborne then
                                local chance = math.random(1, 100)
                                if chance > AirHits then
                                    continue
                                end
                            end
                        end

                        if WallCheck then
                            local rayParams = RaycastParams.new()
                            rayParams.FilterType = Enum.RaycastFilterType.Blacklist
                            rayParams.FilterDescendantsInstances = {character}

                            local result = workspace:Raycast(
                                head.Position,
                                enemyRoot.Position - head.Position,
                                rayParams
                            )

                            if result and not result.Instance:IsDescendantOf(targetChar) then
                                continue
                            end
                        end

                        if dist < closestDist then
                            closestDist = dist
                            closest = targetChar
                        end

                    end

                    if closest then

                        local targetRoot = closest:FindFirstChild("HumanoidRootPart")
                        if not targetRoot then
                            task.wait()
                            continue
                        end

                        
                        local currentTime = tick()
                        fireInterval = 10 / CustomHitReg
                        
                        if currentTime - lastFireTime < fireInterval then
                            task.wait(1/UpdateHz)
                            continue
                        end
                        
                        lastFireTime = currentTime

                        local cursorDirection =
                            (targetRoot.Position - camera.CFrame.Position).Unit

                        local inventory = ReplicatedStorage
                            :WaitForChild("Inventories")
                            :WaitForChild(player.Name)

                        local sword

                        for _,item in ipairs(inventory:GetChildren()) do
                            if string.find(string.lower(item.Name),"sword") then
                                sword = item
                                break
                            end
                        end

                        if sword then

                            ReplicatedStorage
                            :WaitForChild("rbxts_include")
                            :WaitForChild("node_modules")
                            :WaitForChild("@rbxts")
                            :WaitForChild("net")
                            :WaitForChild("out")
                            :WaitForChild("_NetManaged")
                            :WaitForChild("SwordHit")
                            :FireServer({

                                chargedAttack = {
                                    chargeRatio = 0
                                },

                                entityInstance = closest,

                                validate = {

                                    targetPosition = {
                                        value = targetRoot.Position
                                    },

                                    raycast = {

                                        cameraPosition = {
                                            value = camera.CFrame.Position
                                        },

                                        cursorDirection = {
                                            value = cursorDirection
                                        }

                                    },

                                    selfPosition = {
                                        value = root.Position
                                    }

                                },

                                weapon = sword

                            })

                        end
                    end

                    if JustClicked then
                        JustClicked = false
                    end

                    task.wait(1/UpdateHz)

                end
            end)
        else
            
            if visualiserPart then
                visualiserPart:Destroy()
                visualiserPart = nil
            end
        end
    end
})

Hits:CreateToggle({
    Name = "WallCheck",
    Default = true,
    Function = function(v)
        WallCheck = v
    end
})

Hits:CreateToggle({
    Name = "Mouse Require",
    Default = false,
    Function = function(v)
        MouseRequire = v
    end
})

Hits:CreateToggle({
    Name = "MouseClickReq",  
    Default = false,
    Function = function(v)
        MouseClickReq = v
    end
})

Hits:CreateToggle({
    Name = "Team Check",
    Default = false,
    Function = function(v)
        TeamCheck = v
    end
})

Hits:CreateToggle({
    Name = "Tool Check",
    Default = true,
    Function = function(v)
        ToolCheck = v
    end
})

Hits:CreateToggle({
    Name = "GUI Check",
    Default = true,
    Function = function(v)
        GUICheck = v
    end
})

Hits:CreateToggle({
    Name = "MaxAngle Visualiser",
    Default = false,
    Function = function(v)
        MaxAngleVisualiser = v
        if not v and visualiserPart then
            visualiserPart:Destroy()
            visualiserPart = nil
        end
    end
})

Hits:CreateToggle({
    Name = "Target NPC",
    Default = false,
    Function = function(v)
        TargetNPC = v
    end
})

Hits:CreateSlider({
    Name = "MaxAngle",
    Min = 1,
    Max = 360,
    Default = 360,
    Function = function(v)
        MaxAngle = v
    end
})

Hits:CreateSlider({
    Name = "Update Hz",
    Min = 1,
    Max = 60,
    Default = 10,
    Function = function(v)
        UpdateHz = v
    end
})

Hits:CreateSlider({
    Name = "Range (studs)",
    Min = 1,
    Max = 14.4,
    Default = 14,
    Function = function(v)
        Range = v
    end
})

Hits:CreateSlider({
    Name = "Custom Hit Reg",
    Min = 1,
    Max = 36,
    Default = 1,
    Function = function(v)
        CustomHitReg = v
        fireInterval = 10 / v
    end
})

Hits:CreateSlider({
    Name = "Air Hits",
    Min = 0,
    Max = 100,
    Default = 100,
    Function = function(v)
        AirHits = v
    end
})

end)


run(function()

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local lplr = Players.LocalPlayer
local Combat = vape.Categories.Combat


local bedwars = {}

pcall(function()
	local controller = require(
		ReplicatedStorage.TS.controllers.game.sword["sword-controller"]
	)

	if controller and controller.SwordController then
		bedwars.SwordController = controller.SwordController
	end
end)

local CPS = 12
local RandomizeCPS = true
local CPSVariation = 2
local ToolCheckAC = false
local MouseDown = false
local LastSwing = 0

UIS.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		MouseDown = true
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		MouseDown = false
	end
end)

local function canClick()
	local mousepos = (UIS:GetMouseLocation() - GuiService:GetGuiInset())

	for _, v in lplr.PlayerGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
		local obj = v:FindFirstAncestorOfClass("ScreenGui")
		if v.Active and v.Visible and obj and obj.Enabled then
			return false
		end
	end

	for _, v in CoreGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
		local obj = v:FindFirstAncestorOfClass("ScreenGui")
		if v.Active and v.Visible and obj and obj.Enabled then
			return false
		end
	end

	return (not vape.gui.ScaledGui.ClickGui.Visible)
		and (not UIS:GetFocusedTextBox())
end

local function hasSwordAC()
	if not ToolCheckAC then return true end
	
	local character = lplr.Character
	if not character then return false end
	
	for _, child in pairs(character:GetChildren()) do
		if child:IsA("Tool") and string.lower(child.Name):find("sword") then
			return true
		end
	end
	
	return false
end

local AutoClicker
AutoClicker = Combat:CreateModule({
	Name = "AutoClicker",
	Tooltip = "Auto swing sword using SwordController",
	Function = function(callback)

		if callback then

			task.spawn(function()

				while AutoClicker.Enabled do

					if MouseDown and canClick() and hasSwordAC() then
						
						local currentTime = tick()
						
						local actualCPS = CPS
						if RandomizeCPS then
							actualCPS = CPS + math.random(-CPSVariation, CPSVariation)
							actualCPS = math.max(1, actualCPS)
						end
						
						local delay = 1 / actualCPS
						
						if currentTime - LastSwing >= delay then
							pcall(function()
								if bedwars.SwordController and lplr.Character then
									bedwars.SwordController:swingSwordAtMouse()
								end
							end)
							LastSwing = currentTime
						end
					end

					task.wait(0.01)

				end

			end)

		end
	end
})

AutoClicker:CreateSlider({
	Name = "CPS",
	Min = 1,
	Max = 25,
	Default = 12,
	Function = function(v)
		CPS = v
	end
})

AutoClicker:CreateToggle({
	Name = "Randomize CPS",
	Default = true,
	Function = function(v)
		RandomizeCPS = v
	end
})

AutoClicker:CreateSlider({
	Name = "CPS Variation",
	Min = 0,
	Max = 5,
	Default = 2,
	Function = function(v)
		CPSVariation = v
	end
})

AutoClicker:CreateToggle({
	Name = "Tool Check",
	Default = false,
	Function = function(v)
		ToolCheckAC = v
	end
})

end)

run(function()

local Players = game:GetService("Players")
local lplr = Players.LocalPlayer
local Combat = vape.Categories.Combat

local Horizontal = 0
local Vertical = 0

local VelocityConnection

local Velocity = Combat:CreateModule({
	Name = "Velocity",
	Tooltip = "Reduce knockback",
	Function = function(enabled)

		if enabled then

			local character = lplr.Character or lplr.CharacterAdded:Wait()
			local root = character:WaitForChild("HumanoidRootPart")

			VelocityConnection = root:GetPropertyChangedSignal("Velocity"):Connect(function()

				local vel = root.Velocity

				root.Velocity = Vector3.new(
					vel.X * (Horizontal / 100),
					vel.Y * (Vertical / 100),
					vel.Z * (Horizontal / 100)
				)

			end)

		else

			if VelocityConnection then
				VelocityConnection:Disconnect()
				VelocityConnection = nil
			end

		end
	end
})

Velocity:CreateSlider({
	Name = "Horizontal %",
	Min = 0,
	Max = 100,
	Default = 0,
	Function = function(v)
		Horizontal = v
	end
})

Velocity:CreateSlider({
	Name = "Vertical %",
	Min = 0,
	Max = 100,
	Default = 0,
	Function = function(v)
		Vertical = v
	end
})

end)

run(function()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local lplr = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Combat = vape.Categories.Combat

local Range = 30
local MaxAngle = 90
local Smooth = 0.2
local TeamCheck = false
local WallCheck = false

local AimConnection

local function getTarget()

	local character = lplr.Character
	if not character then return end

	local head = character:FindFirstChild("Head")
	if not head then return end

	local closest
	local closestDist = math.huge

	for _,player in pairs(Players:GetPlayers()) do

		if player ~= lplr and player.Character then

			if TeamCheck and player.Team == lplr.Team then
				continue
			end

			local enemyHead = player.Character:FindFirstChild("Head")
			local enemyRoot = player.Character:FindFirstChild("HumanoidRootPart")

			if enemyHead and enemyRoot then

				local dist = (enemyRoot.Position - head.Position).Magnitude

				if dist > Range then
					continue
				end

				local dir = (enemyRoot.Position - head.Position).Unit
				local look = camera.CFrame.LookVector

				local angle = math.deg(math.acos(math.clamp(look:Dot(dir), -1, 1)))

				if angle > MaxAngle then
					continue
				end

				if WallCheck then

					local rayParams = RaycastParams.new()
					rayParams.FilterType = Enum.RaycastFilterType.Blacklist
					rayParams.FilterDescendantsInstances = {character}

					local result = workspace:Raycast(
						head.Position,
						enemyRoot.Position - head.Position,
						rayParams
					)

					if result and not result.Instance:IsDescendantOf(player.Character) then
						continue
					end

				end

				if dist < closestDist then
					closestDist = dist
					closest = enemyHead
				end

			end
		end
	end

	return closest

end

local AimAssist
AimAssist = Combat:CreateModule({

	Name = "AimAssist",
	Tooltip = "Smooth aim to closest player",

	Function = function(enabled)

		if enabled then

			AimConnection = RunService.RenderStepped:Connect(function()

				local target = getTarget()
				if not target then return end

				local targetPos = target.Position

				local newCF = CFrame.new(camera.CFrame.Position, targetPos)

				camera.CFrame = camera.CFrame:Lerp(newCF, Smooth)

			end)

		else

			if AimConnection then
				AimConnection:Disconnect()
				AimConnection = nil
			end

		end

	end

})

AimAssist:CreateSlider({
	Name = "Range",
	Min = 5,
	Max = 100,
	Default = 30,
	Function = function(v)
		Range = v
	end
})

AimAssist:CreateSlider({
	Name = "MaxAngle",
	Min = 1,
	Max = 360,
	Default = 90,
	Function = function(v)
		MaxAngle = v
	end
})

AimAssist:CreateSlider({
	Name = "Smooth",
	Min = 0.01,
	Max = 1,
	Default = 0.2,
	Function = function(v)
		Smooth = v
	end
})

AimAssist:CreateToggle({
	Name = "TeamCheck",
	Default = false,
	Function = function(v)
		TeamCheck = v
	end
})

AimAssist:CreateToggle({
	Name = "WallCheck",
	Default = false,
	Function = function(v)
		WallCheck = v
	end
})

end)

run(function()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local lplr = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Render = vape.Categories.Render

local KitESPEnabled = false
local PlayerESPEnabled = false
local ItemTimeESPEnabled = false
local ItemESPEnabled = false
local ShowDistance = true
local ShowHealth = true
local FontSize = 16
local TextOutline = true

local KitObjects = {}
local PlayerBoxes = {}

local PlayerAddedConnection
local PlayerRemovingConnection

local TAG = "OreCountdownESP"

local function createText(label, color, size)
	local t = Drawing.new("Text")
	t.Text = label
	t.Size = size or FontSize
	t.Center = true
	t.Outline = TextOutline
	t.OutlineColor = Color3.new(0, 0, 0)
	t.Color = color
	t.Visible = false 
	t.Font = Drawing.Fonts.Plex
	return t
end

local function addKit(obj, label)
	if KitObjects[obj] then return end
	local text = createText(label, Color3.fromRGB(255, 170, 0))
	text.Visible = false
	KitObjects[obj] = {
		drawing = text,
		baseLabel = label
	}
end

local function removeKit(obj)
	if KitObjects[obj] then
		KitObjects[obj].drawing:Remove()
		KitObjects[obj] = nil
	end
end

local function tagObject(obj)
	if obj:IsA("ProximityPrompt") and obj.Name == "hidden-metal-prompt" then
		CollectionService:AddTag(obj.Parent, "KitMetal")
	elseif obj.Name == "TreeOrb" then
		CollectionService:AddTag(obj, "KitTreeOrb")
	elseif obj:IsA("MeshPart") and obj.Name == "star_mesh.001" then
		local parent = obj.Parent
		if parent and parent.Name == "CritStar" then
			CollectionService:AddTag(obj, "KitCritStar")
		elseif parent and parent.Name == "VitalityStar" then
			CollectionService:AddTag(obj, "KitVitalityStar")
		end
	end
end

for _, obj in ipairs(workspace:GetDescendants()) do
	tagObject(obj)
end

workspace.DescendantAdded:Connect(tagObject)

local function addPlayer(player)
	if player == lplr then return end
	
	local nameText = createText(player.Name, Color3.fromRGB(255, 60, 60))
	local distText = createText("", Color3.fromRGB(255, 255, 255), FontSize - 2)
	
	local healthBar = Drawing.new("Line")
	healthBar.Thickness = 2
	healthBar.Visible = false 
	healthBar.Color = Color3.fromRGB(0, 255, 0)
	
	PlayerBoxes[player] = {
		nameText = nameText,
		distText = distText,
		healthBar = healthBar
	}
end

local function removePlayer(player)
	if PlayerBoxes[player] then
		PlayerBoxes[player].nameText:Remove()
		PlayerBoxes[player].distText:Remove()
		PlayerBoxes[player].healthBar:Remove()
		PlayerBoxes[player] = nil
	end
end


local function scanCountdowns()
	for _,v in ipairs(workspace:GetDescendants()) do
		if v.Name == "Countdown" and v:IsA("TextLabel") then
			if not CollectionService:HasTag(v, TAG) then
				CollectionService:AddTag(v, TAG)
			end
		end
	end
end

local function applyCountdownESP(text)
	local gui = text:FindFirstAncestorOfClass("BillboardGui")
	if not gui then return end
	
	gui.AlwaysOnTop = true
	gui.MaxDistance = math.huge
	gui.Size = UDim2.new(0,300,0,120)
	
	text.TextScaled = true
	text.TextTransparency = 0
	text.TextStrokeTransparency = 0
	text.TextColor3 = Color3.fromRGB(255,255,0)
end


local itemColors = {
	diamond = Color3.fromRGB(0, 255, 255),
	emerald = Color3.fromRGB(0, 255, 0),
	iron = Color3.fromRGB(200, 200, 200)
}

local function createItemESP(part)
	if not part:IsA("BasePart") then return end
	if part:FindFirstChild("ItemESP") then return end
	
	local name = string.lower(part.Name)
	local color = itemColors[name] or Color3.fromRGB(255,255,255)
	
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ItemESP"
	billboard.Adornee = part
	billboard.Size = UDim2.new(0,200,0,50)
	billboard.AlwaysOnTop = true
	billboard.StudsOffset = Vector3.new(0,2,0)
	
	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1,0,1,0)
	text.BackgroundTransparency = 1
	text.Text = part.Name
	text.TextScaled = true
	text.Font = Enum.Font.SourceSansBold
	text.TextColor3 = color
	text.TextStrokeTransparency = 0
	text.TextStrokeColor3 = Color3.new(0,0,0)
	text.Parent = billboard
	
	billboard.Parent = part
end

local function removeItemESP(part)
	local esp = part:FindFirstChild("ItemESP")
	if esp then
		esp:Destroy()
	end
end

RunService.RenderStepped:Connect(function()
	if KitESPEnabled then
		for obj, data in pairs(KitObjects) do
			if not obj or not obj.Parent then
				removeKit(obj)
				continue
			end

			local text = data.drawing
			local baseLabel = data.baseLabel

			local pos
			if obj:IsA("BasePart") then
				pos = obj.Position
			elseif obj:IsA("Model") and obj.PrimaryPart then
				pos = obj.PrimaryPart.Position
			end

			if pos then
				local screen, visible = camera:WorldToViewportPoint(pos)
				if visible and screen.Z > 0 then
					local distance = (camera.CFrame.Position - pos).Magnitude
					text.Text = string.format("%s [%.1fm]", baseLabel, distance)
					text.Position = Vector2.new(screen.X, screen.Y)
					text.Visible = true
				else
					text.Visible = false
				end
			else
				text.Visible = false
			end
		end
	else
		for _, data in pairs(KitObjects) do
			data.drawing.Visible = false
		end
	end

	if PlayerESPEnabled then
		for player, elements in pairs(PlayerBoxes) do
			local char = player.Character
			local head = char and char:FindFirstChild("Head")
			local humanoid = char and char:FindFirstChild("Humanoid")
			local rootPart = char and char:FindFirstChild("HumanoidRootPart")

			if head and humanoid and rootPart then
				local screen, visible = camera:WorldToViewportPoint(head.Position)
				
				if visible and screen.Z > 0 then
					local distance = (camera.CFrame.Position - rootPart.Position).Magnitude
					local health = humanoid.Health
					local maxHealth = humanoid.MaxHealth
					local healthPercent = health / maxHealth
					
					elements.nameText.Position = Vector2.new(screen.X, screen.Y - 20)
					elements.nameText.Visible = true
					
					if ShowDistance then
						elements.distText.Text = string.format("[%.1fm]", distance)
						elements.distText.Position = Vector2.new(screen.X, screen.Y - 5)
						elements.distText.Visible = true
					else
						elements.distText.Visible = false
					end
					
					if ShowHealth then
						local barWidth = 50
						local barStart = Vector2.new(screen.X - barWidth/2, screen.Y + 10)
						local barEnd = Vector2.new(screen.X - barWidth/2 + (barWidth * healthPercent), screen.Y + 10)
						
						elements.healthBar.From = barStart
						elements.healthBar.To = barEnd
						elements.healthBar.Color = Color3.fromRGB(
							255 * (1 - healthPercent),
							255 * healthPercent,
							0
						)
						elements.healthBar.Visible = true
					else
						elements.healthBar.Visible = false
					end
				else
					elements.nameText.Visible = false
					elements.distText.Visible = false
					elements.healthBar.Visible = false
				end
			else
				elements.nameText.Visible = false
				elements.distText.Visible = false
				elements.healthBar.Visible = false
			end
		end
	else
		for _, elements in pairs(PlayerBoxes) do
			elements.nameText.Visible = false
			elements.distText.Visible = false
			elements.healthBar.Visible = false
		end
	end
end)

local KitESP = Render:CreateModule({
	Name = "KitESP",
	Tooltip = "Metal / TreeOrb / Star ESP",
	Function = function(enabled)
		KitESPEnabled = enabled

		if enabled then
			for _, obj in ipairs(CollectionService:GetTagged("KitMetal")) do
				addKit(obj, "Metal")
			end
			for _, obj in ipairs(CollectionService:GetTagged("KitTreeOrb")) do
				addKit(obj, "TreeOrb")
			end
			for _, obj in ipairs(CollectionService:GetTagged("KitCritStar")) do
				addKit(obj, "CritStar")
			end
			for _, obj in ipairs(CollectionService:GetTagged("KitVitalityStar")) do
				addKit(obj, "VitalityStar")
			end
		else
			for _, data in pairs(KitObjects) do
				data.drawing.Visible = false
			end
		end
	end
})

local PlayerESP = Render:CreateModule({
	Name = "PlayerESP",
	Tooltip = "Player name ESP with health and distance",
	Function = function(enabled)
		PlayerESPEnabled = enabled
		
		if enabled then
			if not PlayerAddedConnection then
				PlayerAddedConnection = Players.PlayerAdded:Connect(addPlayer)
			end
			if not PlayerRemovingConnection then
				PlayerRemovingConnection = Players.PlayerRemoving:Connect(removePlayer)
			end
			
			for _, p in pairs(Players:GetPlayers()) do
				if not PlayerBoxes[p] then
					addPlayer(p)
				end
			end
		else
			for _, elements in pairs(PlayerBoxes) do
				elements.nameText.Visible = false
				elements.distText.Visible = false
				elements.healthBar.Visible = false
			end
		end
	end
})


local ItemTimeESP = Render:CreateModule({
	Name = "ItemTIME ESP",
	Tooltip = "Show ore countdown timers",
	Function = function(enabled)
		ItemTimeESPEnabled = enabled
		
		if enabled then
			scanCountdowns()
			for _,v in ipairs(CollectionService:GetTagged(TAG)) do
				applyCountdownESP(v)
			end
			
			CollectionService:GetInstanceAddedSignal(TAG):Connect(function(v)
				if ItemTimeESPEnabled then
					applyCountdownESP(v)
				end
			end)
			
			
			workspace.DescendantAdded:Connect(function(v)
				if ItemTimeESPEnabled and v.Name == "Countdown" and v:IsA("TextLabel") then
					if not CollectionService:HasTag(v, TAG) then
						CollectionService:AddTag(v, TAG)
					end
				end
			end)
		else
			
			for _,v in ipairs(CollectionService:GetTagged(TAG)) do
				local gui = v:FindFirstAncestorOfClass("BillboardGui")
				if gui then
					gui.AlwaysOnTop = false
					gui.MaxDistance = 100 
					gui.Size = UDim2.new(0,100,0,40)
				end
				
				v.TextTransparency = 0
				v.TextStrokeTransparency = 0.5
				v.TextColor3 = Color3.fromRGB(255,255,255)
			end
		end
	end
})


local ItemESP = Render:CreateModule({
	Name = "ItemESP",
	Tooltip = "Show dropped items (diamond, emerald, iron)",
	Function = function(enabled)
		ItemESPEnabled = enabled
		
		if enabled then
			local folder = workspace:FindFirstChild("ItemDrops")
			if folder then
				
				for _,v in ipairs(folder:GetChildren()) do
					createItemESP(v)
				end
				
				
				folder.ChildAdded:Connect(function(v)
					if ItemESPEnabled then
						createItemESP(v)
					end
				end)
			end
		else
			
			local folder = workspace:FindFirstChild("ItemDrops")
			if folder then
				for _,v in ipairs(folder:GetChildren()) do
					removeItemESP(v)
				end
			end
		end
	end
})

PlayerESP:CreateToggle({
	Name = "Show Distance",
	Default = true,
	Function = function(v)
		ShowDistance = v
	end
})

PlayerESP:CreateToggle({
	Name = "Show Health",
	Default = true,
	Function = function(v)
		ShowHealth = v
	end
})

PlayerESP:CreateToggle({
	Name = "Text Outline",
	Default = true,
	Function = function(v)
		TextOutline = v
		for _, elements in pairs(PlayerBoxes) do
			elements.nameText.Outline = v
			elements.distText.Outline = v
		end
		for _, data in pairs(KitObjects) do
			data.drawing.Outline = v
		end
	end
})

PlayerESP:CreateSlider({
	Name = "Font Size",
	Min = 10,
	Max = 24,
	Default = 16,
	Function = function(v)
		FontSize = v
		for _, elements in pairs(PlayerBoxes) do
			elements.nameText.Size = v
			elements.distText.Size = v - 2
		end
		for _, data in pairs(KitObjects) do
			data.drawing.Size = v
		end
	end
})

end)

run(function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local lplr = Players.LocalPlayer
    local Blatant = vape.Categories.Blatant
    
    
    local Enabled = false
    local DamageAccuracy = 0
    local tracked = 0
    local extraGravity = 0
    
    
    local rayParams = RaycastParams.new()
    rayParams.RespectCanCollide = true
    
   
    local rand = Random.new()
    
    local Connection
    
    local NoFall
    NoFall = Blatant:CreateModule({
        Name = "NoFall",
        Tooltip = "Prevents fall damage using velocity manipulation",
        Function = function(enabled)
            Enabled = enabled
            
            if enabled then
                Connection = RunService.PreSimulation:Connect(function(dt)
                    if not Enabled then return end
                    
                    local character = lplr.Character
                    if not character then return end
                    
                    local rootPart = character:FindFirstChild("HumanoidRootPart")
                    local humanoid = character:FindFirstChild("Humanoid")
                    
                    if not rootPart or not humanoid then return end
                    
                    
                    if rootPart.AssemblyLinearVelocity.Y < -85 then
                        
                        rayParams.FilterDescendantsInstances = {character, workspace.CurrentCamera}
                        rayParams.CollisionGroup = rootPart.CollisionGroup
                        
                        
                        local rootSize = rootPart.Size.Y / 2.5 + (humanoid.HipHeight or 2)
                        
                        
                        local ray = workspace:Blockcast(
                            rootPart.CFrame, 
                            Vector3.new(3, 3, 3), 
                            Vector3.new(0, (tracked * 0.1) - rootSize, 0), 
                            rayParams
                        )
                        
                        if not ray then
                           
                            local Failed = rand:NextNumber(0, 100) < DamageAccuracy
                            local velo = rootPart.AssemblyLinearVelocity.Y
                            
                            if Failed then 
                                
                                rootPart.AssemblyLinearVelocity = Vector3.new(
                                    rootPart.AssemblyLinearVelocity.X, 
                                    velo + 0.5, 
                                    rootPart.AssemblyLinearVelocity.Z
                                )
                            else
                               
                                rootPart.AssemblyLinearVelocity = Vector3.new(
                                    rootPart.AssemblyLinearVelocity.X, 
                                    -86, 
                                    rootPart.AssemblyLinearVelocity.Z
                                )
                            end
                            
                           
                            rootPart.CFrame = rootPart.CFrame + Vector3.new(
                                0, 
                                (Failed and -extraGravity or extraGravity) * dt, 
                                0
                            )
                            
                           
                            extraGravity = extraGravity + (Failed and workspace.Gravity or -workspace.Gravity) * dt
                        end
                    else
                        
                        extraGravity = 0
                    end
                end)
            else
                
                if Connection then
                    Connection:Disconnect()
                    Connection = nil
                end
                extraGravity = 0
                tracked = 0
            end
        end
    })
    
    NoFall:CreateSlider({
        Name = "Damage Accuracy",
        Min = 0,
        Max = 100,
        Default = 0,
        Decimal = 5,
        Suffix = "%",
        Tooltip = "Chance to take damage (0% = no damage, 100% = always damage)",
        Function = function(v)
            DamageAccuracy = v
        end
    })
end)

run(function()

local Blatant = vape.Categories.Blatant
local HttpService = game:GetService("HttpService")

local FFlagEditor = Blatant:CreateModule({
	Name = "FFLAGEDITOR",
	Tooltip = "Set Roblox FFlags using JSON",
	Function = function(callback)

		if callback then

			local success, data = pcall(function()
				return HttpService:JSONDecode(FFlagEditor.JsonInput)
			end)

			if success and type(data) == "table" then

				for flag, value in pairs(data) do
					pcall(function()

						local v = value

						if typeof(value) == "boolean" then
							v = value and "True" or "False"

						elseif typeof(value) == "number" then
							v = tostring(value)

						elseif typeof(value) == "string" then
							v = value
						end

						setfflag(flag, v)

						print("Set FFlag:", flag, v)

					end)
				end

				print("FFlags applied successfully")

			else
				warn("Invalid JSON input")
			end

		end

	end
})

FFlagEditor.JsonInput = "{}"

FFlagEditor:CreateTextBox({
	Name = "JSON",
	Default = "{}",
	Function = function(v)
		FFlagEditor.JsonInput = v
	end
})

end)

run(function()

local Blatant = vape.Categories.Blatant

local DefaultPhysicsRate = 15 

local Desync
Desync = Blatant:CreateModule({
	Name = "Desync",
	Tooltip = "Change physics sender rate for desync",
	Function = function(enabled)
		
		if enabled then
			
			pcall(function()
				setfflag("DFIntS2PhysicsSenderRate", "38000")
			end)
		else
			
			pcall(function()
				setfflag("DFIntS2PhysicsSenderRate", tostring(DefaultPhysicsRate))
			end)
		end
		
	end
})

end)

run(function()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local lplr = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Render = vape.Categories.Render

local PlayerInventoryESPEnabled = false
local FontSize = 14
local ShowCount = true

local InventoryTexts = {}

local function createInventoryText()
	local t = Drawing.new("Text")
	t.Size = FontSize
	t.Center = false
	t.Outline = true
	t.OutlineColor = Color3.new(0, 0, 0)
	t.Color = Color3.fromRGB(255, 255, 255)
	t.Visible = false
	t.Font = Drawing.Fonts.Plex
	return t
end

local function getInventoryItems(player)
	local inventories = ReplicatedStorage:FindFirstChild("Inventories")
	if not inventories then return {} end
	
	local playerInv = inventories:FindFirstChild(player.Name)
	if not playerInv then return {} end
	
	local items = {}
	for _, item in ipairs(playerInv:GetChildren()) do
		table.insert(items, item.Name)
	end
	
	return items
end

RunService.RenderStepped:Connect(function()
	if PlayerInventoryESPEnabled then
		for _, player in ipairs(Players:GetPlayers()) do
			if player == lplr then continue end
			
			local char = player.Character
			local head = char and char:FindFirstChild("Head")
			
			if head then
				local screen, visible = camera:WorldToViewportPoint(head.Position)
				
				if visible and screen.Z > 0 then
					if not InventoryTexts[player] then
						InventoryTexts[player] = createInventoryText()
					end
					
					local items = getInventoryItems(player)
					local invText = ""
					
					if #items > 0 then
						invText = table.concat(items, ", ")
					else
						invText = "Empty"
					end
					
					InventoryTexts[player].Text = invText
					InventoryTexts[player].Position = Vector2.new(screen.X + 10, screen.Y + 30)
					InventoryTexts[player].Visible = true
				else
					if InventoryTexts[player] then
						InventoryTexts[player].Visible = false
					end
				end
			else
				if InventoryTexts[player] then
					InventoryTexts[player].Visible = false
				end
			end
		end
	else
		for _, text in pairs(InventoryTexts) do
			text.Visible = false
		end
	end
end)

local PlayerInventoryESP = Render:CreateModule({
	Name = "PlayerInventoryESP",
	Tooltip = "Show other players' inventory items",
	Function = function(enabled)
		PlayerInventoryESPEnabled = enabled
		
		if not enabled then
			for _, text in pairs(InventoryTexts) do
				text.Visible = false
			end
		end
	end
})

PlayerInventoryESP:CreateSlider({
	Name = "Font Size",
	Min = 10,
	Max = 24,
	Default = 14,
	Function = function(v)
		FontSize = v
		for _, text in pairs(InventoryTexts) do
			text.Size = v
		end
	end
})

end)

run(function()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local lplr = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Render = vape.Categories.Render

local ResourceESPEnabled = false
local FontSize = 14

local ResourceTexts = {}

local resourceColors = {
	diamond = Color3.fromRGB(0, 255, 255),
	emerald = Color3.fromRGB(0, 255, 0),
	iron = Color3.fromRGB(200, 200, 200)
}

local function createResourceText(color)
	local t = Drawing.new("Text")
	t.Size = FontSize
	t.Center = false
	t.Outline = true
	t.OutlineColor = Color3.new(0, 0, 0)
	t.Color = color
	t.Visible = false
	t.Font = Drawing.Fonts.Plex
	return t
end

local function getResourceAmounts(player)
	local inventories = ReplicatedStorage:FindFirstChild("Inventories")
	if not inventories then return {} end
	
	local playerInv = inventories:FindFirstChild(player.Name)
	if not playerInv then return {} end
	
	local resources = {}
	
	for resourceName, _ in pairs(resourceColors) do
		local item = playerInv:FindFirstChild(resourceName)
		if item then
			local amount = item:GetAttribute("Amount")
			if amount and amount > 0 then
				resources[resourceName] = amount
			end
		end
	end
	
	return resources
end

RunService.RenderStepped:Connect(function()
	if ResourceESPEnabled then
		for _, player in ipairs(Players:GetPlayers()) do
			if player == lplr then continue end
			
			local char = player.Character
			local head = char and char:FindFirstChild("Head")
			
			if head then
				local screen, visible = camera:WorldToViewportPoint(head.Position)
				
				if visible and screen.Z > 0 then
					if not ResourceTexts[player] then
						ResourceTexts[player] = {}
					end
					
					local resources = getResourceAmounts(player)
					local yOffset = 50
					
					
					for resourceName, color in pairs(resourceColors) do
						if not ResourceTexts[player][resourceName] then
							ResourceTexts[player][resourceName] = createResourceText(color)
						end
						
						local amount = resources[resourceName]
						if amount then
							ResourceTexts[player][resourceName].Text = string.format("%s: %d", resourceName, amount)
							ResourceTexts[player][resourceName].Position = Vector2.new(screen.X + 10, screen.Y + yOffset)
							ResourceTexts[player][resourceName].Visible = true
							yOffset = yOffset + 15
						else
							ResourceTexts[player][resourceName].Visible = false
						end
					end
				else
					if ResourceTexts[player] then
						for _, text in pairs(ResourceTexts[player]) do
							text.Visible = false
						end
					end
				end
			else
				if ResourceTexts[player] then
					for _, text in pairs(ResourceTexts[player]) do
						text.Visible = false
					end
				end
			end
		end
	else
		for _, playerTexts in pairs(ResourceTexts) do
			for _, text in pairs(playerTexts) do
				text.Visible = false
			end
		end
	end
end)

local ResourceESP = Render:CreateModule({
	Name = "ResourceESP",
	Tooltip = "Show other players' resource amounts (diamond, emerald, iron)",
	Function = function(enabled)
		ResourceESPEnabled = enabled
		
		if not enabled then
			for _, playerTexts in pairs(ResourceTexts) do
				for _, text in pairs(playerTexts) do
					text.Visible = false
				end
			end
		end
	end
})

ResourceESP:CreateSlider({
	Name = "Font Size",
	Min = 10,
	Max = 24,
	Default = 14,
	Function = function(v)
		FontSize = v
		for _, playerTexts in pairs(ResourceTexts) do
			for _, text in pairs(playerTexts) do
				text.Size = v
			end
		end
	end
})

end)

saferun(function()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local lplr = Players.LocalPlayer

local Blatant = vape.Categories.Blatant

local AutoWhisperEnabled = false
local AlwaysHeal = false
local FlyOnlyVoid = false
local TargetUsername = ""
local VoidDepth = 5

local lastHeal = 0
local healCooldown = 1
local previousHealth = {}

local playerDropdown

local function useOwlHeal()
	pcall(function()
		local events = ReplicatedStorage:FindFirstChild("events-@easy-games/game-core:shared/game-core-networking@getEvents.Events")
		if events then
			local useAbility = events:FindFirstChild("useAbility")
			if useAbility then
				useAbility:FireServer("OWL_HEAL")
			end
		end
	end)
end

local function useOwlLift()
	pcall(function()
		local events = ReplicatedStorage:FindFirstChild("events-@easy-games/game-core:shared/game-core-networking@getEvents.Events")
		if events then
			local useAbility = events:FindFirstChild("useAbility")
			if useAbility then
				useAbility:FireServer("OWL_LIFT")
			end
		end
	end)
end

local function isInVoid(character, depth)
	if not character then return false end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return false end
	
	local success, result = pcall(function()
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Blacklist
		rayParams.FilterDescendantsInstances = {character}
		
		local rayDistance = depth * 10
		
		return workspace:Raycast(
			rootPart.Position,
			Vector3.new(0, -rayDistance, 0),
			rayParams
		)
	end)
	
	if not success then return false end
	
	return result == nil
end

local function getPlayerList()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= lplr then
			table.insert(list, player.Name)
		end
	end
	return list
end

local function updatePlayerList()
	if playerDropdown then
		local newList = getPlayerList()
		playerDropdown:SetList(newList)
	end
end

local AutoWhisper = Blatant:CreateModule({
	Name = "AutoWhisper",
	Tooltip = "Auto heal/lift target player",
	Function = function(enabled)
		AutoWhisperEnabled = enabled
		
		if enabled then
			task.spawn(function()
				while AutoWhisperEnabled do
					pcall(function()
						if TargetUsername == "" or TargetUsername == nil then
							task.wait(0.5)
							return
						end
						
						local targetPlayer = Players:FindFirstChild(TargetUsername)
						
						if not targetPlayer then
							task.wait(0.5)
							return
						end
						
						local char = targetPlayer.Character
						if not char then
							task.wait(0.5)
							return
						end
						
						local humanoid = char:FindFirstChild("Humanoid")
						
						
						if AlwaysHeal then
							if tick() - lastHeal >= healCooldown then
								useOwlHeal()
								lastHeal = tick()
							end
						else
							
							if humanoid then
								if not previousHealth[targetPlayer] then
									previousHealth[targetPlayer] = humanoid.Health
								end
								
								local currentHealth = humanoid.Health
								
								if currentHealth < previousHealth[targetPlayer] then
									if tick() - lastHeal >= healCooldown then
										useOwlHeal()
										lastHeal = tick()
									end
								end
								
								previousHealth[targetPlayer] = currentHealth
							end
						end
						
						
						if FlyOnlyVoid then
							if isInVoid(char, VoidDepth) then
								useOwlLift()
							end
						end
					end)
					
					task.wait(0.1)
				end
			end)
		else
			previousHealth = {}
		end
	end
})

AutoWhisper:CreateToggle({
	Name = "AlwaysHeal",
	Default = false,
	Function = function(v)
		AlwaysHeal = v
	end
})

AutoWhisper:CreateToggle({
	Name = "FlyOnlyVoid",
	Default = false,
	Function = function(v)
		FlyOnlyVoid = v
	end
})


playerDropdown = AutoWhisper:CreateDropdown({
	Name = "Target Player",
	List = getPlayerList(),
	Function = function(value)
		TargetUsername = value
	end,
	Tooltip = "Select player to help"
})


AutoWhisper:CreateButton({
	Name = "Refresh Players",
	Function = function()
		updatePlayerList()
	end,
	Tooltip = "Update player list"
})

AutoWhisper:CreateSlider({
	Name = "Void Depth",
	Min = 1,
	Max = 10,
	Default = 5,
	Function = function(v)
		VoidDepth = v
	end
})


Players.PlayerAdded:Connect(updatePlayerList)
Players.PlayerRemoving:Connect(updatePlayerList)

end)

run(function()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local lplr = Players.LocalPlayer

local Blatant = vape.Categories.Blatant


local AutoBuyEnabled = false
local Cooldown = 1
local lastPurchaseTime = {}

local function hasItem(itemName)
	local success, result = pcall(function()
		local character = lplr.Character
		if not character then return false end
		
		local inventoryFolder = workspace:FindFirstChild(lplr.Name)
		if not inventoryFolder then return false end
		
		local invValue = inventoryFolder:FindFirstChild("InventoryFolder")
		if not invValue or not invValue.Value then return false end
		
		return invValue.Value:FindFirstChild(itemName) ~= nil
	end)
	
	return success and result or false
end

local function canBuy(itemName)
	local currentTime = tick()
	local lastTime = lastPurchaseTime[itemName] or 0
	return (currentTime - lastTime) >= Cooldown
end

local function buyItem(itemType, price, currency, shopId)
	if not canBuy(itemType) then
		return false
	end
	
	local success = pcall(function()
		local args = {
			[1] = {
				shopItem = {
					itemType = itemType,
					price = price,
					currency = currency,
					amount = 1,
					lockAfterPurchase = true
				},
				shopId = shopId or "1_item_shop"
			}
		}
		
		local bedwarsPurchase = ReplicatedStorage
			:WaitForChild("rbxts_include", 1)
			:WaitForChild("node_modules", 1)
			:WaitForChild("@rbxts", 1)
			:WaitForChild("net", 1)
			:WaitForChild("out", 1)
			:WaitForChild("_NetManaged", 1)
			:WaitForChild("BedwarsPurchaseItem", 1)
		
		if bedwarsPurchase then
			bedwarsPurchase:InvokeServer(unpack(args))
			lastPurchaseTime[itemType] = tick()
		end
	end)
	
	return success
end

local AutoBuy = Blatant:CreateModule({
	Name = "AutoBuy",
	Tooltip = "Automatically buy weapons and armor",
	Function = function(enabled)
		AutoBuyEnabled = enabled
		
		if enabled then
			task.spawn(function()
				while AutoBuyEnabled do
					pcall(function()
						
						if hasItem("wood_sword") and not hasItem("stone_sword") then
							buyItem("stone_sword", 70, "iron")
						end
						
						
						if hasItem("stone_sword") and not hasItem("iron_sword") then
							buyItem("iron_sword", 70, "iron")
						end
						
						
						if hasItem("iron_sword") and not hasItem("diamond_sword") then
							buyItem("diamond_sword", 70, "emerald")
						end
						
						
						if (hasItem("stone_sword") or hasItem("wood_scythe")) and 
						   not hasItem("iron_chestplate") and 
						   not hasItem("diamond_chestplate") and
						   not hasItem("leather_chestplate") then
							buyItem("leather_chestplate", 50, "iron")
						end
						
						
						if hasItem("leather_chestplate") and not hasItem("iron_chestplate") then
							buyItem("iron_chestplate", 120, "iron")
						end
						
						
						if hasItem("iron_chestplate") and not hasItem("diamond_chestplate") then
							buyItem("diamond_chestplate", 8, "emerald")
						end
					end)
					
					task.wait(0.1)
				end
			end)
		else
			lastPurchaseTime = {}
		end
	end
})

AutoBuy:CreateSlider({
	Name = "Cooldown",
	Min = 0.5,
	Max = 10,
	Default = 1,
	Function = function(v)
		Cooldown = v
	end,
	Tooltip = "Seconds to wait between purchases"
})


local StaffDetectorEnabled = false
local NotifyFriends = false
local NotifyNewPlayers = false
local Blacklist = {}

local keywords = {
	"mod",
	"dev", 
	"owner",
	"famous",
	"admin",
	"staff",
	"moderator"
}

local detectedStaff = {}
local notifiedPlayers = {}

local function playWarningSound()
	pcall(function()
		local sound = Instance.new("Sound")
		sound.Parent = workspace
		sound.SoundId = "rbxassetid://7383525713"
		sound.Volume = 2
		sound:Play()
		
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
	end)
end

local function sendNotification(title, text, duration)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = title,
			Text = text,
			Duration = duration or 10
		})
	end)
end

local function isBlacklisted(playerName)
	for _, name in ipairs(Blacklist) do
		if string.lower(name) == string.lower(playerName) then
			return true
		end
	end
	return false
end

local function checkPlayerTags(player)
	if not StaffDetectorEnabled then return end
	if player == lplr then return end
	if detectedStaff[player.Name] then return end
	
	pcall(function()
		local tags = player:FindFirstChild("Tags")
		if tags and tags:IsA("Folder") then
			for _, tagValue in ipairs(tags:GetChildren()) do
				if tagValue:IsA("StringValue") and tagValue.Value then
					
					for _, keyword in ipairs(keywords) do
						if string.find(string.lower(tagValue.Value), string.lower(keyword)) then
							
							detectedStaff[player.Name] = true
							
							print(string.format("⚠️ STAFF DETECTED: %s (Tag: %s)", player.Name, tagValue.Value))
							
							playWarningSound()
							
							sendNotification(
								"⚠️ Staff Detector",
								string.format("%s joined! (Tag: %s)", player.Name, keyword),
								10
							)
							
							return
						end
					end
				end
			end
		end
	end)
end

local function checkBlacklist(player)
	if not StaffDetectorEnabled then return end
	if player == lplr then return end
	
	pcall(function()
		if isBlacklisted(player.Name) then
			print(string.format("🚫 BLACKLISTED PLAYER: %s", player.Name))
			
			playWarningSound()
			
			sendNotification(
				"🚫 Blacklist Alert",
				string.format("%s (Blacklisted) joined!", player.Name),
				10
			)
		end
	end)
end

local function checkFriend(player)
	if not StaffDetectorEnabled or not NotifyFriends then return end
	if player == lplr then return end
	
	pcall(function()
		if lplr:IsFriendsWith(player.UserId) then
			print(string.format("👋 FRIEND JOINED: %s", player.Name))
			
			sendNotification(
				"👋 Friend Joined",
				string.format("%s is in your game!", player.Name),
				5
			)
		end
	end)
end

local playerAddedConnection
local checkLoop

local StaffDetector = Blatant:CreateModule({
	Name = "StaffDetector",
	Tooltip = "Detect staff, blacklisted players, and friends",
	Function = function(enabled)
		StaffDetectorEnabled = enabled
		
		if enabled then
			
			playerAddedConnection = Players.PlayerAdded:Connect(function(player)
				pcall(function()
					if NotifyNewPlayers and player ~= lplr then
						sendNotification(
							"📢 Player Joined",
							string.format("%s joined the game", player.Name),
							3
						)
					end
					
					task.wait(1) 
					checkPlayerTags(player)
					checkBlacklist(player)
					checkFriend(player)
				end)
			end)
			
			
			checkLoop = task.spawn(function()
				while StaffDetectorEnabled do
					pcall(function()
						for _, player in ipairs(Players:GetPlayers()) do
							if player ~= lplr then
								checkPlayerTags(player)
								checkBlacklist(player)
							end
						end
					end)
					
					task.wait(0.5)
				end
			end)
			
			
			pcall(function()
				for _, player in ipairs(Players:GetPlayers()) do
					if player ~= lplr then
						task.wait(0.1)
						checkPlayerTags(player)
						checkBlacklist(player)
						checkFriend(player)
					end
				end
			end)
		else
			if playerAddedConnection then
				playerAddedConnection:Disconnect()
				playerAddedConnection = nil
			end
			
			if checkLoop then
				task.cancel(checkLoop)
				checkLoop = nil
			end
			
			detectedStaff = {}
			notifiedPlayers = {}
		end
	end
})

StaffDetector:CreateToggle({
	Name = "Notify Friends",
	Default = false,
	Function = function(v)
		NotifyFriends = v
	end,
	Tooltip = "Get notified when friends join"
})

StaffDetector:CreateToggle({
	Name = "Notify New Players",
	Default = false,
	Function = function(v)
		NotifyNewPlayers = v
	end,
	Tooltip = "Get notified when any player joins"
})


StaffDetector:CreateButton({
	Name = "Add to Blacklist",
	Function = function()
		pcall(function()
			
			local username = "PlayerName" 
			table.insert(Blacklist, username)
			print("Added to blacklist: " .. username)
		end)
	end,
	Tooltip = "Add player to blacklist (edit code)"
})

StaffDetector:CreateButton({
	Name = "Clear Blacklist",
	Function = function()
		Blacklist = {}
		print("Blacklist cleared")
	end,
	Tooltip = "Clear all blacklisted players"
})

end)
