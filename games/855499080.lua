--[[
    SkywarsProjAim (Fixed & Optimized + Mouse FOV + WallCheck + Target Part)
]]
local run = function(func)
	func()
end
local cloneref = cloneref or function(obj)
	return obj
end
local vapeEvents = setmetatable({}, {
	__index = function(self, index)
		self[index] = Instance.new('BindableEvent')
		return self[index]
	end
})

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local httpService = cloneref(game:GetService('HttpService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local collectionService = cloneref(game:GetService('CollectionService'))
local contextActionService = cloneref(game:GetService('ContextActionService'))
local guiService = cloneref(game:GetService('GuiService'))
local coreGui = cloneref(game:GetService('CoreGui'))
local starterGui = cloneref(game:GetService('StarterGui'))
local lightingService = cloneref(game:GetService('Lighting'))
local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer

local vape = shared.vape
local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo
local uipallet = vape.Libraries.uipallet
local tween = vape.Libraries.tween
local color = vape.Libraries.color
local whitelist = vape.Libraries.whitelist
local prediction = vape.Libraries.prediction

local function notif(...)
	return vape:CreateNotification(...)
end

local function getRaycastFilterType()
	local ok, value = pcall(function()
		return Enum.RaycastFilterType.Exclude
	end)

	if ok then
		return value
	end

	ok, value = pcall(function()
		return Enum.RaycastFilterType.Blacklist
	end)

	if ok then
		return value
	end

	return nil
end

local function buildWallCheckParams()
	local params = RaycastParams.new()

	local filterType = getRaycastFilterType()
	if filterType then
		params.FilterType = filterType
	end

	-- プレイヤーキャラは全部除外して、壁だけ判定しやすくする
	local filter = {}
	for _, player in ipairs(playersService:GetPlayers()) do
		if player.Character then
			table.insert(filter, player.Character)
		end
	end

	params.FilterDescendantsInstances = filter
	params.IgnoreWater = true

	pcall(function()
		params.RespectCanCollide = false
	end)

	return params
end

local function isPositionVisible(originPosition, targetPosition, params)
	local direction = targetPosition - originPosition
	local distance = direction.Magnitude

	if distance < 0.001 then
		return true
	end

	local ok, result = pcall(function()
		return workspace:Raycast(originPosition, direction, params)
	end)

	if not ok then
		return true
	end

	-- 何も当たらなければ見える扱い
	if not result then
		return true
	end

	-- 目標より手前に何かが当たっているなら壁越し扱い
	return result.Distance >= distance - 0.5
end

local function getTargetPartFromCharacter(character, partName)
	if not character then
		return nil
	end

	if partName == 'HumanoidRootPart' then
		return character:FindFirstChild('HumanoidRootPart') or character:FindFirstChild('Head')
	elseif partName == 'Torso' then
		return character:FindFirstChild('UpperTorso')
			or character:FindFirstChild('Torso')
			or character:FindFirstChild('LowerTorso')
			or character:FindFirstChild('HumanoidRootPart')
			or character:FindFirstChild('Head')
	elseif partName == 'Random' then
		local parts = {}

		local head = character:FindFirstChild('Head')
		local hrp = character:FindFirstChild('HumanoidRootPart')
		local torso = character:FindFirstChild('UpperTorso')
			or character:FindFirstChild('Torso')
			or character:FindFirstChild('LowerTorso')

		if head then
			table.insert(parts, head)
		end
		if hrp then
			table.insert(parts, hrp)
		end
		if torso then
			table.insert(parts, torso)
		end

		if #parts > 0 then
			return parts[math.random(1, #parts)]
		end

		return character:FindFirstChild('Head')
	else
		-- Default: Head
		return character:FindFirstChild('Head') or character:FindFirstChild('HumanoidRootPart')
	end
end

-- 最適なターゲット部位を取得
-- Mouseモード: 画面カーソル基準でFOV内から選ぶ
-- Positionモード: 3D距離で選ぶ
local function getBestTargetPart(options)
	options = options or {}

	if not lplr then
		return nil
	end

	local character = lplr.Character
	if not character then
		return nil
	end

	local myRoot = character:FindFirstChild("HumanoidRootPart")
	if not myRoot then
		return nil
	end

	local camera = workspace.CurrentCamera
	local mouseLocation = inputService:GetMouseLocation()

	local wallParams = nil
	local originPosition = nil

	if options.WallCheck then
		if options.WallCheckOrigin == 'Camera' and camera then
			originPosition = camera.CFrame.Position
		else
			local originPart = character:FindFirstChild("Head") or myRoot
			originPosition = originPart.Position
		end

		wallParams = buildWallCheckParams()
	end

	local bestPart = nil
	local bestScore = math.huge

	for _, player in ipairs(playersService:GetPlayers()) do
		if player ~= lplr and player.Character then
			local enemyChar = player.Character
			local enemyHumanoid = enemyChar:FindFirstChildOfClass("Humanoid")

			if enemyHumanoid and enemyHumanoid.Health > 0 then
				local targetPart = getTargetPartFromCharacter(enemyChar, options.TargetPart or 'Head')

				if targetPart then
					local position = targetPart.Position
					local distance = (myRoot.Position - position).Magnitude

					-- Range制限
					if not options.Range or options.Range <= 0 or distance <= options.Range then
						if options.Mode == 'Mouse' then
							if camera then
								local screenPos = camera:WorldToViewportPoint(position)

								if screenPos and screenPos.Z > 0 then
									local screenDistance = (Vector2.new(screenPos.X, screenPos.Y) - mouseLocation).Magnitude
									local fov = options.FOV or math.huge

									-- まずFOV内かで絞って、その後WallCheckする
									if screenDistance <= fov and screenDistance < bestScore then
										local passesWallCheck = true

										if options.WallCheck and wallParams and originPosition then
											passesWallCheck = isPositionVisible(originPosition, position, wallParams)
										end

										if passesWallCheck then
											bestScore = screenDistance
											bestPart = targetPart
										end
									end
								end
							end
						else
							-- Positionモードは近い順
							if distance < bestScore then
								local passesWallCheck = true

								if options.WallCheck and wallParams and originPosition then
									passesWallCheck = isPositionVisible(originPosition, position, wallParams)
								end

								if passesWallCheck then
									bestScore = distance
									bestPart = targetPart
								end
							end
						end
					end
				end
			end
		end
	end

	return bestPart
end

run(function()
	local SkywarsProjAim
	local Targets
	local Mode
	local Range
	local FOV
	local TargetPart
	local WallCheck
	local WallCheckOrigin
	local CircleColor
	local CircleTransparency
	local CircleFilled
	local CircleObject
	local ShowTarget
	local DebugMode
	local debugMode = false

	local function dbg(msg)
		if debugMode then
			print('[SkywarsProjAim] ' .. tostring(msg))
		end
	end

	local function updateCircleForMode()
		if not SkywarsProjAim or not Mode then
			return
		end

		if CircleObject then
			pcall(function()
				CircleObject.Visible = SkywarsProjAim.Enabled and Mode.Value == 'Mouse'

				if Mode.Value == 'Mouse' and FOV then
					CircleObject.Radius = FOV.Value
				end
			end)
		end
	end

	SkywarsProjAim = vape.Categories.Combat:CreateModule({
		Name = 'SkywarsProjAim',
		Function = function(callback)
			updateCircleForMode()

			if callback then
				debugMode = DebugMode and DebugMode.Enabled or false
				dbg('Module ENABLED')

				-- フックおよび動作スレッド
				SkywarsProjAim:Clean(task.spawn(function()
					while SkywarsProjAim.Enabled do
						local character = lplr.Character
						if character then
							local tool = character:FindFirstChild("Bow") or character:FindFirstChildOfClass("Tool")
							if tool then
								local clientControl = tool:FindFirstChild("ClientControl")
								if clientControl and clientControl:IsA("RemoteFunction") then
									local hookedFunction

									hookedFunction = function(...)
										if not SkywarsProjAim.Enabled then
											return Vector3.new(0, 0, 0)
										end

										dbg('OnClientInvoke triggered!')

										local targetPart = getBestTargetPart({
											Mode = Mode and Mode.Value or 'Mouse',
											Range = Range and Range.Value or 0,
											FOV = FOV and FOV.Value or math.huge,
											TargetPart = TargetPart and TargetPart.Value or 'Head',
											WallCheck = WallCheck and WallCheck.Enabled or false,
											WallCheckOrigin = WallCheckOrigin and WallCheckOrigin.Value or 'Character',
										})

										if targetPart then
											dbg(
												'Target locked: '
												.. tostring(targetPart.Parent and targetPart.Parent.Name)
												.. ' / Part: '
												.. tostring(targetPart.Name)
												.. ' at '
												.. tostring(targetPart.Position)
											)
											return targetPart.Position
										end

										return Vector3.new(0, 0, 0)
									end

									-- OnClientInvokeを直接上書き
									clientControl.OnClientInvoke = hookedFunction
									dbg('ClientControl successfully hooked for tool: ' .. tool.Name)

									if debugMode then
										notif('SkywarsProjAim', 'Hooked Bow: ' .. tool.Name, 3)
									end

									-- 他スクリプトに上書きされたら再度フック
									while SkywarsProjAim.Enabled and tool.Parent == character do
										pcall(function()
											if clientControl.OnClientInvoke ~= hookedFunction then
												clientControl.OnClientInvoke = hookedFunction
											end
										end)
										task.wait(0.25)
									end
								end
							end
						end
						task.wait(0.5)
					end
				end))

				-- FOV Circle更新ループ
				SkywarsProjAim:Clean(runService.RenderStepped:Connect(function()
					if CircleObject then
						pcall(function()
							CircleObject.Position = inputService:GetMouseLocation()
						end)
					end
				end))
			else
				dbg('Module DISABLED')
				debugMode = false
			end
		end,
		ExtraText = function()
			local modeText = Mode and Mode.Value or ''
			local partText = TargetPart and TargetPart.Value or ''

			local text = modeText
			if partText ~= '' then
				text = text .. ' / ' .. partText
			end

			if WallCheck and WallCheck.Enabled then
				text = text .. ' / Wall'
			end

			return text
		end,
		Tooltip = 'Automatically aims projectiles by hooking ClientControl.OnClientInvoke directly. Mouse mode uses FOV, optional WallCheck and target part.'
	})

	Targets = SkywarsProjAim:CreateTargets({Players = true})

	Mode = SkywarsProjAim:CreateDropdown({
		Name = 'Mode',
		List = {'Mouse', 'Position'},
		Function = function(val)
			local isMouse = val == 'Mouse'

			if FOV and FOV.Object then
				pcall(function()
					FOV.Object.Visible = isMouse
				end)
			end

			updateCircleForMode()
		end
	})

	Range = SkywarsProjAim:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 500,
		Default = 150,
		Function = function(val)
			-- Rangeは3D距離制限として使用
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Tooltip = 'Maximum 3D distance for target selection.'
	})

	FOV = SkywarsProjAim:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 150,
		Function = function(val)
			if CircleObject and Mode and Mode.Value == 'Mouse' then
				pcall(function()
					CircleObject.Radius = val
				end)
			end
		end,
		Suffix = function(val)
			return 'px'
		end,
		Tooltip = 'Mouse mode only: only targets inside this screen FOV circle are selected.',
		Visible = Mode.Value == 'Mouse'
	})

	TargetPart = SkywarsProjAim:CreateDropdown({
		Name = 'Target Part',
		List = {'Head', 'HumanoidRootPart', 'Torso', 'Random'},
		Function = function(val)
			-- 次回のOnClientInvokeから反映される
		end,
		Tooltip = 'Part to aim at. Torso supports UpperTorso / Torso / LowerTorso.'
	})

	WallCheck = SkywarsProjAim:CreateToggle({
		Name = 'Wall Check',
		Function = function(callback)
			if WallCheckOrigin and WallCheckOrigin.Object then
				pcall(function()
					WallCheckOrigin.Object.Visible = callback
				end)
			end
		end,
		Tooltip = 'Only aim at targets visible by raycast.'
	})

	WallCheckOrigin = SkywarsProjAim:CreateDropdown({
		Name = 'Wall Check Origin',
		List = {'Character', 'Camera'},
		Function = function(val)
			-- 次回のOnClientInvokeから反映される
		end,
		Tooltip = 'Raycast origin for wall check. Camera can be less strict, Character is more stable.',
		Visible = false
	})

	ShowTarget = SkywarsProjAim:CreateToggle({
		Name = 'Show target info'
	})

	DebugMode = SkywarsProjAim:CreateToggle({
		Name = 'Debug Mode',
		Function = function(callback)
			debugMode = callback
		end,
		Tooltip = 'Prints debug logs to console'
	})

	-- FOV Circle
	SkywarsProjAim:CreateToggle({
		Name = 'FOV Circle',
		Function = function(callback)
			if callback then
				CircleObject = Drawing.new('Circle')
				CircleObject.Filled = CircleFilled and CircleFilled.Enabled or false
				CircleObject.Color = CircleColor and Color3.fromHSV(CircleColor.Hue, CircleColor.Sat, CircleColor.Value) or Color3.new(1, 1, 1)
				CircleObject.Position = inputService:GetMouseLocation()
				CircleObject.Radius = FOV and FOV.Value or 150
				CircleObject.NumSides = 100
				CircleObject.Transparency = CircleTransparency and (1 - CircleTransparency.Value) or 0.5
				CircleObject.Visible = SkywarsProjAim.Enabled and Mode.Value == 'Mouse'
			else
				pcall(function()
					CircleObject.Visible = false
					CircleObject:Remove()
				end)
				CircleObject = nil
			end

			if CircleColor and CircleColor.Object then
				pcall(function()
					CircleColor.Object.Visible = callback
				end)
			end
			if CircleTransparency and CircleTransparency.Object then
				pcall(function()
					CircleTransparency.Object.Visible = callback
				end)
			end
			if CircleFilled and CircleFilled.Object then
				pcall(function()
					CircleFilled.Object.Visible = callback
				end)
			end
		end
	})

	CircleColor = SkywarsProjAim:CreateColorSlider({
		Name = 'Circle Color',
		Function = function(hue, sat, val)
			if CircleObject then
				pcall(function()
					CircleObject.Color = Color3.fromHSV(hue, sat, val)
				end)
			end
		end,
		Darker = true,
		Visible = false
	})

	CircleTransparency = SkywarsProjAim:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Default = 0.5,
		Function = function(val)
			if CircleObject then
				pcall(function()
					CircleObject.Transparency = 1 - val
				end)
			end
		end,
		Darker = true,
		Visible = false
	})

	CircleFilled = SkywarsProjAim:CreateToggle({
		Name = 'Circle Filled',
		Function = function(callback)
			if CircleObject then
				pcall(function()
					CircleObject.Filled = callback
				end)
			end
		end,
		Darker = true,
		Visible = false
	})
end)