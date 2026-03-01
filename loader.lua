--[[
    Vape V4 Loader (Remaked)
    - All exploit function hooks removed
    - URL system integrated
    - Clean and stable code
--]]

repeat task.wait() until game:IsLoaded()

print('[Vape] Loader starting...')

-- Load URL configuration
local URLs
local function loadURLs()
    local suc, res = pcall(function()
        if isfile and isfile('newvape/URL.lua') then
            return loadstring(readfile('newvape/URL.lua'))()
        end
    end)
    
    if not suc or not res then
        -- Fallback: load from GitHub
        suc, res = pcall(function()
            return loadstring(game:HttpGet('https://raw.githubusercontent.com/YourUsername/YourRepo/main/URL.lua', true))()
        end)
    end
    
    if suc and res then
        return res
    else
        error('[Vape] Failed to load URL configuration')
    end
end

URLs = loadURLs()
print('[Vape] URLs loaded')

-- Basic file functions (no hooks)
local isfile = isfile or function(file)
    local suc, res = pcall(function()
        return readfile(file)
    end)
    return suc and res ~= nil and res ~= ''
end

local delfile = delfile or function(file)
    local suc = pcall(function()
        writefile(file, '')
    end)
    return suc
end

-- Download file using URL system
local function downloadFile(path, func)
    if not isfile(path) then
        local urlPath = path:gsub('newvape/', '')
        local fullURL = URLs:Get(urlPath)
        
        local suc, res = pcall(function()
            return game:HttpGet(fullURL, true)
        end)
        
        if not suc or res == '404: Not Found' then
            warn('[Vape] Failed to download: ' .. path)
            warn('[Vape] URL: ' .. fullURL)
            error(res or 'Download failed')
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

-- Create necessary folders
local folders = {
    'newvape',
    'newvape/games',
    'newvape/profiles',
    'newvape/assets',
    'newvape/libraries',
    'newvape/guis'
}

for _, folder in ipairs(folders) do
    if not isfolder(folder) then
        makefolder(folder)
    end
end

-- Save URL configuration locally
if not isfile('newvape/URL.lua') then
    local urlContent = game:HttpGet(URLs:GetBaseURL() .. '/URL.lua', true)
    writefile('newvape/URL.lua', urlContent)
end

-- Commit/version management
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

print('[Vape] Loader initialized')
print('[Vape] No exploit hooks - Clean execution')

-- Load main script
return loadstring(downloadFile('newvape/main.lua'), 'main')()
