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
    URLs = loadstring(game:HttpGet('https://raw.githubusercontent.com/HiyokoPVp/HIYOKO-VAPE/main/URL.lua', true))()
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
    print('[Vape] finishLoading() called')
    
    if not vape then
        warn('[Vape] ERROR: vape object is nil!')
        return
    end
    
    print('[Vape] vape object exists')
    print('[Vape] vape.Load exists:', vape.Load ~= nil)
    
    vape.Init = nil
    
    local loadSuccess, loadErr = pcall(function()
        vape:Load()
    end)
    
    if not loadSuccess then
        warn('[Vape] ERROR in vape:Load():', loadErr)
        return
    end
    
    print('[Vape] vape:Load() successful')
    
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
                    local URLs = loadstring(game:HttpGet('https://raw.githubusercontent.com/HiyokoPVp/HIYOKO-VAPE/main/URL.lua', true))()
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

local guiLoadSuccess, guiLoadResult = pcall(function()
    return loadstring(downloadFile('newvape/guis/'..gui..'.lua'), 'gui')()
end)

if not guiLoadSuccess then
    error('[Vape] CRITICAL: Failed to load GUI: ' .. tostring(guiLoadResult))
end

if not guiLoadResult then
    error('[Vape] CRITICAL: GUI loaded but returned nil')
end

vape = guiLoadResult
shared.vape = vape
getgenv().vape = vape

print('[Vape] GUI loaded successfully')
print('[Vape] vape object type:', type(vape))
print('[Vape] vape.Load exists:', vape.Load ~= nil)
print('[Vape] vape.Libraries exists:', vape.Libraries ~= nil)

-- Load required libraries BEFORE universal.lua
print('[Vape] Loading libraries...')

-- entity.lua
local entityLibLoaded, entityLib = pcall(function()
    return loadstring(downloadFile('newvape/libraries/entity.lua'), 'entity')()
end)

if entityLibLoaded and entityLib then
    vape.Libraries.entity = entityLib
    shared.vapeentity = entityLib
    print('[Vape] entity.lua loaded')
else
    warn('[Vape] Failed to load entity.lua: ' .. tostring(entityLib))
end

-- prediction.lua  
local predictionLoaded, predictionLib = pcall(function()
    return loadstring(downloadFile('newvape/libraries/prediction.lua'), 'prediction')()
end)

if predictionLoaded and predictionLib then
    vape.Libraries.prediction = predictionLib
    print('[Vape] prediction.lua loaded')
end

-- drawing.lua
local drawingLoaded, drawingLib = pcall(function()
    return loadstring(downloadFile('newvape/libraries/drawing.lua'), 'drawing')()
end)

if drawingLoaded and drawingLib then
    vape.Libraries.drawing = drawingLib
    print('[Vape] drawing.lua loaded')
end

-- Create missing Libraries if they don't exist
if not vape.Libraries.whitelist then
    print('[Vape] Creating whitelist fallback...')
    vape.Libraries.whitelist = {
        get = function(self, plr)
            return 0, true  -- level 0, attackable true
        end,
        tag = function(self, plr, text, rich)
            return ''  -- no tags
        end
    }
end

if not vape.Libraries.targetinfo then
    vape.Libraries.targetinfo = {}
end

if not vape.Libraries.sessioninfo then
    vape.Libraries.sessioninfo = {}
end

print('[Vape] Libraries loaded successfully')

-- Load game scripts
if not shared.VapeIndependent then
    print('[Vape] Loading universal script...')
    loadstring(downloadFile('newvape/games/universal.lua'), 'universal')()
    
    -- Game-specific script
    local gameId = tostring(game.PlaceId)
    print('[Vape] Current game PlaceId: ' .. gameId)
    
    -- まずローカルファイルをチェック
    local gameScriptPath = 'newvape/games/'..gameId..'.lua'
    local gameScriptLoaded = false
    
    if isfile(gameScriptPath) then
        print('[Vape] Loading game script from local: ' .. gameId)
        local suc, err = pcall(function()
            loadstring(readfile(gameScriptPath), gameId)()
        end)
        if suc then
            gameScriptLoaded = true
        else
            warn('[Vape] Failed to load local game script: ' .. tostring(err))
        end
    end
    
    -- ローカルになければGitHubから試す
    if not gameScriptLoaded and not shared.VapeDeveloper then
        local suc, res = pcall(function()
            return game:HttpGet(URLs:GetGame(gameId), true)
        end)
        
        if suc and res ~= '404: Not Found' and res ~= '' then
            print('[Vape] Downloading game script: ' .. gameId)
            -- ファイルを保存
            if res:find('.lua') then
                res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
            end
            writefile(gameScriptPath, res)
            
            -- ロード
            local loadSuc, loadErr = pcall(function()
                loadstring(res, gameId)()
            end)
            if loadSuc then
                gameScriptLoaded = true
            else
                warn('[Vape] Failed to load downloaded game script: ' .. tostring(loadErr))
            end
        else
            print('[Vape] No specific script for game: ' .. gameId .. ' (using universal only)')
        end
    end
    
    if gameScriptLoaded then
        print('[Vape] Game-specific script loaded successfully')
    end
    
    finishLoading()
else
    vape.Init = finishLoading
    return vape
end

print('[Vape] Main script loaded successfully')
print('[Vape] Version: Clean Remake')
print('[Vape] No exploit hooks - Stable execution')
