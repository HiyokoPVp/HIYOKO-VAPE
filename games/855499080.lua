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

-- Character内のBowのみを取得（Backpackは無視）
local function getCharacterBow()
    if not lplr or not lplr.Character then
        return nil
    end

    for _, v in ipairs(lplr.Character:GetChildren()) do
        if v:IsA("Tool") and v.Name == "Bow" then
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

local function getTool()
    return lplr.Character and lplr.Character:FindFirstChildWhichIsA('Tool', true) or nil
end

local function notif(...)
    return vape:CreateNotification(...)
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
    local oldInvoke
    local isInRound = false
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
                isInRound = false
                oldInvoke = nil
                debugMode = DebugMode.Enabled

                dbg('Module ENABLED')
                dbg('debugMode = ' .. tostring(debugMode))
                dbg('Mode = ' .. Mode.Value)
                dbg('Range = ' .. Range.Value)

                -- 試合開始待機 + フックスレッド
                SkywarsProjAim:Clean(task.spawn(function()
                    -- ① 試合開始（ツール配布）を待機
                    dbg('--- Phase 1: Waiting for round to start ---')
                    notif('SkywarsProjAim', 'Waiting for round to start...', 3)
                    while SkywarsProjAim.Enabled do
                        if inround() then
                            isInRound = true
                            dbg('Round started! Tools detected in Backpack/Character.')
                            notif('SkywarsProjAim', 'Round started! Looking for Bow in Character...', 3)
                            break
                        end
                        dbg('No tools found yet... waiting.')
                        task.wait(0.5)
                    end

                    if not SkywarsProjAim.Enabled then
                        dbg('Module disabled during Phase 1. Exiting.')
                        return
                    end

                    -- ② Character内にBowが装備されるまで待機
                    dbg('--- Phase 2: Waiting for Bow in Character ---')
                    while SkywarsProjAim.Enabled do
                        local bow = getCharacterBow()
                        if bow then
                            dbg('Bow found in Character: ' .. bow.Name)
                            notif('SkywarsProjAim', 'Bow equipped! Looking for ClientControl...', 3)
                            break
                        end
                        dbg('Bow not in Character yet... (Backpack does not count)')
                        task.wait(0.5)
                    end

                    if not SkywarsProjAim.Enabled then
                        dbg('Module disabled during Phase 2. Exiting.')
                        return
                    end

                    -- ③ ClientControlを待機してフック
                    dbg('--- Phase 3: Hooking ClientControl ---')
                    while SkywarsProjAim.Enabled do
                        local bow = getCharacterBow()
                        if bow then
                            local clientControl = bow:FindFirstChild('ClientControl')
                            if clientControl then
                                dbg('ClientControl found! ClassName: ' .. tostring(clientControl.ClassName))
                                oldInvoke = clientControl.OnClientInvoke
                                dbg('oldInvoke saved: ' .. tostring(oldInvoke))

                                clientControl.OnClientInvoke = function(...)
                                    if not SkywarsProjAim.Enabled then
                                        dbg('OnClientInvoke called but module disabled. Returning oldInvoke.')
                                        return oldInvoke and oldInvoke(...) or Vector3.zero
                                    end

                                    local targetPart = 'Head'
                                    local ent

                                    dbg('OnClientInvoke triggered! Searching for target...')
                                    dbg('Mode: ' .. Mode.Value .. ' | Range: ' .. Range.Value .. ' | Wallcheck: ' .. tostring(Targets.Walls.Enabled))

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
                                        dbg('TARGET LOCKED: ' .. tostring(ent.Player and ent.Player.Name or ent.Character.Name) .. ' | Part: ' .. targetPart .. ' | Pos: ' .. tostring(ent[targetPart].Position))
                                        if ShowTarget.Enabled then
                                            targetinfo.Targets[ent] = tick() + 1
                                        end
                                        return ent[targetPart].Position
                                    end

                                    dbg('No target found. Returning oldInvoke or Vector3.zero.')
                                    if oldInvoke then
                                        return oldInvoke(...)
                                    end
                                    return Vector3.new(0, 0, 0)
                                end

                                dbg('OnClientInvoke HOOKED successfully!')
                                notif('SkywarsProjAim', 'Hooked: ' .. bow.Name, 3)
                                break
                            else
                                dbg('Bow found but no ClientControl yet... waiting.')
                            end
                        else
                            dbg('Bow removed from Character! Waiting for re-equip...')
                        end
                        task.wait(0.5)
                    end

                    if not SkywarsProjAim.Enabled then
                        dbg('Module disabled during Phase 3. Exiting.')
                        return
                    end

                    -- ④ 監視ループ（ツール切り替え・試合終了検知・再フック）
                    dbg('--- Phase 4: Monitoring loop started ---')
                    while SkywarsProjAim.Enabled do
                        task.wait(1)

                        -- 試合終了チェック
                        if not inround() then
                            isInRound = false
                            oldInvoke = nil
                            dbg('Round ended! Tools gone. Waiting for next round...')
                            notif('SkywarsProjAim', 'Round ended. Waiting for next round...', 3)

                            while SkywarsProjAim.Enabled do
                                if inround() then
                                    isInRound = true
                                    dbg('New round started!')
                                    break
                                end
                                task.wait(0.5)
                            end
                            if not SkywarsProjAim.Enabled then break end

                            -- 次ラウンドのBow待機
                            dbg('Waiting for Bow in Character (new round)...')
                            while SkywarsProjAim.Enabled do
                                if getCharacterBow() then
                                    dbg('Bow found in Character (new round).')
                                    break
                                end
                                task.wait(0.5)
                            end
                            if not SkywarsProjAim.Enabled then break end
                        end

                        -- 再フックチェック
                        local bow = getCharacterBow()
                        if bow then
                            local clientControl = bow:FindFirstChild('ClientControl')
                            if clientControl and clientControl.OnClientInvoke ~= oldInvoke then
                                dbg('New ClientControl detected! Re-hooking...')
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
                                        dbg('RE-HOOK TARGET: ' .. tostring(ent.Player and ent.Player.Name or ent.Character.Name))
                                        if ShowTarget.Enabled then
                                            targetinfo.Targets[ent] = tick() + 1
                                        end
                                        return ent[targetPart].Position
                                    end

                                    if oldInvoke then
                                        return oldInvoke(...)
                                    end
                                    return Vector3.new(0, 0, 0)
                                end

                                dbg('Re-hook complete!')
                                notif('SkywarsProjAim', 'Re-hooked: ' .. bow.Name, 3)
                            end
                        else
                            dbg('Bow not in Character. Waiting...')
                        end
                    end

                    dbg('Monitoring loop ended.')
                end))

                -- FOV Circle更新ループ
                SkywarsProjAim:Clean(runService.RenderStepped:Connect(function()
                    if CircleObject then
                        CircleObject.Position = inputService:GetMouseLocation()
                    end
                end))

            else
                -- 無効化時
                dbg('Module DISABLED')
                isInRound = false
                debugMode = false
                if oldInvoke then
                    local bow = getCharacterBow()
                    if bow then
                        local clientControl = bow:FindFirstChild('ClientControl')
                        if clientControl then
                            clientControl.OnClientInvoke = oldInvoke
                            dbg('OnClientInvoke restored to original.')
                        end
                    end
                    oldInvoke = nil
                end
            end
        end,
        ExtraText = function()
            if not isInRound then
                return 'Waiting...'
            end
            return Mode.Value
        end,
        Tooltip = 'Automatically aims projectiles in Skywars\nby hooking ClientControl.OnClientInvoke\nWaits for Bow in Character before hooking.'
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

    DebugMode = SkywarsProjAim:CreateToggle({
        Name = 'Debug Mode',
        Function = function(callback)
            debugMode = callback
            if callback then
                print('[SkywarsProjAim] === DEBUG MODE ENABLED ===')
                print('[SkywarsProjAim] Module Enabled: ' .. tostring(SkywarsProjAim.Enabled))
                print('[SkywarsProjAim] isInRound: ' .. tostring(isInRound))
                print('[SkywarsProjAim] Mode: ' .. Mode.Value)
                print('[SkywarsProjAim] Range: ' .. Range.Value)
                print('[SkywarsProjAim] Wallcheck: ' .. tostring(Targets.Walls.Enabled))
                print('[SkywarsProjAim] oldInvoke: ' .. tostring(oldInvoke))
                local bow = getCharacterBow()
                print('[SkywarsProjAim] Bow in Character: ' .. tostring(bow))
                if bow then
                    print('[SkywarsProjAim] ClientControl: ' .. tostring(bow:FindFirstChild('ClientControl')))
                end
                print('[SkywarsProjAim] ============================')
            else
                print('[SkywarsProjAim] === DEBUG MODE DISABLED ===')
            end
        end,
        Tooltip = 'Prints all internal state and events to the console'
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