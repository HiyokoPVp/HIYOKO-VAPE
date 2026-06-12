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
    local walkspeedacdisabler
    local walkspeed

    local function disablewscheck()
        local mt = getrawmetatable(game)
        setreadonly(mt, false)

        local oldindex = mt.__index

        mt.__index = newcclosure(function(self, b)
            if b == 'WalkSpeed' then
                return 16
            end
        end)
    end

    walkspeedacdisabler = vape.Categories.Blatant:CreateModule({
        Name = "Skywars Speed",
        Function = function(callback)
            if callback then
            repeat
                disablewscheck()
                lplr.Character:FindFirstChild("Humanoid").WalkSpeed = walkspeed
                task.wait()
            until not callback.Enabled

            else
                lplr.Character:FindFirstChild("Humanoid").WalkSpeed = 16
        end 

        end
    })

    walkspeed = walkspeedacdisabler:CreateSlider({
        Name = "WalkSpeed",
        Min = 1,
        Max = 150,
        Default = 50
    })
end)