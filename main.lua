--[[
    Vape V4 Main Script (Remaked)
    - All exploit function hooks removed
    - URL system integrated
    - Clean and stable code
--]]

repeat task.wait() until game:IsLoaded()

-- Uninject old vape
if shared.vape then 
    pcall(function() shared.vape:Uninject() end)
end

print('[Vape] Main script starting...')

-- Load URLs
local URLs
if isfile and isfile('newvape/URL.lua') then
    URLs = loadstring(readfile('newvape/URL.lua'))()
else
    URLs = loadstring(game:HttpGet('https://raw.githubusercontent.com/YourUsername/YourRepo/main/URL.lua', true))()
end

-- Basic functions (no hooks!)
local vape

local queue_on_teleport = queue_on_teleport or function() end

local isfile = isfile or function(file)
    local suc, res = pcall(function()
        return readfile(file)
    end)
    return suc and res ~= nil and res ~= ''
end

local cloneref = cloneref or function(obj)
    return obj
end

-- Services
local playersService = cloneref(game:GetService('Players'))
local runService = cloneref(game:GetService('RunService'))

-- Download function with URL system
local function downloadFile(path, func)
    if not isfile(path) then
        local urlPath = path:gsub('newvape/', '')
        local fullURL = URLs:Get(urlPath)
        
        local suc, res = pcall(function()
            return game:HttpGet(fullURL, true)
        end)
        
        if not suc or res == '404: Not Found' then
            warn('[Vape] Failed to download: ' .. path)
            error(res or 'Download failed')
        end
        
        if path:find('.lua') then
            res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
        end
        
        writefile(path, res)
    end
    return (func or readfile)(path)
end

-- Custom loadstring with error handling
local oldLoadstring = loadstring
getgenv().loadstring = function(...)
    local res, err = oldLoadstring(...)
    if err and vape then
        pcall(function()
            vape:CreateNotification('Vape', 'Failed to load: '..tostring(err), 30, 'alert')
        end)
    end
    return res
end

-- Finish loading function
local function finishLoading()
    vape.Init = nil
    vape:Load()
    
    -- Auto-save
    task.spawn(function()
        repeat
            pcall(function() vape:Save() end)
            task.wait(10)
        until not vape.Loaded
    end)
    
    -- Teleport handling
    local teleportedServers
    vape:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
        if not teleportedServers and not shared.VapeIndependent then
            teleportedServers = true
            
            local teleportScript = [[
                repeat task.wait() until game:IsLoaded()
                shared.vapereload = true
                
                if shared.VapeDeveloper then
                    loadstring(readfile('newvape/loader.lua'), 'loader')()
                else
                    local URLs = loadstring(game:HttpGet('https://raw.githubusercontent.com/YourUsername/YourRepo/main/URL.lua', true))()
                    loadstring(game:HttpGet(URLs:GetLoader(), true), 'loader')()
                end
            ]]
            
            if shared.VapeDeveloper then
                teleportScript = 'shared.VapeDeveloper = true\n'..teleportScript
            end
            if shared.VapeCustomProfile then
                teleportScript = 'shared.VapeCustomProfile = "'..tostring(shared.VapeCustomProfile)..'"\n'..teleportScript
            end
            
            pcall(function() vape:Save() end)
            queue_on_teleport(teleportScript)
        end
    end))
    
    -- Load notification
    if not shared.vapereload then
        task.delay(1, function()
            if vape.Categories and vape.Categories.Main and vape.Categories.Main.Options then
                local bindIndicator = vape.Categories.Main.Options['GUI bind indicator']
                if bindIndicator and bindIndicator.Enabled then
                    local msg = vape.VapeButton and 'Press the button in the top right to open GUI' 
                        or 'Press '..table.concat(vape.Keybind or {'RightShift'}, ' + '):upper()..' to open GUI'
                    vape:CreateNotification('Finished Loading', msg, 5)
                end
            end
        end)
    end
end

-- GUI setup
if not isfile('newvape/profiles/gui.txt') then
    writefile('newvape/profiles/gui.txt', 'new')
end

local gui = readfile('newvape/profiles/gui.txt')

if not isfolder('newvape/assets/'..gui) then
    makefolder('newvape/assets/'..gui)
end

-- Load GUI
print('[Vape] Loading GUI: ' .. gui)
vape = loadstring(downloadFile('newvape/guis/'..gui..'.lua'), 'gui')()
shared.vape = vape
getgenv().vape = vape

-- Load game scripts
if not shared.VapeIndependent then
    print('[Vape] Loading universal script...')
    loadstring(downloadFile('newvape/games/universal.lua'), 'universal')()
    
    -- Game-specific script
    local gameId = tostring(game.PlaceId)
    
    if isfile('newvape/games/'..gameId..'.lua') then
        print('[Vape] Loading game script: ' .. gameId)
        loadstring(readfile('newvape/games/'..gameId..'.lua'), gameId)(...)
    else
        if not shared.VapeDeveloper then
            local suc, res = pcall(function()
                return game:HttpGet(URLs:GetGame(gameId), true)
            end)
            
            if suc and res ~= '404: Not Found' then
                print('[Vape] Downloading game script: ' .. gameId)
                loadstring(downloadFile('newvape/games/'..gameId..'.lua'), gameId)(...)
            else
                print('[Vape] No specific script for game: ' .. gameId)
            end
        end
    end
    
    finishLoading()
else
    vape.Init = finishLoading
    return vape
end

print('[Vape] Main script loaded successfully')
print('[Vape] Version: Clean Remake')
print('[Vape] No exploit hooks - Stable execution')
