--[[
    Vape V4 NewMainScript (Remaked)
    - All exploit function hooks removed
    - URL system integrated
--]]

repeat task.wait() until game:IsLoaded()

print('[Vape] NewMainScript starting...')

-- Load URLs
local URLs
local function loadURLs()
    local suc, res = pcall(function()
        if isfile and isfile('newvape/URL.lua') then
            return loadstring(readfile('newvape/URL.lua'))()
        end
    end)
    
    if not suc or not res then
        suc, res = pcall(function()
            return loadstring(game:HttpGet('https://raw.githubusercontent.com/HiyokoPVp/HIYOKO-VAPE/main/URL.lua', true))()
        end)
    end
    
    if suc and res then
        return res
    else
        error('[Vape] Failed to load URLs')
    end
end

URLs = loadURLs()

-- Basic functions
local isfile = isfile or function(file)
    local suc, res = pcall(function()
        return readfile(file)
    end)
    return suc and res ~= nil and res ~= ''
end

local delfile = delfile or function(file)
    writefile(file, '')
end

-- Download with URL system
local function downloadFile(path, func)
    if not isfile(path) then
        local urlPath = path:gsub('newvape/', '')
        local fullURL = URLs:Get(urlPath)
        
        local suc, res = pcall(function()
            return game:HttpGet(fullURL, true)
        end)
        
        if not suc or res == '404: Not Found' then
            error('[Vape] Download failed: ' .. path)
        end
        
        if path:find('.lua') then
            res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
        end
        
        writefile(path, res)
    end
    return (func or readfile)(path)
end

-- Wipe cached files
local function wipeFolder(path)
    if not isfolder(path) then return end
    for _, file in listfiles(path) do
        if file:find('loader') or file:find('URL') then continue end
        if isfile(file) then
            local content = readfile(file)
            if content:find('--This watermark is used to delete the file if its cached') == 1 then
                delfile(file)
            end
        end
    end
end

-- Create folders
for _, folder in {'newvape', 'newvape/games', 'newvape/profiles', 'newvape/assets', 'newvape/libraries', 'newvape/guis'} do
    if not isfolder(folder) then
        makefolder(folder)
    end
end

-- Save URL config
if not isfile('newvape/URL.lua') then
    local urlContent = game:HttpGet(URLs:GetBaseURL() .. '/URL.lua', true)
    writefile('newvape/URL.lua', urlContent)
end

-- Version management
if not shared.VapeDeveloper then
    local commit = URLs.Branch or 'main'
    local oldCommit = isfile('newvape/profiles/commit.txt') and readfile('newvape/profiles/commit.txt') or ''
    
    if commit ~= oldCommit then
        print('[Vape] Version changed, clearing cache...')
        wipeFolder('newvape')
        wipeFolder('newvape/games')
        wipeFolder('newvape/guis')
        wipeFolder('newvape/libraries')
    end
    
    writefile('newvape/profiles/commit.txt', commit)
end

print('[Vape] NewMainScript initialized')

-- Load main
return loadstring(downloadFile('newvape/main.lua'), 'main')()
