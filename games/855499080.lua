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
local isnetworkowner = identifyexecutor and table.find({'Volcano', 'Nihon'}, ({identifyexecutor()})[1]) and isnetworkowner or function()
	return true
end
local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer
local assetfunction = getcustomasset

local vape = shared.vape
local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo
local uipallet = vape.Libraries.uipallet
local tween = vape.Libraries.tween
local color = vape.Libraries.color
local whitelist = vape.Libraries.whitelist
local prediction = vape.Libraries.prediction
local getfontsize = vape.Libraries.getfontsize
local getcustomasset = vape.Libraries.getcustomasset

local store = {
	attackReach = 0,
	attackReachUpdate = tick(),
	damageBlockFail = tick(),
	hand = {},
	inventory = {
		inventory = {
			items = {},
			armor = {}
		},
		hotbar = {}
	},
	inventories = {},
	tools = {}
}

local function getbackpacktool()
    local tools = {}

    if lplr then
        for _, v in ipairs(lplr.Backpack:GetChildren()) do
            if v:IsA("Tool") then
                table.insert(tools, v)
            end
        end
    end

    if #tools == 0 then
        return nil
    end

    return tools
end

local function getcharactertool()
    local tools = {}

    if lplr and lplr.Character then
        for _, v in ipairs(lplr.Character:GetChildren()) do
            if v:IsA("Tool") then
                table.insert(tools, v)
            end
        end
    end

    if #tools == 0 then
        return nil
    end

    return tools
end

local function hasTool()
    if not lplr then
        return nil
    end

    local backpack = lplr:FindFirstChild("Backpack")
    local character = lplr.Character

    if backpack then
        for _, v in ipairs(backpack:GetChildren()) do
            if v:IsA("Tool") then
                return true
            end
        end
    end

    if character then
        for _, v in ipairs(character:GetChildren()) do
            if v:IsA("Tool") then
                return true
            end
        end
    end

    return nil
end

local function IsCharacterTool()
    if not lplr or not lplr.Character then
        return nil
    end

    for _, v in ipairs(lplr.Character:GetChildren()) do
        if v:IsA("Tool") then
            return true
        end
    end

    return nil
end

local function gettoolbyname(name)
    if not lplr then
        return nil
    end

    local backpack = lplr:FindFirstChild("Backpack")
    local character = lplr.Character

    if backpack then
        for _, v in ipairs(backpack:GetChildren()) do
            if v:IsA("Tool") and v.Name == name then
                return v
            end
        end
    end

    if character then
        for _, v in ipairs(character:GetChildren()) do
            if v:IsA("Tool") and v.Name == name then
                return v
            end
        end
    end

    return nil
end

local function getcharactertool()
    if not lplr or not lplr.Character then
        return nil
    end

    for _, v in ipairs(lplr.Character:GetChildren()) do
        if v:IsA("Tool") then
            return v
        end
    end

    return nil
end

local function getaxe()
    return gettoolbyname("Axe")
end

local function getblock()
    return gettoolbyname("Block")
end

local function getbow()
    return gettoolbyname("Bow")
end

local function getsword()
    return gettoolbyname("Sword")
end

local function inround()
    return hasTool()
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
    local oldInvoke

    SkywarsProjAim = vape.Categories.Combat:CreateModule({
        Name = 'SkywarsProjAim',
        Function = function(callback)
            if CircleObject then
                CircleObject.Visible = callback and Mode.Value == 'Mouse'
            end
            if callback then
                -- ツールとClientControlを待機してフックするスレッド
                SkywarsProjAim:Clean(task.spawn(function()
                    while SkywarsProjAim.Enabled do
                        local tool = getTool()
                        if tool then
                            local clientControl = tool:FindFirstChild('ClientControl')
                            if clientControl then
                                -- 元のOnClientInvokeを保存
                                oldInvoke = clientControl.OnClientInvoke

                                clientControl.OnClientInvoke = function(...)
                                    if not SkywarsProjAim.Enabled then
                                        return oldInvoke and oldInvoke(...) or Vector3.zero
                                    end

                                    local targetPart = 'Head'
                                    local ent

                                    if Mode.Value == 'Mouse' then
                                        ent = entitylib.EntityMouse({
                                            Range = Range.Value,
                                            Wallcheck = Targets.Walls.Enabled or nil,
                                            Part = targetPart,
                                            Players = Targets.Players.Enabled,
                                            NPCs = Targets.NPCs.Enabled,
                                            Origin = gameCamera.CFrame.Position
                                        })
                                    else
                                        ent = entitylib.EntityPosition({
                                            Range = Range.Value,
                                            Wallcheck = Targets.Walls.Enabled or nil,
                                            Part = targetPart,
                                            Players = Targets.Players.Enabled,
                                            NPCs = Targets.NPCs.Enabled,
                                            Origin = entitylib.isAlive and entitylib.character.RootPart.Position or Vector3.zero
                                        })
                                    end

                                    if ent and ent[targetPart] then
                                        if ShowTarget.Enabled then
                                            targetinfo.Targets[ent] = tick() + 1
                                        end
                                        return ent[targetPart].Position
                                    end

                                    -- ターゲットなし → 元の処理 or ゼロ
                                    if oldInvoke then
                                        return oldInvoke(...)
                                    end
                                    return Vector3.new(0, 0, 0)
                                end

                                -- フック成功通知
                                notif('SkywarsProjAim', 'Hooked: '..tool.Name, 3)
                                break
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
                -- 無効化時: 元のOnClientInvokeを復元
                if oldInvoke then
                    local tool = getTool()
                    if tool then
                        local clientControl = tool:FindFirstChild('ClientControl')
                        if clientControl then
                            clientControl.OnClientInvoke = oldInvoke
                        end
                    end
                    oldInvoke = nil
                end
            end
        end,
        ExtraText = function()
            return Mode.Value
        end,
        Tooltip = 'Automatically aims projectiles in Skywars\nby hooking ClientControl.OnClientInvoke'
    })

    Targets = SkywarsProjAim:CreateTargets({Players = true})

    Mode = SkywarsProjAim:CreateDropdown({
        Name = 'Mode',
        List = {'Mouse', 'Position'},
        Function = function(val)
            if CircleObject then
                CircleObject.Visible = SkywarsProjAim.Enabled and val == 'Mouse'
            end
        end,
        Tooltip = 'Mouse - Checks for entities near the mouse position\nPosition - Checks for entities near the local character'
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