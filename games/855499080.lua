--[[
    SkywarsProjAim (Fixed & Optimized)
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

-- 最も近くにいる他のプレイヤー（敵）の頭部を取得する安全な関数
local function getNearestEnemyHead()
	local character = lplr.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return nil end
	
	local myRoot = character.HumanoidRootPart
	local nearestHead = nil
	local shortestDistance = math.huge
	
	for _, player in ipairs(playersService:GetPlayers()) do
		if player ~= lplr and player.Character then
			local enemyChar = player.Character
			local enemyHead = enemyChar:FindFirstChild("Head")
			local enemyHumanoid = enemyChar:FindFirstChildOfClass("Humanoid")
			
			if enemyHead and enemyHumanoid and enemyHumanoid.Health > 0 then
				local distance = (myRoot.Position - enemyHead.Position).Magnitude
				if distance < shortestDistance then
					shortestDistance = distance
					nearestHead = enemyHead
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

	SkywarsProjAim = vape.Categories.Combat:CreateModule({
		Name = 'SkywarsProjAim',
		Function = function(callback)
			if CircleObject then
				CircleObject.Visible = callback and Mode.Value == 'Mouse'
			end
			if callback then
				debugMode = DebugMode.Enabled
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
									-- OnClientInvokeはリード（取得）できないため、直接上書きする
									clientControl.OnClientInvoke = function(...)
										if not SkywarsProjAim.Enabled then
											return Vector3.new(0, 0, 0)
										end

										dbg('OnClientInvoke triggered!')
										local targetHead = getNearestEnemyHead()
										
										if targetHead then
											dbg('Target locked: ' .. tostring(targetHead.Parent.Name) .. ' at ' .. tostring(targetHead.Position))
											return targetHead.Position
										end

										return Vector3.new(0, 0, 0)
									end
									dbg('ClientControl successfully hooked for tool: ' .. tool.Name)
									
									-- DebugModeが無効な場合のみ通知を表示
									if debugMode then
										notif('SkywarsProjAim', 'Hooked Bow: ' .. tool.Name, 3)
									end
									
									-- フック完了後はツールが外されるまで待機
									while SkywarsProjAim.Enabled and tool.Parent == character do
										task.wait(0.5)
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
			return Mode.Value
		end,
		Tooltip = 'Automatically aims projectiles by hooking ClientControl.OnClientInvoke directly.'
	})

	Targets = SkywarsProjAim:CreateTargets({Players = true})

	Mode = SkywarsProjAim:CreateDropdown({
		Name = 'Mode',
		List = {'Mouse', 'Position'},
		Function = function(val)
			if CircleObject then
				CircleObject.Visible = SkywarsProjAim.Enabled and val == 'Mouse'
			end
		end
	})

	Range = SkywarsProjAim:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 500,
		Default = 150,
		Function = function(val)
			if CircleObject then
				CircleObject.Radius = val
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
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

	-- Range Circle (Mouse FOV)
	SkywarsProjAim:CreateToggle({
		Name = 'Range Circle',
		Function = function(callback)
			if callback then
				CircleObject = Drawing.new('Circle')
				CircleObject.Filled = CircleFilled.Enabled
				CircleObject.Color = Color3.fromHSV(CircleColor.Hue, CircleColor.Sat, CircleColor.Value)
				CircleObject.Position = inputService:GetMouseLocation()
				CircleObject.Radius = Range.Value
				CircleObject.NumSides = 100
				CircleObject.Transparency = 1 - CircleTransparency.Value
				CircleObject.Visible = SkywarsProjAim.Enabled and Mode.Value == 'Mouse'
			else
				pcall(function()
					CircleObject.Visible = false
					CircleObject:Remove()
				end)
				CircleObject = nil
			end
			CircleColor.Object.Visible = callback
			CircleTransparency.Object.Visible = callback
			CircleFilled.Object.Visible = callback
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