--[[
    SkywarsProjAim (Fixed & Optimized + Mouse FOV)
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

-- 最も近い敵の頭部を取得
-- Mouseモード: 画面カーソル基準でFOV内から選ぶ
-- Positionモード: 3D距離で選ぶ
local function getNearestEnemyHead(options)
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

	local nearestHead = nil
	local bestScore = math.huge

	for _, player in ipairs(playersService:GetPlayers()) do
		if player ~= lplr and player.Character then
			local enemyChar = player.Character
			local enemyHead = enemyChar:FindFirstChild("Head")
			local enemyHumanoid = enemyChar:FindFirstChildOfClass("Humanoid")

			if enemyHead and enemyHumanoid and enemyHumanoid.Health > 0 then
				local distance = (myRoot.Position - enemyHead.Position).Magnitude

				-- Range制限
				if not options.Range or options.Range <= 0 or distance <= options.Range then
					if options.Mode == 'Mouse' then
						if camera then
							local screenPos = camera:WorldToViewportPoint(enemyHead.Position)

							if screenPos and screenPos.Z > 0 then
								local screenDistance = (Vector2.new(screenPos.X, screenPos.Y) - mouseLocation).Magnitude
								local fov = options.FOV or math.huge

								-- FOV内の中で、最もカーソルに近い敵を選ぶ
								if screenDistance <= fov and screenDistance < bestScore then
									bestScore = screenDistance
									nearestHead = enemyHead
								end
							end
						end
					else
						-- Positionモードは単純に最も近い敵
						if distance < bestScore then
							bestScore = distance
							nearestHead = enemyHead
						end
					end
				end
			end
		end
	end

	return nearestHead
end

run(function()
	local SkywarsProjAim
	local Targets
	local Mode
	local Range
	local FOV
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
			CircleObject.Visible = SkywarsProjAim.Enabled and Mode.Value == 'Mouse'

			if Mode.Value == 'Mouse' and FOV then
				CircleObject.Radius = FOV.Value
			end
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

										local targetHead = getNearestEnemyHead({
											Mode = Mode and Mode.Value or 'Mouse',
											Range = Range and Range.Value or 0,
											FOV = FOV and FOV.Value or math.huge,
										})

										if targetHead then
											dbg('Target locked: ' .. tostring(targetHead.Parent and targetHead.Parent.Name) .. ' at ' .. tostring(targetHead.Position))
											return targetHead.Position
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
						CircleObject.Position = inputService:GetMouseLocation()
					end
				end))
			else
				dbg('Module DISABLED')
				debugMode = false
			end
		end,
		ExtraText = function()
			return Mode and Mode.Value or ''
		end,
		Tooltip = 'Automatically aims projectiles by hooking ClientControl.OnClientInvoke directly. Mouse mode uses FOV.'
	})

	Mode = SkywarsProjAim:CreateDropdown({
		Name = 'Mode',
		List = {'Mouse', 'Position'},
		Function = function(val)
			local isMouse = val == 'Mouse'

			if FOV and FOV.Object then
				FOV.Object.Visible = isMouse
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
				CircleObject.Radius = val
			end
		end,
		Suffix = function(val)
			return 'px'
		end,
		Tooltip = 'Mouse mode only: only targets inside this screen FOV circle are selected.',
		Visible = Mode.Value == 'Mouse'
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
				CircleColor.Object.Visible = callback
			end
			if CircleTransparency and CircleTransparency.Object then
				CircleTransparency.Object.Visible = callback
			end
			if CircleFilled and CircleFilled.Object then
				CircleFilled.Object.Visible = callback
			end
		end
	})

	CircleColor = SkywarsProjAim:CreateColorSlider({
		Name = 'Circle Color',
		Function = function(hue, sat, val)
			if CircleObject then
				CircleObject.Color = Color3.fromHSV(hue, sat, val)
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
				CircleObject.Transparency = 1 - val
			end
		end,
		Darker = true,
		Visible = false
	})

	CircleFilled = SkywarsProjAim:CreateToggle({
		Name = 'Circle Filled',
		Function = function(callback)
			if CircleObject then
				CircleObject.Filled = callback
			end
		end,
		Darker = true,
		Visible = false
	})
end)